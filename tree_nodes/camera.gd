# camera.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2023 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield in the US
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# *****************************************************************************
class_name IVCamera
extends Camera


# This camera works with the IVSelection object, which is a wrapper that can
# hold IVBody or IVLagrangePoint instances (or could be extended to hold
# anything). It uses IVCameraPath to determine path and interpolate between
# target objects.


# WIP Overhaul:
# IVCamera can attach itself to any Spatial (called 'target').
# There are some duck typing options for Target:
#   get_ground_basis() - enables 'ground tracking'
#   get_orbit_basis() - enables 'orbit tracking'
#   (note: we always use target.global_transform to resolve ecliptic)
#   get_view_position(view_type, track_type)
#   get_mean_radius()
#   get_system_radius()
#   get_min_view_dist()

#   m_radius - for camera dynamic range determination
#   min_view_dist - otherwise, uses m_radius * FALLBACK_MIN_DIST_RADIUS_MULTIPLIER
#
# Overhaul steps:
# 1. Redo camera controls ->  Camera Locks:  x Up  x Ground  _ Orbit
# 2. Fix motions/rotations.
# 3. Add CameraPath object


# This camera is always locked to an IVBody and constantly orients itself based
# on that IVBody's ground or orbit around its parent, depending on 'tracking'
# selection.
#
# You can replace this with another Camera class, but see:
#    IVGlobal signals related to camera (singletons/global.gd)
#    IVCameraHandler (prog_nodes/camera_handler.gd); replace this!
#    Possibly other dependencies. You'll need to search.
#
# The camera stays "in place" by maintaining view_position & view_rotations.
# The first is position relative to either target body's parent or ground
# depending on track_type. The second is rotation relative to looking at
# target body w/ north up.

signal move_started(to_spatial, is_camera_lock) # to_spatial not parent yet
signal parent_changed(spatial)
signal range_changed(camera_range)
signal latitude_longitude_changed(lat_long, is_ecliptic, selection)
signal focal_length_changed(focal_length)
signal camera_lock_changed(is_camera_lock)
signal view_type_changed(view_type)
signal tracking_changed(track_type, is_ecliptic)


const math := preload("res://ivoyager/static/math.gd") # =IVMath when issue #37529 fixed

const VIEW_ZOOM := IVEnums.ViewType.VIEW_ZOOM
const VIEW_45 := IVEnums.ViewType.VIEW_45
const VIEW_TOP := IVEnums.ViewType.VIEW_TOP
const VIEW_OUTWARD := IVEnums.ViewType.VIEW_OUTWARD
const VIEW_BUMPED := IVEnums.ViewType.VIEW_BUMPED
const VIEW_BUMPED_ROTATED := IVEnums.ViewType.VIEW_BUMPED_ROTATED
const TRACK_ECLIPTIC := IVEnums.CameraTrackType.TRACK_ECLIPTIC
const TRACK_ORBIT := IVEnums.CameraTrackType.TRACK_ORBIT
const TRACK_GROUND := IVEnums.CameraTrackType.TRACK_GROUND
const IDENTITY_BASIS := Basis.IDENTITY
const ECLIPTIC_X := IDENTITY_BASIS.x # primary direction
const ECLIPTIC_Y := IDENTITY_BASIS.y
const ECLIPTIC_Z := IDENTITY_BASIS.z # ecliptic north
const NULL_ROTATION := Vector3(-INF, -INF, -INF)
const VECTOR2_ZERO := Vector2.ZERO
const VECTOR3_ZERO := Vector3.ZERO
const OUTWARD_VIEW_ROTATION := Vector3(0.0, PI, 0.0)

const DPRINT := false
const UNIVERSE_SHIFTING := true # prevents "shakes" at high global translation
const NEAR_MULTIPLIER := 0.1
const FAR_MULTIPLIER := 1e9 # see Note below

# Note: As of Godot 3.2.3 we had to raise FAR_MULTIPLIER from 1e9 to 1e6.
# It used to be that ~10 orders of magnitude was allowed between near and far,
# but perhaps that is now only 7.

const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL
const PERSIST_PROPERTIES := [
	"name",
	"is_camera_lock",
	"view_type",
	"track_type",
	"selection",
	"view_position",
	"view_rotations",
	"focal_length",
	"focal_length_index",
	"_transform",
	"_view_type_memory",
]

# ******************************* PERSISTED ***********************************

# public - read only except project init
var is_camera_lock := true
var view_type := VIEW_ZOOM
var track_type := TRACK_GROUND

# public - read only! (use move methods to set; these are "to" during transfer)
var selection: IVSelection
var view_position := Vector3.ONE # spherical; relative to orbit or ground ref
var view_rotations := VECTOR3_ZERO # euler; relative to looking_at(-origin, north)
var focal_length: float
var focal_length_index: int # use init_focal_length_index below

# private
var _transform := Transform(Basis(), Vector3.ONE) # working value
var _view_type_memory := view_type

# *****************************************************************************

# public - project init vars
var focal_lengths := [6.0, 15.0, 24.0, 35.0, 50.0] # ~fov 125.6, 75.8, 51.9, 36.9, 26.3
var init_focal_length_index := 2
var ease_exponent := 5.0
var track_dist: float = 4e7 * IVUnits.KM # km after dividing by fov
var use_local_up: float = 5e7 * IVUnits.KM # must be > track_dist
var use_ecliptic_up: float = 5e10 * IVUnits.KM # must be > use_local_up
var max_compensated_dist: float = 5e7 * IVUnits.KM
var action_immediacy := 10.0 # how fast we use up the accumulators
var min_action := 0.002 # use all below this
var size_ratio_exponent := 0.95 # 0.0, none; 1.0 moves to same visual size

# public read-only
var parent: Spatial # actual Spatial parent at this time
var is_moving := false # body to body move in progress

# private
var _camera_pathing: IVCameraPathing = IVGlobal.program.CameraPathing
var _times: Array = IVGlobal.times
var _settings: Dictionary = IVGlobal.settings
var _world_targeting: Array = IVGlobal.world_targeting
var _max_dist: float = IVGlobal.max_camera_distance
var _min_dist := 0.1 # changed on move for parent body
var _track_dist: float
var _use_local_up_dist: float
var _use_ecliptic_up_dist: float
var _max_compensated_dist: float

# motions / rotations
var _motion_accumulator := VECTOR3_ZERO
var _rotation_accumulator := VECTOR3_ZERO

# move_to
var _move_time: float
var _is_interupted_move := false
var _interupted_transform: Transform


var _to_spatial: Spatial
var _from_spatial: Spatial
var _from_selection: IVSelection
var _from_view_type := VIEW_ZOOM
var _from_view_position := Vector3.ONE # any non-zero dist ok
var _from_view_rotations := VECTOR3_ZERO
var _from_track_type := TRACK_GROUND
var _is_ecliptic := false
var _last_dist := 0.0
var _lat_long := Vector2(-INF, -INF)

var _universe: Spatial = IVGlobal.program.Universe



# settings
onready var _transfer_time: float = _settings.camera_transfer_time


# virtual functions

func _ready() -> void:
	assert(track_dist < use_local_up and use_local_up < use_ecliptic_up)
	name = "Camera"
	IVGlobal.connect("system_tree_ready", self, "_on_system_tree_ready",
			[], CONNECT_ONESHOT)
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_prepare_to_free",
			[], CONNECT_ONESHOT)
	IVGlobal.connect("update_gui_requested", self, "_send_gui_refresh")
	IVGlobal.connect("move_camera_requested", self, "move_to")
	IVGlobal.connect("setting_changed", self, "_settings_listener")
	transform = _transform
	var dist := _transform.origin.length()
	near = dist * NEAR_MULTIPLIER
	far = dist * FAR_MULTIPLIER
	focal_length_index = init_focal_length_index
	focal_length = focal_lengths[focal_length_index]
	fov = math.get_fov_from_focal_length(focal_length)
	_track_dist = track_dist / fov
	_is_ecliptic = dist > _track_dist
	_use_local_up_dist = use_local_up / fov
	_use_ecliptic_up_dist = use_ecliptic_up / fov
	_max_compensated_dist = max_compensated_dist / fov
	_world_targeting[2] = self
	_world_targeting[3] = fov
	IVGlobal.verbose_signal("camera_ready", self)


func _process(delta: float) -> void:
	# We process our working '_transform', then update here.
	if is_moving:
		_process_move_in_progress(delta)
	else:
		_process_at_target(delta)
	if UNIVERSE_SHIFTING:
		# Camera parent will be at global translation (0,0,0) after this step.
		# The -= operator works because current Universe translation is part
		# of parent.global_translation, so we are removing old shift at
		# the same time we add our new shift.
		_universe.translation -= parent.global_translation
	transform = _transform


# public functions

func add_motion(motion_amount: Vector3) -> void: # rotate around or move in/out from target
	_motion_accumulator += motion_amount


func add_rotation(rotation_amount: Vector3) -> void: # rotate in-place
	_rotation_accumulator += rotation_amount


func move_to(to_selection: IVSelection, to_view_type := -1, to_view_position := VECTOR3_ZERO,
		to_view_rotations := NULL_ROTATION, to_track_type := -1, is_instant_move := false) -> void:
	# Null or null-equivilant args tell the camera to keep its current value.
	# Some view_type values override all or some components of view_position &
	# view_rotations.
	assert(DPRINT and prints("move_to", to_selection, to_view_type, to_view_position,
			to_view_rotations, to_track_type, is_instant_move) or true)
	# Don't move if *nothing* is changed.
	if ((!to_selection or to_selection == selection)
			and (to_view_type == -1 or to_view_type == view_type)
			and (to_view_position == VECTOR3_ZERO or to_view_position == view_position)
			and (to_view_rotations == NULL_ROTATION or to_view_rotations == view_rotations)
			and (to_track_type == -1 or to_track_type == track_type)):
		return
	_from_selection = selection
	_from_view_type = view_type
	_from_view_position = view_position
	_from_view_rotations = view_rotations
	_from_track_type = track_type
	_from_spatial = parent
	if to_selection and to_selection.spatial:
		selection = to_selection
		_to_spatial = to_selection.spatial
		_min_dist = selection.view_min_distance * 50.0 / fov
	if to_track_type != -1 and track_type != to_track_type:
		track_type = to_track_type
		emit_signal("tracking_changed", to_track_type, _is_ecliptic)
	if to_view_type != -1:
		view_type = to_view_type
	match view_type:
		VIEW_ZOOM, VIEW_45, VIEW_TOP, VIEW_OUTWARD:
			if track_type == TRACK_GROUND:
				view_position = selection.track_ground_positions[view_type]
			elif track_type == TRACK_ORBIT:
				view_position = selection.track_orbit_positions[view_type]
			else:
				view_position = selection.track_ecliptic_positions[view_type]
			view_position[2] /= fov
			if view_type == VIEW_OUTWARD:
				view_rotations = OUTWARD_VIEW_ROTATION
			else:
				view_rotations = VECTOR3_ZERO
		VIEW_BUMPED, VIEW_BUMPED_ROTATED:
			if to_view_position != VECTOR3_ZERO:
				view_position = to_view_position
			elif _from_selection != selection \
					and view_position[2] < _max_compensated_dist:
				# partial distance compensation
				var from_radius := _from_selection.get_radius_for_camera()
				var to_radius := selection.get_radius_for_camera()
				var adj_ratio := pow(to_radius / from_radius, size_ratio_exponent)
				view_position[2] *= adj_ratio
			continue
		VIEW_BUMPED:
			view_rotations = VECTOR3_ZERO
		VIEW_BUMPED_ROTATED:
			if to_view_rotations != NULL_ROTATION:
				view_rotations = to_view_rotations
		_:
			assert(false, "Unknown view_type %s" % view_type)
	var min_dist := selection.view_min_distance * sqrt(50.0 / fov)
	if view_position[2] < min_dist:
		view_position[2] = min_dist
	if is_instant_move:
		_move_time = _transfer_time # finishes move on next frame
	elif !is_moving:
		_move_time = 0.0 # starts move on next frame
	else:
		_is_interupted_move = true
		_interupted_transform = transform
		
		_move_time = 0.0
	is_moving = true
	_motion_accumulator = VECTOR3_ZERO
	_rotation_accumulator = VECTOR3_ZERO
	emit_signal("move_started", _to_spatial, is_camera_lock)
	emit_signal("view_type_changed", view_type) # FIXME: signal if it really happened


func change_track_type(new_track_type: int) -> void:
	# changes tracking without a "move"
	if new_track_type == track_type:
		return
	track_type = new_track_type
	view_type = VIEW_BUMPED_ROTATED
	_reset_view_position_and_rotations()
	emit_signal("tracking_changed", track_type, _is_ecliptic)
	emit_signal("view_type_changed", view_type)


func increment_focal_length(increment: int) -> void:
	var new_fl_index = focal_length_index + increment
	if new_fl_index < 0:
		new_fl_index = 0
	elif new_fl_index >= focal_lengths.size():
		new_fl_index = focal_lengths.size() - 1
	if new_fl_index != focal_length_index:
		set_focal_length_index(new_fl_index, false)


func set_focal_length_index(new_fl_index, suppress_move := false) -> void:
	focal_length_index = new_fl_index
	focal_length = focal_lengths[focal_length_index]
	fov = math.get_fov_from_focal_length(focal_length)
	_use_local_up_dist = use_local_up / fov
	_use_ecliptic_up_dist = use_ecliptic_up / fov
	_track_dist = track_dist / fov
	_max_compensated_dist = max_compensated_dist / fov
	_min_dist = selection.view_min_distance * 50.0 / fov
	_world_targeting[3] = fov
	if !suppress_move:
		move_to(null, -1, VECTOR3_ZERO, NULL_ROTATION, -1, true)
	emit_signal("focal_length_changed", focal_length)


func change_camera_lock(new_lock: bool) -> void:
	if is_camera_lock != new_lock:
		is_camera_lock = new_lock
		emit_signal("camera_lock_changed", new_lock)
		if new_lock:
			if view_type > VIEW_OUTWARD:
				view_type = _view_type_memory


# private functions

func _on_system_tree_ready(_is_new_game: bool) -> void:
	parent = get_parent()
	_to_spatial = parent
	_from_spatial = parent
	if !selection: # new game
		var _SelectionManager_: Script = IVGlobal.script_classes._SelectionManager_
		selection = _SelectionManager_.get_or_make_selection(parent.name)
		assert(selection)
	_from_selection = selection
	_min_dist = selection.view_min_distance * 50.0 / fov
	move_to(null, -1, VECTOR3_ZERO, NULL_ROTATION, -1, true)


func _prepare_to_free() -> void:
	set_process(false)
	IVGlobal.disconnect("update_gui_requested", self, "_send_gui_refresh")
	IVGlobal.disconnect("move_camera_requested", self, "move_to")
	IVGlobal.disconnect("setting_changed", self, "_settings_listener")
	selection = null
	parent = null
	_to_spatial = null
	_from_spatial = null
	_from_selection = null


func _process_move_in_progress(delta: float) -> void:
	_move_time += delta
	if _is_interupted_move:
		_move_time += delta # double-time; user is in a hurry!
	if _move_time >= _transfer_time: # end the move
		is_moving = false
		_is_interupted_move = false
		if parent != _to_spatial:
			_do_handoff()
		_process_at_target(delta)
		return
	
	var progress := ease(_move_time / _transfer_time, -ease_exponent)
	
	# Hand-off at halfway point avoids precision shakes at either end
	if progress > 0.5 and parent != _to_spatial:
		_do_handoff()
	
	var from_transform := (_interupted_transform if _is_interupted_move
			 else _get_view_transform(_from_selection, _from_view_position, _from_view_rotations,
			_from_track_type))
	var to_transform := _get_view_transform(selection, view_position, view_rotations, track_type)
	_transform = _camera_pathing.interpolate_path(from_transform, _from_spatial,
			to_transform, _to_spatial, parent, progress)
	

	var gui_translation := _transform.origin
	var dist := gui_translation.length()
	near = dist * NEAR_MULTIPLIER
	far = dist * FAR_MULTIPLIER
	if parent != _to_spatial: # GUI is already showing _to_spatial
		gui_translation = global_translation - _to_spatial.global_translation
		dist = gui_translation.length()
	emit_signal("range_changed", dist)
	var is_ecliptic := dist > _track_dist
	if _is_ecliptic != is_ecliptic:
		_is_ecliptic = is_ecliptic
		emit_signal("tracking_changed", track_type, is_ecliptic)
	if is_ecliptic:
		_lat_long = math.get_latitude_longitude(global_translation)
	else:
		_lat_long = selection.get_latitude_longitude(gui_translation)
	emit_signal("latitude_longitude_changed", _lat_long, is_ecliptic, selection)


func _do_handoff() -> void:
	assert(DPRINT and prints("Camera handoff", tr(parent.name), tr(_to_spatial.name)) or true)
	parent.remove_child(self)
	_to_spatial.add_child(self)
	parent = _to_spatial
	emit_signal("parent_changed", parent)


func _process_at_target(delta: float) -> void:
	var is_camera_bump := false
	# maintain present "position" based on track_type
	_transform = _get_view_transform(selection, view_position, view_rotations, track_type)
	# process accumulated user inputs
	if _motion_accumulator:
		_process_motion(delta)
		is_camera_bump = true
	if _rotation_accumulator:
		_process_rotation(delta)
		is_camera_bump = true
	if is_camera_bump and view_type != VIEW_BUMPED_ROTATED:
		if view_rotations:
			view_type = VIEW_BUMPED_ROTATED
			emit_signal("view_type_changed", view_type)
		elif view_type != VIEW_BUMPED:
			view_type = VIEW_BUMPED
			emit_signal("view_type_changed", view_type)
	var dist := view_position[2]
	if dist != _last_dist:
		_last_dist = dist
		emit_signal("range_changed", dist)
		near = dist * NEAR_MULTIPLIER
		far = dist * FAR_MULTIPLIER
	var is_ecliptic := dist > _track_dist
	if _is_ecliptic != is_ecliptic:
		_is_ecliptic = is_ecliptic
		emit_signal("tracking_changed", track_type, is_ecliptic)
	var lat_long: Vector2
	if is_ecliptic:
		lat_long = math.get_latitude_longitude(global_translation)
	else:
		lat_long = selection.get_latitude_longitude(_transform.origin)
	if _lat_long != lat_long:
		_lat_long = lat_long
		emit_signal("latitude_longitude_changed", lat_long, is_ecliptic, selection)


func _process_motion(delta: float) -> void:
	var action_proportion := action_immediacy * delta
	if action_proportion > 1.0:
		action_proportion = 1.0
	var move_now := _motion_accumulator
	if abs(move_now.x) > min_action:
		move_now.x *= action_proportion
		_motion_accumulator.x -= move_now.x
	else:
		_motion_accumulator.x = 0.0
	if abs(move_now.y) > min_action:
		move_now.y *= action_proportion
		_motion_accumulator.y -= move_now.y
	else:
		_motion_accumulator.y = 0.0
	if abs(move_now.z) > min_action:
		move_now.z *= action_proportion
		_motion_accumulator.z -= move_now.z
	else:
		_motion_accumulator.z = 0.0
	# rotate for camera basis
	var move_vector := _transform.basis.xform(move_now)
	# get values for adjustments below
	var origin := _transform.origin
	var dist: float = view_position[2]
	var up := _get_up(selection, dist, track_type)
	var radial_movement := move_vector.dot(origin)
	var normalized_origin := origin.normalized()
	var longitude_vector := normalized_origin.cross(up).normalized()
	# dampen "spin" movement as we near the poles
	var longitudinal_move := longitude_vector * longitude_vector.dot(move_vector)
	var spin_dampening := up.dot(normalized_origin)
	spin_dampening *= spin_dampening # makes positive & reduces
	spin_dampening *= spin_dampening # reduces more
	move_vector -= longitudinal_move * spin_dampening
	# add adjusted move vector scaled by distance to parent
	origin += move_vector * dist
	# test for pole traversal
	if longitude_vector.dot(origin.cross(up)) <= 0.0: # before/after comparison
		view_rotations.z = wrapf(view_rotations.z + PI, -PI, PI)
	# fix our distance to ignore small tangental movements
	var new_dist := dist + radial_movement
	new_dist = clamp(new_dist, _min_dist, _max_dist)
	origin = new_dist * origin.normalized()
	# update _transform using new origin & existing view_rotations
	_transform.origin = origin
	_transform = _transform.looking_at(-origin, up)
	_transform.basis *= Basis(view_rotations)
	# reset view_position
	var tracking_basis := _get_tracking_basis(selection, new_dist, track_type)
	view_position = math.get_rotated_spherical3(origin, tracking_basis)


func _process_rotation(delta: float) -> void:
	var action_proportion := action_immediacy * delta
	if action_proportion > 1.0:
		action_proportion = 1.0
	var rotate_now := _rotation_accumulator
	if abs(rotate_now.x) > min_action:
		rotate_now.x *= action_proportion
		_rotation_accumulator.x -= rotate_now.x
	else:
		_rotation_accumulator.x = 0.0
	if abs(rotate_now.y) > min_action:
		rotate_now.y *= action_proportion
		_rotation_accumulator.y -= rotate_now.y
	else:
		_rotation_accumulator.y = 0.0
	if abs(rotate_now.z) > min_action:
		rotate_now.z *= action_proportion
		_rotation_accumulator.z -= rotate_now.z
	else:
		_rotation_accumulator.z = 0.0
	var basis := Basis(view_rotations)
	basis = basis.rotated(basis.x, rotate_now.x)
	basis = basis.rotated(basis.y, rotate_now.y)
	basis = basis.rotated(basis.z, rotate_now.z)
	view_rotations = basis.get_euler()
	var dist := view_position[2]
	var up := _get_up(selection, dist, track_type)
	_transform = _transform.looking_at(-_transform.origin, up)
	_transform.basis *= Basis(view_rotations)


func _reset_view_position_and_rotations() -> void:
	# update for current _transform, selection & track_type
	var origin := _transform.origin
	var dist := origin.length()
	# position
	var tracking_basis := _get_tracking_basis(selection, dist, track_type)
	view_position = math.get_rotated_spherical3(origin, tracking_basis)
	# rotations
	var basis_rotated := _transform.basis
	var up := _get_up(selection, dist, track_type)
	var transform_looking_at := _transform.looking_at(-origin, up)
	var basis_looking_at := transform_looking_at.basis
	# From _process_rotation() we have...
	# basis_rotated = basis_looking_at * rotations_basis
	# A = B * C
	# C = B^-1 * A
	var rotations_basis := basis_looking_at.inverse() * basis_rotated
	view_rotations = rotations_basis.get_euler()


func _get_view_transform(selection_: IVSelection, view_position_: Vector3,
		view_rotations_: Vector3, track_type_: int) -> Transform:
	var dist := view_position_[2]
	var up := _get_up(selection_, dist, track_type_)
	var tracking_basis := _get_tracking_basis(selection_, dist, track_type_)
	var view_translation := math.convert_rotated_spherical3(view_position_, tracking_basis)
	assert(view_translation)
	var view_transform := Transform(IDENTITY_BASIS, view_translation).looking_at(
			-view_translation, up)
	view_transform.basis *= Basis(view_rotations_) # TODO: The member should be the rotation basis
	return view_transform


func _get_up(selection_: IVSelection, dist: float, track_type_: int) -> Vector3:
	if dist >= _use_ecliptic_up_dist or track_type_ == TRACK_ECLIPTIC:
		return ECLIPTIC_Z
	var local_up: Vector3
	if track_type_ == TRACK_ORBIT:
		local_up = selection_.get_orbit_normal(NAN, true)
	else:
		local_up = selection_.get_up()
	if dist <= _use_local_up_dist:
		return local_up
	# interpolate along a log scale
	var proportion := log(dist / _use_local_up_dist) / log(
			_use_ecliptic_up_dist / _use_local_up_dist)
	proportion = ease(proportion, -ease_exponent)
	var diff_vector := local_up - ECLIPTIC_Z
	return (local_up - diff_vector * proportion).normalized()


func _get_tracking_basis(selection_: IVSelection, dist: float, track_type_: int) -> Basis:
	if dist > _track_dist:
		return IDENTITY_BASIS
	if track_type_ == TRACK_ORBIT:
		return selection_.get_orbit_basis()
	if track_type_ == TRACK_GROUND:
		return selection_.get_ground_basis()
	return IDENTITY_BASIS


func _send_gui_refresh() -> void:
	assert(parent)
	emit_signal("parent_changed", parent)
	emit_signal("range_changed", translation.length())
	emit_signal("focal_length_changed", focal_length)
#	emit_signal("camera_lock_changed", is_camera_lock) # triggers camera move
	emit_signal("view_type_changed", view_type)
	var is_ecliptic := translation.length() > _track_dist
	emit_signal("tracking_changed", track_type, is_ecliptic)
	var lat_long: Vector2
	if is_ecliptic:
		lat_long = math.get_latitude_longitude(global_translation)
	else:
		lat_long = selection.get_latitude_longitude(translation)
	emit_signal("latitude_longitude_changed", lat_long, is_ecliptic, selection)


func _settings_listener(setting: String, value) -> void:
	match setting:
		"camera_transfer_time":
			_transfer_time = value
