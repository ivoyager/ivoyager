# camera.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2022 Charlie Whitfield
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

signal move_started(to_body, is_camera_lock)
signal parent_changed(new_body)
signal range_changed(new_range)
signal latitude_longitude_changed(lat_long, is_ecliptic)
signal focal_length_changed(focal_length)
signal camera_lock_changed(is_camera_lock)
signal view_type_changed(view_type)
signal tracking_changed(track_type, is_ecliptic)

# TODO: Select path_type at move(). PATH_SPHERICAL is usually best. But in some
# circumstances, PATH_CARTESION looks better.
enum {
	PATH_CARTESIAN,
	PATH_SPHERICAL,
}

const math := preload("res://ivoyager/static/math.gd") # =IVMath when issue #37529 fixed

const VIEW_ZOOM := IVEnums.ViewType.VIEW_ZOOM
const VIEW_45 := IVEnums.ViewType.VIEW_45
const VIEW_TOP := IVEnums.ViewType.VIEW_TOP
const VIEW_OUTWARD := IVEnums.ViewType.VIEW_OUTWARD
const VIEW_BUMPED := IVEnums.ViewType.VIEW_BUMPED
const VIEW_BUMPED_ROTATED := IVEnums.ViewType.VIEW_BUMPED_ROTATED
const TRACK_NONE := IVEnums.CameraTrackType.TRACK_NONE
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
const FAR_MULTIPLIER := 1e6 # see Note below

# Note: As of Godot 3.2.3 we had to raise FAR_MULTIPLIER from 1e9 to 1e6.
# It used to be that ~10 orders of magnitude was allowed between near and far,
# but perhaps that is now only 7.

const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL
const PERSIST_PROPERTIES := [
	"name",
	"is_camera_lock",
	"selection",
	"view_type",
	"track_type",
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

# public - read only! (these are "to" during body-to-body transfer)
var selection: IVSelection
var view_type := VIEW_ZOOM
var track_type := TRACK_GROUND
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
var size_ratio_exponent := 0.8 # 1.0 is full size compensation

# public read-only
var parent: Spatial # actual Spatial parent at this time
var is_moving := false # body to body move in progress

# private
var _times: Array = IVGlobal.times
var _settings: Dictionary = IVGlobal.settings
var _visuals_helper: IVVisualsHelper = IVGlobal.program.VisualsHelper
var _body_registry: IVBodyRegistry = IVGlobal.program.BodyRegistry
var _max_dist: float = IVGlobal.max_camera_distance
var _min_dist := 0.1 # changed on move for parent body
var _track_dist: float
var _use_local_up_dist: float
var _use_ecliptic_up_dist: float
var _max_compensated_dist: float

# move/rotate actions - these are accumulators
var _move_action := VECTOR3_ZERO
var _rotate_action := VECTOR3_ZERO

# body to body transfer
var _move_progress: float
var _path_type := PATH_SPHERICAL # TODO: select at move()
var _to_spatial: Spatial
var _from_spatial: Spatial
var _transfer_ref_spatial: Spatial
var _transfer_ref_basis: Basis
var _from_selection: IVSelection
var _from_view_type := VIEW_ZOOM
var _from_view_position := Vector3.ONE # any non-zero dist ok
var _from_view_rotations := VECTOR3_ZERO
var _from_track_type := TRACK_GROUND
var _is_ecliptic := false
var _last_dist := 0.0
var _lat_long := Vector2(-INF, -INF)

var _universe: Spatial = IVGlobal.program.Universe
var _View_: Script = IVGlobal.script_classes._View_

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
	IVGlobal.connect("move_camera_to_selection_requested", self, "move_to_selection")
	IVGlobal.connect("move_camera_to_body_requested", self, "move_to_body")
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
	_visuals_helper.camera = self
	_visuals_helper.camera_fov = fov
	IVGlobal.verbose_signal("camera_ready", self)


func _on_system_tree_ready(_is_new_game: bool) -> void:
	parent = get_parent()
	_to_spatial = parent
	_from_spatial = parent
	if !selection:
		selection = _body_registry.get_body_selection(parent)
	_from_selection = selection
	_min_dist = selection.view_min_distance * 50.0 / fov
	move_to_selection(null, -1, VECTOR3_ZERO, NULL_ROTATION, -1, true)


func _prepare_to_free() -> void:
	set_process(false)
	IVGlobal.disconnect("update_gui_requested", self, "_send_gui_refresh")
	IVGlobal.disconnect("move_camera_to_selection_requested", self, "move_to_selection")
	IVGlobal.disconnect("move_camera_to_body_requested", self, "move_to_body")
	IVGlobal.disconnect("setting_changed", self, "_settings_listener")
	selection = null
	parent = null
	_to_spatial = null
	_from_spatial = null
	_transfer_ref_spatial = null


func _process(delta: float) -> void:
	# We process our working _transform, then update transform
	if is_moving:
		_process_move_in_progress(delta)
	else:
		_process_at_target(delta)
	if UNIVERSE_SHIFTING:
		# Camera parent will be at global translation (0,0,0) after this step.
		# The -= operator works because current Universe translation is part
		# of parent.global_transform.origin, so we are removing old shift at
		# the same time we add our new shift.
		_universe.translation -= parent.global_transform.origin
	transform = _transform


# public functions


func add_move_action(move_action: Vector3) -> void:
	_move_action += move_action


func add_rotate_action(rotate_action: Vector3) -> void:
	_rotate_action += rotate_action


func move_to_view(view: IVView, is_instant_move := false) -> void:
	var to_selection: IVSelection
	if view.selection_name:
		to_selection = _body_registry.get_selection(view.selection_name)
		assert(to_selection)
	move_to_selection(to_selection, view.view_type, view.view_position, view.view_rotations,
			view.track_type, is_instant_move)
	view.set_huds_visible()


func create_view(use_current_selection := true, has_hud_states := true) -> IVView:
	# IVView object is useful for cache or save persistence
	var view: IVView = _View_.new()
	if use_current_selection:
		view.selection_name = selection.name
	view.track_type = track_type
	view.view_type = view_type
	match view_type:
		VIEW_BUMPED, VIEW_BUMPED_ROTATED:
			view.view_position = view_position
			continue
		VIEW_BUMPED_ROTATED:
			view.view_rotations = view_rotations
	if has_hud_states:
		view.store_huds_visible()
	return view


func move_to_body(to_body: IVBody, to_view_type := -1, to_view_position := VECTOR3_ZERO,
		to_view_rotations := NULL_ROTATION, to_track_type := -1, is_instant_move := false) -> void:
	assert(DPRINT and prints("move_to_body", to_body, to_view_type, to_view_position,
			to_view_rotations, to_track_type, is_instant_move) or true)
	var to_selection := _body_registry.get_body_selection(to_body)
	move_to_selection(to_selection, to_view_type, to_view_position, to_view_rotations, to_track_type,
			is_instant_move)


func move_to_selection(to_selection: IVSelection, to_view_type := -1, to_view_position := VECTOR3_ZERO,
		to_view_rotations := NULL_ROTATION, to_track_type := -1, is_instant_move := false) -> void:
	# Null or null-equivilant args tell the camera to keep its current value.
	# Most view_type values override all or some components of view_position &
	# view_rotations.
	assert(DPRINT and prints("move_to_selection", to_selection, to_view_type, to_view_position,
			to_view_rotations, to_track_type, is_instant_move) or true)
	_from_selection = selection
	_from_spatial = parent
	_from_view_type = view_type
	_from_view_position = view_position
	_from_view_rotations = view_rotations
	_from_track_type = track_type
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
		_move_progress = _transfer_time # finishes move on next frame
	elif !is_moving:
		_move_progress = 0.0 # starts move on next frame
	else:
		_move_progress = _transfer_time / 2.0 # move was in progress; user is in a hurry!
	_transfer_ref_spatial = _get_transfer_ref_spatial(_from_spatial, _to_spatial)
	_transfer_ref_basis = _get_transfer_ref_basis(_from_selection, selection)
	is_moving = true
	_move_action = VECTOR3_ZERO
	_rotate_action = VECTOR3_ZERO
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
	_visuals_helper.camera_fov = fov
	if !suppress_move:
		move_to_selection(null, -1, VECTOR3_ZERO, NULL_ROTATION, -1, true)
	emit_signal("focal_length_changed", focal_length)


func change_camera_lock(new_lock: bool) -> void:
	if is_camera_lock != new_lock:
		is_camera_lock = new_lock
		emit_signal("camera_lock_changed", new_lock)
		if new_lock:
			if view_type > VIEW_OUTWARD:
				view_type = _view_type_memory


# private functions

func _process_move_in_progress(delta: float) -> void:
	_move_progress += delta
	if _move_progress >= _transfer_time: # end the move
		is_moving = false
		if parent != _to_spatial:
			_do_camera_handoff()
		_process_at_target(delta)
		return
	var progress := ease(_move_progress / _transfer_time, -ease_exponent)
	# Hand-off at halfway point avoids precision shakes at either end
	if parent != _to_spatial and progress > 0.5:
		_do_camera_handoff()
	if _path_type == PATH_CARTESIAN:
		_interpolate_cartesian_path(progress)
	else: # PATH_SPHERICAL
		_interpolate_spherical_path(progress)
	var gui_translation := _transform.origin
	var dist := gui_translation.length()
	near = dist * NEAR_MULTIPLIER
	far = dist * FAR_MULTIPLIER
	if parent != _to_spatial: # GUI is already showing _to_spatial
		gui_translation = global_transform.origin - _to_spatial.global_transform.origin
		dist = gui_translation.length()
	emit_signal("range_changed", dist)
	var is_ecliptic := dist > _track_dist
	if _is_ecliptic != is_ecliptic:
		_is_ecliptic = is_ecliptic
		emit_signal("tracking_changed", track_type, is_ecliptic)
	if is_ecliptic:
		_lat_long = math.get_latitude_longitude(global_transform.origin)
	else:
		_lat_long = selection.get_latitude_longitude(gui_translation)
	emit_signal("latitude_longitude_changed", _lat_long, is_ecliptic)


func _do_camera_handoff() -> void:
	parent.remove_child(self)
	_to_spatial.add_child(self)
	parent = _to_spatial
	emit_signal("parent_changed", parent)


func _interpolate_cartesian_path(progress: float) -> void:
	# interpolate global cartesian coordinates
	var from_transform := _get_view_transform(_from_selection, _from_view_position,
			_from_view_rotations, _from_track_type)
	var to_transform := _get_view_transform(selection, view_position,
			view_rotations, track_type)
	var from_global_origin := _from_spatial.global_transform.origin
	var to_global_origin := _to_spatial.global_transform.origin
	from_transform.origin += from_global_origin
	to_transform.origin += to_global_origin
	_transform = from_transform.interpolate_with(to_transform, progress)
	if parent == _from_spatial:
		_transform.origin -= from_global_origin
	else:
		_transform.origin -= to_global_origin


func _interpolate_spherical_path(progress: float) -> void:
	# interpolate spherical coordinates relative to _transfer_ref_spatial and
	# _transfer_ref_basis
	var from_transform := _get_view_transform(_from_selection, _from_view_position,
			_from_view_rotations, _from_track_type)
	var to_transform := _get_view_transform(selection, view_position,
			view_rotations, track_type)
	var from_global_origin := _from_spatial.global_transform.origin
	var to_global_origin := _to_spatial.global_transform.origin
	var ref_origin := _transfer_ref_spatial.global_transform.origin
	var from_ref_origin := from_transform.origin + from_global_origin - ref_origin
	var to_ref_origin := to_transform.origin + to_global_origin - ref_origin
	var from_ref_spherical := math.get_rotated_spherical3(from_ref_origin, _transfer_ref_basis)
	var to_ref_spherical := math.get_rotated_spherical3(to_ref_origin, _transfer_ref_basis)
	# interpolate spherical coordinates & convert
	var longitude_diff: float = to_ref_spherical[0] - from_ref_spherical[0]
	if longitude_diff > PI:
		from_ref_spherical[0] += TAU
	if longitude_diff < -PI:
		to_ref_spherical[0] += TAU
	var spherical := from_ref_spherical.linear_interpolate(to_ref_spherical, progress)
	_transform.origin = math.convert_rotated_spherical3(spherical, _transfer_ref_basis)
	_transform.origin += ref_origin
	if parent == _from_spatial:
		_transform.origin -= from_global_origin
	else:
		_transform.origin -= to_global_origin
	# interpolate basis
	_transform.basis = from_transform.basis.slerp(to_transform.basis, progress)


func _process_at_target(delta: float) -> void:
	var is_camera_bump := false
	# maintain present "position" based on track_type
	_transform = _get_view_transform(selection, view_position, view_rotations, track_type)
	# process accumulated user inputs
	if _move_action:
		_process_move_action(delta)
		is_camera_bump = true
	if _rotate_action:
		_process_rotate_action(delta)
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
		lat_long = math.get_latitude_longitude(global_transform.origin)
	else:
		lat_long = selection.get_latitude_longitude(_transform.origin)
	if _lat_long != lat_long:
		_lat_long = lat_long
		emit_signal("latitude_longitude_changed", lat_long, is_ecliptic)


func _process_move_action(delta: float) -> void:
	var action_proportion := action_immediacy * delta
	if action_proportion > 1.0:
		action_proportion = 1.0
	var move_now := _move_action
	if abs(move_now.x) > min_action:
		move_now.x *= action_proportion
		_move_action.x -= move_now.x
	else:
		_move_action.x = 0.0
	if abs(move_now.y) > min_action:
		move_now.y *= action_proportion
		_move_action.y -= move_now.y
	else:
		_move_action.y = 0.0
	if abs(move_now.z) > min_action:
		move_now.z *= action_proportion
		_move_action.z -= move_now.z
	else:
		_move_action.z = 0.0
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


func _process_rotate_action(delta: float) -> void:
	var action_proportion := action_immediacy * delta
	if action_proportion > 1.0:
		action_proportion = 1.0
	var rotate_now := _rotate_action
	if abs(rotate_now.x) > min_action:
		rotate_now.x *= action_proportion
		_rotate_action.x -= rotate_now.x
	else:
		_rotate_action.x = 0.0
	if abs(rotate_now.y) > min_action:
		rotate_now.y *= action_proportion
		_rotate_action.y -= rotate_now.y
	else:
		_rotate_action.y = 0.0
	if abs(rotate_now.z) > min_action:
		rotate_now.z *= action_proportion
		_rotate_action.z -= rotate_now.z
	else:
		_rotate_action.z = 0.0
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
	# From _process_rotate_action() we have...
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
	if dist >= _use_ecliptic_up_dist or track_type_ == TRACK_NONE:
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
		return selection_.get_orbit_ref_basis()
	if track_type_ == TRACK_GROUND:
		return selection_.get_ground_ref_basis()
	return IDENTITY_BASIS


func _get_transfer_ref_basis(s1: IVSelection, s2: IVSelection) -> Basis:
	var normal1 := s1.get_orbit_normal(NAN, true)
	var normal2 := s2.get_orbit_normal(NAN, true)
	var z_axis := (normal1 + normal2).normalized()
	var y_axis := z_axis.cross(ECLIPTIC_X).normalized() # norm needed - imprecision?
	var x_axis := y_axis.cross(z_axis)
	return Basis(x_axis, y_axis, z_axis)


func _get_transfer_ref_spatial(spatial1: Spatial, spatial2: Spatial) -> Spatial:
	assert(spatial1 and spatial2)
	while spatial1:
		var test_spatial = spatial2
		while test_spatial:
			if spatial1 == test_spatial:
				return spatial1
			test_spatial = test_spatial.get_parent_spatial()
		spatial1 = spatial1.get_parent_spatial()
	assert(false)
	return null


func _send_gui_refresh() -> void:
	if parent:
		emit_signal("parent_changed", parent)
	emit_signal("range_changed", translation.length())
	emit_signal("focal_length_changed", focal_length)
#	emit_signal("camera_lock_changed", is_camera_lock) # triggers camera move
	emit_signal("view_type_changed", view_type)
	var is_ecliptic := translation.length() > _track_dist
	emit_signal("tracking_changed", track_type, is_ecliptic)
	var lat_long: Vector2
	if is_ecliptic:
		lat_long = math.get_latitude_longitude(global_transform.origin)
	else:
		lat_long = selection.get_latitude_longitude(translation)
	emit_signal("latitude_longitude_changed", lat_long, is_ecliptic)


func _settings_listener(setting: String, value) -> void:
	match setting:
		"camera_transfer_time":
			_transfer_time = value
