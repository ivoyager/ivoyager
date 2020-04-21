# b_camera.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2020 Charlie Whitfield
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
# BCamera for "Body". Presumably we will have other cameras in the future.

extends Camera
class_name BCamera

const math := preload("res://ivoyager/static/math.gd") # =Math when issue #37529 fixed

# ********************************* SIGNALS ***********************************

signal move_started(to_body, is_camera_lock)
signal parent_changed(new_body)
signal range_changed(new_range)
signal focal_length_changed(focal_length)
signal camera_lock_changed(is_camera_lock)
signal view_type_changed(view_type)

# ***************************** ENUMS & CONSTANTS *****************************

const VIEW_ZOOM = Enums.VIEW_ZOOM
const VIEW_45 = Enums.VIEW_45
const VIEW_TOP = Enums.VIEW_TOP
const VIEW_CENTERED = Enums.VIEW_CENTERED
const VIEW_UNCENTERED = Enums.VIEW_UNCENTERED

enum {
	LONGITUDE_REMAP_INIT,
	LONGITUDE_REMAP_NONE,
	LONGITUDE_REMAP_FROM,
	LONGITUDE_REMAP_TO
}

const DPRINT := false
const CENTER_ORIGIN_SHIFTING := true # prevents "shakes" at high translation
const NEAR_DIST_MULTIPLIER := 0.1 
const FAR_DIST_MULTIPLIER := 1e9 # far/near seems to allow ~10 orders-of-magnitude 
const MIN_ANGLE_TO_POLE := PI / 80.0
const MOUSE_MOVE_ADJ := 0.4
const MOUSE_PITCH_YAW_ADJ := 0.1
const MOUSE_ROLL_ADJ := 0.3
const MOUSE_WHEEL_ADJ := 20.0
const ECLIPTIC_NORTH := Vector3(0.0, 0.0, 1.0)
const Y_DIRECTION := Vector3(0.0, 1.0, 0.0)
const X_DIRECTION := Vector3(1.0, 0.0, 0.0)
const NULL_DRAG := Vector2.ZERO
const NULL_ROTATION := Vector3(-INF, -INF, -INF)

# ******************************* PERSISTED ***********************************

# public - read only except project init
var is_camera_lock := true

# public - read only! (these are "to" during camera move)
var selection_item: SelectionItem
var view_type := VIEW_ZOOM
var spherical_position := Vector3.ZERO # longitude, latitude, radius
var camera_rotation := Vector3.ZERO # relative to pointing at parent, north up
var focal_length: float
var focal_length_index: int # use init_focal_length_index below

# private
var _transform := Transform(Basis(), Vector3.ONE) # "working" value
var _view_type_memory := view_type

# persistence
const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["name", "is_camera_lock", "view_type", "spherical_position",
	"camera_rotation", "focal_length", "focal_length_index", "_transform", "_view_type_memory"]
const PERSIST_OBJ_PROPERTIES := ["selection_item"]

# ****************************** UNPERSISTED **********************************

# public - project init vars
var focal_lengths := [6.0, 15.0, 24.0, 35.0, 50.0] # ~fov 125.6, 75.8, 51.9, 36.9, 26.3
var init_focal_length_index := 2
var ease_exponent := 5.0
var follow_orbit: float = 4e7 * UnitDefs.KM # km after dividing by fov
var orient_to_local_pole: float = 5e7 * UnitDefs.KM # must be > follow_orbit
var orient_to_ecliptic: float = 5e10 * UnitDefs.KM # must be > orient_to_local_pole
var move_tangentially_rate := 0.7 # affects mouse & key
var move_in_out_rate := 3.0 # affects mouse & key
var mouse_rotate_min_z_at_offcenter := 0.2
var mouse_rotate_max_z_at_offcenter := 0.7
var mouse_wheel_halflife_x2 := 0.1 # sec

# public read-only
var parent: Spatial # always current
var is_moving := false

# private
var _settings: Dictionary = Global.settings
var _registrar: Registrar = Global.program.Registrar
var _max_dist_sq: float = pow(Global.max_camera_distance, 2.0)
var _min_dist_sq := 0.01 # set for parent body
var _follow_orbit_dist_sq: float
var _orient_to_local_pole_sq: float
var _orient_to_ecliptic_sq: float
var _mouse_wheel_accumulator := 0
var _move_action_pressed := Vector3.ZERO
var _rotate_action_pressed := Vector3.ZERO

var _drag_l_button_start := NULL_DRAG
var _drag_l_button_segment_start := NULL_DRAG
var _drag_l_button_current := NULL_DRAG
var _drag_r_button_start := NULL_DRAG
var _drag_r_button_segment_start := NULL_DRAG
var _drag_r_button_current := NULL_DRAG
# move
var _move_progress: float
var _to_spatial: Spatial
var _from_spatial: Spatial
var _move_spatial: Spatial
var _move_north := ECLIPTIC_NORTH
var _from_selection_item: SelectionItem
var _from_view_type := VIEW_ZOOM
var _from_spherical_position := Vector3.ONE
var _from_camera_rotation := Vector3.ZERO
var _last_anomaly := -INF # -INF is used as null value
var _move_longitude_remap := LONGITUDE_REMAP_INIT

onready var _top_body: Body = _registrar.top_body
onready var _viewport := get_viewport()
onready var _tree := get_tree()
# settings
onready var _transition_time: float = _settings.camera_transition_time
onready var _mouse_in_out_rate: float = _settings.camera_mouse_in_out_rate
onready var _mouse_move_rate: float = _settings.camera_mouse_move_rate
onready var _mouse_pitch_yaw_rate: float = _settings.camera_mouse_pitch_yaw_rate
onready var _mouse_roll_rate: float = _settings.camera_mouse_roll_rate
onready var _key_in_out_rate: float = _settings.camera_key_in_out_rate
onready var _key_move_rate: float = _settings.camera_key_move_rate
onready var _key_pitch_yaw_rate: float = _settings.camera_key_pitch_yaw_rate
onready var _key_roll_rate: float = _settings.camera_key_roll_rate

# **************************** PUBLIC FUNCTIONS *******************************

static func get_spherical_position(translation_: Vector3, north: Vector3,
		ref_longitude := 0.0) -> Vector3:
	# FIXME: This should be way simpler than the way I did it here!
	#
	# "spherical_position_" is a standardized Vector3 where:
	#    x is longitude angle relative to ref_longitude
	#    y is latitude angle
	#    z is radius distance
	# (ref_longitude is used here to track orbital motion when close; -INF, ok)
	assert(north.is_normalized())
	if ref_longitude == -INF:
		ref_longitude = 0.0
	
	# TODO: Use spherical coordinate conversions
#	translation_ = _math.rotate_vector_pole(translation_, north)
#	var spherical := _math.cartesian2spherical(translation_)
#	var radius := spherical[0]
#	var latitude := PI / 2.0 - spherical[1]
#	var longitude := wrapf(spherical[2] - ref_longitude, -PI, PI)
	
	var radius := translation_.length()
	var latitude := PI / 2.0 - translation_.angle_to(north)
	var axis := translation_.cross(north).normalized()
	var world_x := Y_DIRECTION.cross(north).normalized()
	var longitude := axis.angle_to(world_x)
	if axis.dot(Y_DIRECTION) < 0.0:
		longitude = -longitude
	longitude = wrapf(longitude + PI / 2.0 - ref_longitude, -PI, PI)
	return Vector3(longitude, latitude, radius)

static func convert_spherical_position(spherical_position_: Vector3, north: Vector3,
		ref_longitude: float) -> Vector3:
	# inverse of above function
	# FIXME: This should be way simpler than this!!!
	if ref_longitude == -INF:
		ref_longitude = 0.0
	var longitude := spherical_position_[0]
	var latitude := spherical_position_[1]
	var radius := spherical_position_[2]
	
	# TODO: Use spherical coordinate conversions
#	var spherical := Vector3(radius, PI / 2.0 - latitude, longitude - ref_longitude)
#	var translation_ := _math.spherical2cartesian(spherical)
#	translation_ = -_math.rotate_vector_pole(north, translation_)
	
	var world_x := Y_DIRECTION.cross(north).normalized()
	var axis := world_x.rotated(north, longitude - PI / 2.0 + ref_longitude)
	var translation_ = axis.cross(north)
	assert(translation_.is_normalized())
	translation_ = translation_.rotated(axis, latitude)
	translation_ *= -radius
	return translation_

func move(to_selection_item: SelectionItem, to_view_type := -1, to_spherical_position := Vector3.ZERO,
		to_rotations := NULL_ROTATION, is_instant_move := false) -> void:
	# Null or null-equivilant args tell the camera to keep its current value.
	# Most view_type values override spherical_position & camera_rotation.
	assert(DPRINT and prints("move", to_selection_item, to_view_type, to_spherical_position,
			to_rotations, is_instant_move) or true)
	_from_selection_item = selection_item
	_from_spatial = parent
	_from_view_type = view_type
	_from_spherical_position = spherical_position
	_from_camera_rotation = camera_rotation
	if to_selection_item and to_selection_item.spatial:
		selection_item = to_selection_item
		_to_spatial = to_selection_item.spatial
		_min_dist_sq = pow(selection_item.view_min_distance, 2.0) * 50.0 / fov
	if to_view_type != -1:
		view_type = to_view_type
	match view_type:
		VIEW_ZOOM, VIEW_45, VIEW_TOP:
			spherical_position = selection_item.camera_spherical_positions[view_type]
			spherical_position[2] /= fov
			camera_rotation = Vector3.ZERO
		VIEW_CENTERED:
			if to_spherical_position != Vector3.ZERO:
				spherical_position = to_spherical_position
			camera_rotation = Vector3.ZERO
		VIEW_UNCENTERED:
			if to_spherical_position != Vector3.ZERO:
				spherical_position = to_spherical_position
			if to_rotations != NULL_ROTATION:
				camera_rotation = to_rotations
		_:
			assert(false)
	var min_dist := selection_item.view_min_distance * sqrt(50.0 / fov)
	if spherical_position.z < min_dist:
		spherical_position.z = min_dist

	if is_instant_move:
		_move_progress = _transition_time # finishes move on next frame
	elif !is_moving:
		_move_progress = 0.0 # starts move on next frame
	else:
		_move_progress = _transition_time / 2.0 # move was in progress; user is in a hurry!
	_move_spatial = _get_common_spatial(_from_spatial, _to_spatial)
	var from_north: Vector3 = _from_spatial.north_pole if "north_pole" in _from_spatial else ECLIPTIC_NORTH
	var to_north: Vector3 = _to_spatial.north_pole if "north_pole" in _to_spatial else ECLIPTIC_NORTH
	_move_north = (from_north + to_north).normalized()
	is_moving = true
	_move_longitude_remap = LONGITUDE_REMAP_INIT
	emit_signal("move_started", _to_spatial, is_camera_lock)
	emit_signal("view_type_changed", view_type)

func move_to_body(to_body: Body, to_view_type := -1, to_spherical_position := Vector3.ZERO,
		to_rotations := NULL_ROTATION, is_instant_move := false) -> void:
	assert(DPRINT and prints("move_to_body", to_body, to_view_type, is_instant_move) or true)
	var to_selection_item := _registrar.get_selection_for_body(to_body)
	move(to_selection_item, to_view_type, to_spherical_position, to_rotations, is_instant_move)

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
	_orient_to_local_pole_sq = pow(orient_to_local_pole / fov, 2)
	_orient_to_ecliptic_sq = pow(orient_to_ecliptic / fov, 2)
	_follow_orbit_dist_sq = pow(follow_orbit / fov, 2)
	_min_dist_sq = pow(selection_item.view_min_distance, 2.0) * 50.0 / fov
	if !suppress_move:
		move(null, -1, Vector3.ZERO, NULL_ROTATION, true)
	emit_signal("focal_length_changed", focal_length)

func change_camera_lock(new_lock: bool) -> void:
	if is_camera_lock != new_lock:
		is_camera_lock = new_lock
		emit_signal("camera_lock_changed", new_lock)
		if new_lock:
			if view_type > VIEW_TOP:
				view_type = _view_type_memory

func tree_manager_process(engine_delta: float) -> void:
	var is_dist_change := false
	if is_moving:
		_move_progress += engine_delta
		if _move_progress < _transition_time:
			_process_moving()
		else: # end the move
			is_moving = false
			is_dist_change = true
			if parent != _to_spatial:
				_do_camera_handoff() # happened at halfway unless is_instant_move
	if !is_moving:
		_process_not_moving(engine_delta, is_dist_change)
	if CENTER_ORIGIN_SHIFTING:
		_top_body.translation -= parent.global_transform.origin
	transform = _transform

# ********************* VIRTUAL & PRIVATE FUNCTIONS ***************************

func _ready() -> void:
	_on_ready()

func _on_ready():
	name = "BCamera"
	Global.connect("about_to_free_procedural_nodes", self, "_prepare_to_free", [], CONNECT_ONESHOT)
	Global.connect("about_to_start_simulator", self, "_start_sim", [], CONNECT_ONESHOT)
	Global.connect("gui_refresh_requested", self, "_send_gui_refresh")
	Global.connect("run_state_changed", self, "_set_run_state")
	Global.connect("move_camera_to_selection_requested", self, "move")
	Global.connect("move_camera_to_body_requested", self, "move_to_body")
	Global.connect("setting_changed", self, "_settings_listener")
	transform = _transform
	var dist := _transform.origin.length_squared()
	near = dist * NEAR_DIST_MULTIPLIER
	far = dist * FAR_DIST_MULTIPLIER
	pause_mode = PAUSE_MODE_PROCESS
	parent = get_parent()
	_to_spatial = parent
	_from_spatial = parent
	selection_item = _registrar.get_selection_for_body(parent)
	_from_selection_item = selection_item
	focal_length_index = init_focal_length_index
	focal_length = focal_lengths[focal_length_index]
	fov = math.get_fov_from_focal_length(focal_length)
	_follow_orbit_dist_sq = pow(follow_orbit / fov, 2)
	_orient_to_local_pole_sq = pow(orient_to_local_pole / fov, 2)
	_orient_to_ecliptic_sq = pow(orient_to_ecliptic / fov, 2)
	_min_dist_sq = pow(selection_item.view_min_distance, 2.0) * 50.0 / fov
	_set_run_state(Global.state.is_running)
	Global.emit_signal("camera_ready", self)
	print("BCamera ready...")

func _set_run_state(is_running: bool) -> void:
	set_process(is_running)
	set_process_unhandled_input(is_running)

func _start_sim(_is_new_game: bool) -> void:
	move(null, -1, Vector3.ZERO, NULL_ROTATION, true)

func _prepare_to_free() -> void:
	Global.disconnect("run_state_changed", self, "_set_run_state")
	Global.disconnect("gui_refresh_requested", self, "_send_gui_refresh")
	Global.disconnect("move_camera_to_selection_requested", self, "move")
	Global.disconnect("move_camera_to_body_requested", self, "move_to_body")
	selection_item = null
	parent = null
	_to_spatial = null
	_from_spatial = null
	_move_spatial = null
	_top_body = null

func _process_moving() -> void:
	var ease_progress := ease(_move_progress / _transition_time, -ease_exponent)
	# Hand-off at halfway point avoids imprecision shakes at either end
	if parent != _to_spatial and ease_progress > 0.5:
		_do_camera_handoff()
	# We interpolate position using our "spherical_position_" coordinates for the
	# common parent of the move. E.g., we move around Jupiter (not through it
	# if going from Io to Europa. Basis is interpolated more straightforwardly
	# using transform.basis.
	var from_transform := _get_transform(_from_selection_item, _from_view_type, _from_spherical_position,
			_from_camera_rotation)
	var to_transform := _get_transform(selection_item, view_type, spherical_position, camera_rotation)
	var global_common_translation := _move_spatial.global_transform.origin
#	var common_north = _move_spatial.north_pole # FIXME
	var from_common_translation := from_transform.origin \
			+ _from_spatial.global_transform.origin - global_common_translation
	var to_common_translation := to_transform.origin \
			+ _to_spatial.global_transform.origin - global_common_translation
	var from_common_spherical_position := get_spherical_position(from_common_translation, _move_north, 0.0)
	var to_common_spherical_position := get_spherical_position(to_common_translation, _move_north, 0.0)
	# We can remap longitude to allow shorter travel over the PI/-PI transition.
	# However, we must commit at begining of move to a particular remapping and
	# stick to it.
	if _move_longitude_remap == LONGITUDE_REMAP_INIT:
		var view_longitude_diff := to_common_spherical_position[0] - from_common_spherical_position[0]
		if view_longitude_diff > PI:
			_move_longitude_remap = LONGITUDE_REMAP_FROM
		elif view_longitude_diff < -PI:
			_move_longitude_remap = LONGITUDE_REMAP_TO
		else:
			_move_longitude_remap = LONGITUDE_REMAP_NONE
	if _move_longitude_remap == LONGITUDE_REMAP_FROM:
		from_common_spherical_position[0] += TAU
	elif _move_longitude_remap == LONGITUDE_REMAP_TO:
		to_common_spherical_position[0] += TAU
	var interpolated_spherical_position := from_common_spherical_position.linear_interpolate(
			to_common_spherical_position, ease_progress)
	var interpolated_common_translation := convert_spherical_position(
			interpolated_spherical_position, _move_north, 0.0)

	_transform.origin = interpolated_common_translation + global_common_translation \
			- parent.global_transform.origin
	_transform.basis = from_transform.basis.slerp(to_transform.basis, ease_progress)

	var dist := _transform.origin.length()
	near = dist * NEAR_DIST_MULTIPLIER
	far = dist * FAR_DIST_MULTIPLIER
	if parent != _to_spatial: # use dist to target parent for GUI
		dist = (global_transform.origin - _to_spatial.global_transform.origin).length()
	emit_signal("range_changed", dist)

func _do_camera_handoff() -> void:
	parent.remove_child(self)
	_to_spatial.add_child(self)
	parent = _to_spatial
	emit_signal("parent_changed", parent)

func _process_not_moving(delta: float, is_dist_change := false) -> void:
	var is_camera_bump := false
	var is_rotation_change := false
	_transform = _get_transform(selection_item, view_type, spherical_position, camera_rotation)
	var move_vector := Vector3.ZERO
	var rotate_vector := Vector3.ZERO
	# mouse drag movement
	if _drag_l_button_segment_start and _drag_l_button_segment_start != _drag_l_button_current:
		var mouse_move := (_drag_l_button_current - _drag_l_button_segment_start) * delta * _mouse_move_rate * MOUSE_MOVE_ADJ
		_drag_l_button_segment_start = _drag_l_button_current
		move_vector.x = -mouse_move.x
		move_vector.y = mouse_move.y
	if _drag_r_button_segment_start and _drag_r_button_segment_start != _drag_r_button_current:
		var mouse_rotate := (_drag_r_button_current - _drag_r_button_segment_start) * delta
		_drag_r_button_segment_start = _drag_r_button_current
		# Mouse offset from center at start of drag determines amount of z-rotation vs xy-rotation
		var z_proportion := (2.0 * _drag_r_button_start - _viewport.size).length() / _viewport.size.x
		z_proportion -= mouse_rotate_min_z_at_offcenter
		z_proportion /= mouse_rotate_max_z_at_offcenter - mouse_rotate_min_z_at_offcenter
		z_proportion = clamp(z_proportion, 0.0, 1.0)
		var center_to_mouse := (_drag_r_button_segment_start - _viewport.size / 2.0).normalized()
		rotate_vector.z = center_to_mouse.cross(mouse_rotate) * z_proportion * _mouse_roll_rate * MOUSE_ROLL_ADJ
		mouse_rotate *= (1.0 - z_proportion) * _mouse_pitch_yaw_rate * MOUSE_PITCH_YAW_ADJ
		rotate_vector.x = mouse_rotate.y
		rotate_vector.y = mouse_rotate.x
	# mouse wheel zooming
	if _mouse_wheel_accumulator != 0:
		var use_now := int(_mouse_wheel_accumulator * delta / mouse_wheel_halflife_x2)
		if use_now == 0:
			use_now = -1 if _mouse_wheel_accumulator < 0 else 1
		_mouse_wheel_accumulator -= use_now
		move_vector.z = use_now * 0.002
	# key control
	if _move_action_pressed:
		move_vector += _move_action_pressed * delta
	if _rotate_action_pressed:
		rotate_vector += _rotate_action_pressed * delta
	if move_vector.z:
		_move_camera_radially(move_vector.z)
		is_dist_change = true
		is_camera_bump = true
	if move_vector.x or move_vector.y:
		_move_camera_tangentially(move_vector)
		is_rotation_change = true
		is_camera_bump = true
	if rotate_vector:
		_rotate_camera(rotate_vector)
		is_rotation_change = true
		is_camera_bump = true
	# flagged updates
	var dist_sq := _transform.origin.length_squared()
	if is_camera_bump and view_type != VIEW_UNCENTERED:
		if camera_rotation:
			view_type = VIEW_UNCENTERED
			emit_signal("view_type_changed", view_type)
		elif view_type != VIEW_CENTERED:
			view_type = VIEW_CENTERED
			emit_signal("view_type_changed", view_type)
	if is_dist_change:
		var dist := sqrt(dist_sq)
		emit_signal("range_changed", dist)
		near = dist * NEAR_DIST_MULTIPLIER
		far = dist * FAR_DIST_MULTIPLIER
		is_rotation_change = true
	if is_rotation_change:
		var north := _get_north(selection_item, dist_sq)
		_transform = _transform.looking_at(-_transform.origin, north)
		_transform.basis *= Basis(camera_rotation)

func _move_camera_radially(radial_movement: float) -> void:
	var origin := _transform.origin
	var dist_sq := origin.length_squared()
	dist_sq *= 1.0 + radial_movement * move_in_out_rate
	if dist_sq > _max_dist_sq:
		dist_sq = _max_dist_sq
	elif dist_sq < _min_dist_sq:
		dist_sq = _min_dist_sq
	origin = origin.normalized() * sqrt(dist_sq)
	_transform.origin = origin
	var north := _get_north(selection_item, dist_sq)
	spherical_position = get_spherical_position(origin, north)

func _move_camera_tangentially(move_vector: Vector3) -> void:
	# We're only interested in tangental compenents (x & y) but we need a
	# Vector3 for 3D camera_rotation.
	move_vector.z = 0.0
	move_vector = Basis(camera_rotation) * move_vector # any resulting z is ignored
	var origin := _transform.origin
	var dist_sq := origin.length_squared()
	var north := _get_north(selection_item, dist_sq)
	var angle_to_pole := origin.angle_to(north)
	var old_angle_to_pole := angle_to_pole
	angle_to_pole -= move_vector.y * move_tangentially_rate
	if angle_to_pole < MIN_ANGLE_TO_POLE:
		angle_to_pole = MIN_ANGLE_TO_POLE
	elif angle_to_pole > PI - MIN_ANGLE_TO_POLE:
		angle_to_pole = PI - MIN_ANGLE_TO_POLE
	var x_axis := north.cross(origin).normalized()
	origin = origin.rotated(x_axis, angle_to_pole - old_angle_to_pole)
	origin = origin.rotated(north, move_vector.x * move_tangentially_rate)
	_transform.origin = origin
	spherical_position = get_spherical_position(origin, north)

func _rotate_camera(delta_rotations: Vector3) -> void:
	var basis := Basis(camera_rotation)
	basis = basis.rotated(basis.x, delta_rotations.x)
	basis = basis.rotated(basis.y, delta_rotations.y)
	basis = basis.rotated(basis.z, delta_rotations.z)
	camera_rotation = basis.get_euler()

func _get_transform(selection_item_: SelectionItem, view_type_: int, spherical_position_: Vector3,
		camera_rotation_: Vector3) -> Transform:
	var dist := spherical_position_.z
	var dist_sq := dist * dist
	var north := _get_north(selection_item_, dist_sq)
	var orbit_anomaly := _get_orbit_anomaly(selection_item_, dist_sq)
	var view_type_translation: Vector3
	if !is_moving and view_type_ > VIEW_TOP:
		var delta_anomaly := 0.0
		if orbit_anomaly != -INF and _last_anomaly != -INF:
			delta_anomaly = orbit_anomaly - _last_anomaly
		view_type_translation = _transform.origin.rotated(north, delta_anomaly)
	else:
		view_type_translation = convert_spherical_position(spherical_position_, north, orbit_anomaly)
	_last_anomaly = orbit_anomaly
	var view_type_transform := Transform(Basis(), view_type_translation).looking_at(-view_type_translation, north)
	view_type_transform.basis *= Basis(camera_rotation_)
	return view_type_transform

func _get_orbit_anomaly(selection_item_: SelectionItem, dist_sq: float) -> float:
	if dist_sq < _follow_orbit_dist_sq:
		return selection_item_.get_orbit_anomaly_for_camera()
	return -INF

func _get_north(selection_item_: SelectionItem, dist_sq: float) -> Vector3:
	if !selection_item_.is_body:
		return ECLIPTIC_NORTH
	var local_north := selection_item_.get_north()
	if dist_sq <= _orient_to_local_pole_sq:
		return local_north
	elif dist_sq >= _orient_to_ecliptic_sq:
		return ECLIPTIC_NORTH
	else:
		var proportion := log(dist_sq / _orient_to_local_pole_sq) / log(_orient_to_ecliptic_sq / _orient_to_local_pole_sq)
		proportion = ease(proportion, -ease_exponent)
		var diff_vector := local_north - ECLIPTIC_NORTH
		return (local_north - diff_vector * proportion).normalized()

func _get_common_spatial(spatial1: Spatial, spatial2: Spatial) -> Spatial:
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

func _unhandled_input(event: InputEvent) -> void:
	_on_unhandled_input(event)
	
func _on_unhandled_input(event: InputEvent) -> void:
	var is_handled := false
	if event is InputEventMouseButton:
		# mouse-wheel accumulates and is spread out so zooming isn't jumpy
		if event.button_index == BUTTON_WHEEL_UP:
			_mouse_wheel_accumulator -= int(_mouse_in_out_rate * MOUSE_WHEEL_ADJ)
			is_handled = true
		elif event.button_index == BUTTON_WHEEL_DOWN:
			_mouse_wheel_accumulator += int(_mouse_in_out_rate * MOUSE_WHEEL_ADJ)
			is_handled = true
		# start/stop mouse drag or process a mouse click
		elif event.button_index == BUTTON_LEFT:
			if event.pressed:
				_drag_l_button_start = _viewport.get_mouse_position()
				_drag_l_button_segment_start = _drag_l_button_start
				_drag_l_button_current = _drag_l_button_start
			else:
				if _drag_l_button_start == _drag_l_button_current: # it was a mouse click, not drag movement
					Global.emit_signal("mouse_clicked_viewport_at", event.position, self, true)
				_drag_l_button_start = NULL_DRAG
				_drag_l_button_segment_start = NULL_DRAG
			is_handled = true
		elif event.button_index == BUTTON_RIGHT:
			if event.pressed:
				_drag_r_button_start = _viewport.get_mouse_position()
				_drag_r_button_segment_start = _drag_r_button_start
				_drag_r_button_current = _drag_r_button_start
#				var offcenter_length := (_drag_r_button_start - _viewport.size / 2.0).length()
#				if offcenter_length / _viewport.size.y > mouse_rotate_z_at_screen_proportion:
#					_drag_is_z_rotate = true
			else:
				if _drag_r_button_start == _drag_r_button_current: # it was a mouse click, not drag movement
					Global.emit_signal("mouse_clicked_viewport_at", event.position, self, false)
				_drag_r_button_start = NULL_DRAG
				_drag_r_button_segment_start = NULL_DRAG
#				_drag_is_z_rotate = false
			is_handled = true
	elif event is InputEventMouseMotion:
		# accumulate mouse drag motion
		if _drag_l_button_segment_start:
			_drag_l_button_current = _viewport.get_mouse_position()
			is_handled = true
		if _drag_r_button_segment_start:
			_drag_r_button_current = _viewport.get_mouse_position()
			is_handled = true
	elif event.is_action_type():
		if event.is_pressed():
			if event.is_action_pressed("camera_zoom_view"):
				move(null, VIEW_ZOOM, Vector3.ZERO, Vector3.ZERO, false)
			elif event.is_action_pressed("camera_45_view"):
				move(null, VIEW_45, Vector3.ZERO, Vector3.ZERO, false)
			elif event.is_action_pressed("camera_top_view"):
				move(null, VIEW_TOP, Vector3.ZERO, Vector3.ZERO, false)
			elif event.is_action_pressed("recenter"):
				move(null, -1, Vector3.ZERO, Vector3.ZERO, false)
			elif event.is_action_pressed("camera_left"):
				_move_action_pressed.x = -_key_move_rate
			elif event.is_action_pressed("camera_right"):
				_move_action_pressed.x = _key_move_rate
			elif event.is_action_pressed("camera_up"):
				_move_action_pressed.y = _key_move_rate
			elif event.is_action_pressed("camera_down"):
				_move_action_pressed.y = -_key_move_rate
			elif event.is_action_pressed("camera_in"):
				_move_action_pressed.z = -_key_in_out_rate
			elif event.is_action_pressed("camera_out"):
				_move_action_pressed.z = _key_in_out_rate
			elif event.is_action_pressed("pitch_up"):
				_rotate_action_pressed.x = _key_pitch_yaw_rate
			elif event.is_action_pressed("pitch_down"):
				_rotate_action_pressed.x = -_key_pitch_yaw_rate
			elif event.is_action_pressed("yaw_left"):
				_rotate_action_pressed.y = _key_pitch_yaw_rate
			elif event.is_action_pressed("yaw_right"):
				_rotate_action_pressed.y = -_key_pitch_yaw_rate
			elif event.is_action_pressed("roll_left"):
				_rotate_action_pressed.z = -_key_roll_rate
			elif event.is_action_pressed("roll_right"):
				_rotate_action_pressed.z = _key_roll_rate
			else:
				return  # no input handled
		else: # key release
			if event.is_action_released("camera_left"):
				_move_action_pressed.x = 0.0
			elif event.is_action_released("camera_right"):
				_move_action_pressed.x = 0.0
			elif event.is_action_released("camera_up"):
				_move_action_pressed.y = 0.0
			elif event.is_action_released("camera_down"):
				_move_action_pressed.y = 0.0
			elif event.is_action_released("camera_in"):
				_move_action_pressed.z = 0.0
			elif event.is_action_released("camera_out"):
				_move_action_pressed.z = 0.0
			elif event.is_action_released("pitch_up"):
				_rotate_action_pressed.x = 0.0
			elif event.is_action_released("pitch_down"):
				_rotate_action_pressed.x = 0.0
			elif event.is_action_released("yaw_left"):
				_rotate_action_pressed.y = 0.0
			elif event.is_action_released("yaw_right"):
				_rotate_action_pressed.y = 0.0
			elif event.is_action_released("roll_left"):
				_rotate_action_pressed.z = 0.0
			elif event.is_action_released("roll_right"):
				_rotate_action_pressed.z = 0.0
			else:
				return  # no input handled
		is_handled = true
	if is_handled:
		_tree.set_input_as_handled()

func _send_gui_refresh() -> void:
	if parent:
		emit_signal("parent_changed", parent)
	emit_signal("range_changed", translation.length())
	emit_signal("focal_length_changed", focal_length)
	emit_signal("camera_lock_changed", is_camera_lock)
	emit_signal("view_type_changed", view_type)

func _settings_listener(setting: String, value) -> void:
	match setting:
		"camera_transition_time":
			_transition_time = value
		"camera_mouse_in_out_rate":
			_mouse_in_out_rate = value
		"camera_mouse_move_rate":
			_mouse_move_rate = value
		"camera_mouse_pitch_yaw_rate":
			_mouse_pitch_yaw_rate = value
		"camera_mouse_roll_rate":
			_mouse_roll_rate = value
		"camera_key_in_out_rate":
			_key_in_out_rate = value
		"camera_key_move_rate":
			_key_move_rate = value
		"camera_key_pitch_yaw_rate":
			_key_pitch_yaw_rate = value
		"camera_key_roll_rate":
			_key_roll_rate = value
