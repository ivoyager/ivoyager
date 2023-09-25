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
extends Camera3D

# This camera works with the IVSelection object, which is a wrapper that can
# potentially hold anything (in ivoyager, IVBody [and TODO: IVLagrangePoint)].
# IVCamera recieves most of its control input from IVCameraHandler.
#
# Replacing this class should be possible but may be challenging. Very many
# GUI widgets are built to use it.
#
# The camera uses a 'perspective distance' when moving from body to body at
# close range. The distance is adjusted for body 'perspective_raduis' (usually
# the same as m_radius) so that it appears the same size in the view. At far
# distances there is no adjustment. (There is a transition between the two.)
# Hence, distance vars with name '_radii_meters' that are on the order of
# meters are adjusted to 'target radii'. Distance vars in units AU are what
# they appear to be. In the transition distance they are intermediate.
# This system *may* break for objects smaller than meters (not tested yet).

signal move_started(to_spatial, is_camera_lock) # to_spatial is not parent yet
signal parent_changed(spatial)
signal range_changed(camera_range)
signal latitude_longitude_changed(lat_long, is_ecliptic, selection)
signal focal_length_changed(focal_length)
signal camera_lock_changed(is_camera_lock)
signal up_lock_changed(flags, disabled_flags)
signal tracking_changed(flags, disabled_flags)


const math := preload("res://ivoyager/static/math.gd")
const utils := preload("res://ivoyager/static/utils.gd")

const Flags := IVEnums.CameraFlags
const ANY_UP_FLAGS := Flags.ANY_UP_FLAGS
const ANY_TRACK_FLAGS := Flags.ANY_TRACK_FLAGS
const DisabledFlags := IVEnums.CameraDisabledFlags

const IDENTITY_BASIS := Basis.IDENTITY
const ECLIPTIC_X := IDENTITY_BASIS.x # primary direction
const ECLIPTIC_Y := IDENTITY_BASIS.y
const ECLIPTIC_Z := IDENTITY_BASIS.z # ecliptic north
const NULL_VECTOR3 := Vector3(-INF, -INF, -INF)


const METER := IVUnits.METER
const KM := IVUnits.KM

const DPRINT := false
const UNIVERSE_SHIFTING := true # prevents "shakes" at high global position
const NEAR_MULTIPLIER := 0.1
const FAR_MULTIPLIER := 1e6 # see Note below
const POLE_LIMITER := PI / 2.1
const MIN_DIST_RADII_METERS := 1.5 * METER # really target radii; see 'perspective distance'

# Note: As of Godot 3.2.3, we had to lower FAR_MULTIPLIER from 1e9 to 1e6.
# It used to be that ~10 orders of magnitude was allowed between near and far.
# As of Godot 4.1.1, still breaks above 1e6. 

const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL
const PERSIST_PROPERTIES := [
	&"name",
	&"flags",
	&"is_camera_lock",
	&"selection",
	&"perspective_radius",
	&"view_position",
	&"view_rotations",
	&"focal_length",
	&"focal_length_index",
	&"_transform",
]

# ******************************* PERSISTED ***********************************

# public - read only except project init
var flags: int = Flags.UP_LOCKED | Flags.TRACK_ORBIT
var is_camera_lock := true

# public - read only! (use move methods to set; these are "to" during transfer)
var selection: IVSelection
var perspective_radius := KM
var view_position := Vector3(0.5, 2.5, 3.0) # spherical, relative to ref frame; r is 'perspective'
var view_rotations := Vector3.ZERO # euler, relative to looking_at(-origin, 'up')
var focal_length: float
var focal_length_index: int # use init_focal_length_index below

# private
var _transform := Transform3D(Basis(), Vector3(0, 0, KM)) # working value

# *****************************************************************************

# public - project init vars
var focal_lengths: Array[float] = [6.0, 15.0, 24.0, 35.0, 50.0] # ~fov 125.6, 75.8, 51.9, 36.9, 26.3
var init_focal_length_index := 2
var ease_exponent := 5.0 # DEPRECIATE: Make dynamic for distance / size
var gui_ecliptic_coordinates_dist := 1e6 * KM
var action_immediacy := 10.0 # how fast we use up the accumulators
var min_action := 0.002 # use all below this
var size_ratio_exponent := 0.9 # 0.0, none; 1.0 moves to same visual size
# 'perspective' settings
var perspective_close_radii := 500.0 # full perspective adjustment inside this
var perspective_far_dist := 1e9 * KM # no perspective adjustment outside this
var max_perspective_radii_meters := 1e9 * METER # really target radii; see 'perspective distance'
var min_perspective_radii_meters := 2.0 * METER # really target radii; see 'perspective distance'

# public read-only
var parent: Node3D # actual Node3D parent at this time
var is_moving := false # body to body move in progress
var disabled_flags := 0 # IVEnums.CameraDisabledFlags

# private
var _universe: Node3D = IVGlobal.program.Universe
var _settings: Dictionary = IVGlobal.settings
var _world_targeting: Array = IVGlobal.world_targeting
var _max_dist: float = IVGlobal.max_camera_distance

# motions / rotations
var _motion_accumulator := Vector3.ZERO
var _rotation_accumulator := Vector3.ZERO

# move_to
var _move_time: float
var _is_interupted_move := false
var _interupted_transform: Transform3D
var _reference_basis: Basis
var _to_spatial: Node3D
var _trasfer_spatial: Node3D
var _from_spatial: Node3D
var _from_selection: IVSelection
var _from_flags := flags
var _from_perspective_radius := KM
var _from_view_position := Vector3(0, 0, 3)
var _from_view_rotations := Vector3.ZERO

# gui signalling
var _gui_range := NAN
var _gui_latitude_longitude := Vector2(NAN, NAN)

# settings
var _transfer_time: float = _settings[&"camera_transfer_time"]


# virtual functions

func _ready() -> void:
	name = &"IVCamera"
	IVGlobal.system_tree_ready.connect(_on_system_tree_ready, CONNECT_ONE_SHOT)
	IVGlobal.simulator_started.connect(_on_simulator_started, CONNECT_ONE_SHOT)
	IVGlobal.about_to_free_procedural_nodes.connect(_prepare_to_free, CONNECT_ONE_SHOT)
	IVGlobal.update_gui_requested.connect(_send_gui_refresh)
	IVGlobal.move_camera_requested.connect(move_to)
	IVGlobal.setting_changed.connect(_settings_listener)
	transform = _transform
	focal_length_index = init_focal_length_index
	focal_length = focal_lengths[focal_length_index]
	fov = math.get_fov_from_focal_length(focal_length)
	_world_targeting[2] = self
	_world_targeting[3] = fov
	IVGlobal.camera_ready.emit(self)
	set_process(false) # don't process until sim started


func _process(delta: float) -> void:
	# We process our working '_transform', then update here.
	_reference_basis = _get_reference_basis(selection, flags)
	if is_moving:
		_process_move_to(delta)
	else:
		_process_motions_and_rotations(delta)
	if UNIVERSE_SHIFTING:
		# Camera will be at global translation (0,0,0) after this step.
		# The -= operator works because current Universe translation is part
		# of global_translation, so we are removing old shift at the same time
		# we add our new shift.
		_universe.position -= global_position
	transform = _transform
	_signal_range_latitude_longitude()
	
	# We set our visual range based on current parent range. Note that setting
	# far too high breaks near, making small objects invisible. Unfortunately,
	# limiting far causes distant objects (e.g., orbit lines) to disappear when
	# zoomed in to small objects. The allowed orders of magnitude between near
	# and far has changed over Godot development, so experimentation is needed.
	var dist := position.length()
	near = dist * NEAR_MULTIPLIER
	far = dist * FAR_MULTIPLIER


# public functions

func add_motion(motion_amount: Vector3) -> void:
	# Rotate around target (x, y) or move in/out (z).
	_motion_accumulator += motion_amount


func add_rotation(rotation_amount: Vector3) -> void:
	# Rotate in-place: x, pitch; y, yaw; z, roll.
	_rotation_accumulator += rotation_amount


func move_to(to_selection: IVSelection, to_flags := 0, to_view_position := NULL_VECTOR3,
		to_view_rotations := NULL_VECTOR3, is_instant_move := false) -> void:
	# Note: call IVCameraHandler.move_to() or move_to_by_name() to move camera
	# *and* change selection.
	# Null or null-equivilant args tell the camera to keep its current value.
	# For this purpose, individual -INF elements in to_view_position and
	# to_view_rotations are treated as 'null' (ie, we can set 1 or 2 elements).
	# Note: some flags may override elements of position or rotation.
	assert(!DPRINT or IVDebug.dprint("move_to", [to_selection, to_flags, to_view_position,
			to_view_rotations, is_instant_move]))
	
	# overrides
	if to_flags & Flags.UP_LOCKED:
		if to_view_rotations != NULL_VECTOR3:
			to_view_rotations.z = 0.0 # cancel roll, if any
	if (to_view_rotations != NULL_VECTOR3 and to_view_rotations.z != -INF
			and to_view_rotations.z): # any roll unlocks 'up'
		to_flags |= Flags.UP_UNLOCKED
	
	var to_up_flags := to_flags & ANY_UP_FLAGS
	var to_track_flags := to_flags & ANY_TRACK_FLAGS
	
	assert(to_up_flags & (to_up_flags - 1) == 0, "only 1 or 0 bits allowed")
	assert(to_track_flags & (to_track_flags - 1) == 0, "only 1 or 0 bits allowed")

	# don't move if *nothing* has changed and is_instant_move == false
	if (
			!is_instant_move
			and (!to_selection or to_selection == selection)
			and (!to_up_flags or to_up_flags == flags & ANY_UP_FLAGS)
			and (!to_track_flags or to_track_flags == flags & ANY_TRACK_FLAGS)
			and (to_view_position == NULL_VECTOR3 or to_view_position == view_position)
			and (to_view_rotations == NULL_VECTOR3 or to_view_rotations == view_rotations)
	):
		return
	
	# data needed during the move
	_from_selection = selection
	_from_flags = flags
	_from_perspective_radius = perspective_radius
	_from_view_position = view_position
	_from_view_rotations = view_rotations
	_from_spatial = parent
	
	_trasfer_spatial = utils.get_ancestor_spatial(_from_spatial, _to_spatial)
	
	# change booleans
	var is_up_change: bool = ((to_up_flags and to_up_flags != flags & ANY_UP_FLAGS)
			or (to_view_rotations != NULL_VECTOR3 and to_view_rotations.z != -INF
			and to_view_rotations.z and flags & Flags.UP_LOCKED))
	var is_track_change := to_track_flags and to_track_flags != flags & ANY_TRACK_FLAGS
	
	# set selection and flags
	if to_selection and to_selection.spatial:
		selection = to_selection
		perspective_radius = selection.get_perspective_radius()
		_to_spatial = to_selection.spatial
	if is_up_change:
		flags &= ~ANY_UP_FLAGS
		flags |= to_up_flags
	if is_track_change:
		flags &= ~ANY_TRACK_FLAGS
		flags |= to_track_flags
	if to_view_rotations != NULL_VECTOR3:
		if to_view_rotations.z != -INF and to_view_rotations.z:
			flags &= ~Flags.UP_LOCKED
			flags |= Flags.UP_UNLOCKED
	
	# if track change w/out specified longitude, go to current longitude in new reference frame
	if is_track_change and to_view_position.x == -INF:
		var current_basis := _get_reference_basis(selection, flags)
		var current_view_position = math.get_rotated_spherical3(position, current_basis)
		to_view_position.x = current_view_position.x
	
	# set position & rotaion
	if to_view_position != NULL_VECTOR3:
		if to_view_position.x != -INF:
			view_position.x = to_view_position.x
		if to_view_position.y != -INF:
			view_position.y = to_view_position.y
		if to_view_position.z != -INF:
			view_position.z = to_view_position.z
	if to_view_rotations != NULL_VECTOR3:
		if to_view_rotations.x != -INF:
			view_rotations.x = to_view_rotations.x
		if to_view_rotations.y != -INF:
			view_rotations.y = to_view_rotations.y
		if to_view_rotations.z != -INF:
			view_rotations.z = to_view_rotations.z
	if flags & Flags.UP_LOCKED:
		view_rotations.z = 0.0 # up lock overrides roll
	view_position.z = clamp(view_position.z, MIN_DIST_RADII_METERS, _max_dist)
	
	# initiate move
	if is_instant_move:
		_move_time = _transfer_time # finishes move on next frame
	elif !is_moving:
		_move_time = 0.0 # starts move on next frame
	else:
		_is_interupted_move = true
		_interupted_transform = transform
		_move_time = 0.0
	is_moving = true
	
	# TODO?: Allow accumulators during move?
	_motion_accumulator = Vector3.ZERO
	_rotation_accumulator = Vector3.ZERO
	
	# signals
	if is_up_change:
		up_lock_changed.emit(flags, disabled_flags)
	if is_track_change:
		tracking_changed.emit(flags, disabled_flags)
	move_started.emit(_to_spatial, is_camera_lock)


func set_up_lock(is_locked: bool) -> void:
	# Invokes a move to set, but not to unset.
	if is_locked == bool(flags & Flags.UP_LOCKED):
		return
	if is_locked:
		move_to(null, Flags.UP_LOCKED)
	else:
		flags &= ~Flags.UP_LOCKED
		flags |= Flags.UP_UNLOCKED
		up_lock_changed.emit(flags, disabled_flags)


func increment_focal_length(increment: int) -> void:
	var new_fl_index = focal_length_index + increment
	if new_fl_index < 0:
		new_fl_index = 0
	elif new_fl_index >= focal_lengths.size():
		new_fl_index = focal_lengths.size() - 1
	if new_fl_index != focal_length_index:
		set_focal_length_index(new_fl_index, false)


func set_focal_length_index(new_fl_index, _suppress_move := false) -> void:
	focal_length_index = new_fl_index
	focal_length = focal_lengths[focal_length_index]
	fov = math.get_fov_from_focal_length(focal_length)
	_world_targeting[3] = fov
	focal_length_changed.emit(focal_length)


func change_camera_lock(new_lock: bool) -> void:
	if is_camera_lock != new_lock:
		is_camera_lock = new_lock
		camera_lock_changed.emit(new_lock)


# private functions

func _on_system_tree_ready(_is_new_game: bool) -> void:
	parent = get_parent()
	_to_spatial = parent
	_from_spatial = parent
	if !selection: # new game
		var _SelectionManager_: Script = IVGlobal.procedural_classes._SelectionManager_
		@warning_ignore("unsafe_method_access") # project subclass may override static func
		selection = _SelectionManager_.get_or_make_selection(parent.name)
		assert(selection)
		perspective_radius = selection.get_perspective_radius()
	_from_selection = selection
	_from_perspective_radius = perspective_radius


func _on_simulator_started() -> void:
	set_process(true)


func _prepare_to_free() -> void:
	# Some deconstruction needed to prevent freeing object signalling errors (Godot3.x)
	set_process(false)
	IVGlobal.update_gui_requested.disconnect(_send_gui_refresh)
	IVGlobal.move_camera_requested.disconnect(move_to)
	IVGlobal.setting_changed.disconnect(_settings_listener)
	selection = null
	parent = null
	_to_spatial = null
	_trasfer_spatial = null
	_from_selection = null
	_from_spatial = null


func _process_move_to(delta: float) -> void:
	_move_time += delta
	if _is_interupted_move:
		_move_time += delta # double-time; user is in a hurry!
	if _move_time >= _transfer_time: # end the move
		is_moving = false
		_is_interupted_move = false
		if parent != _to_spatial:
			_do_handoff()
		_process_motions_and_rotations(delta)
		return
	
	# Interpolate from where we would be (if move hadn't happened) to where
	# we are going. We continue to calculate were we would be so there isn't
	# an abrupt velocity change (although that happens in an interupted move).
	var from_transform: Transform3D
	if _is_interupted_move:
		from_transform = _interupted_transform
	else:
		var from_reference_basis := _get_reference_basis(_from_selection, _from_flags)
		from_transform = _get_view_transform(_from_view_position, _from_view_rotations,
				from_reference_basis, _from_perspective_radius)
	var to_transform := _get_view_transform(view_position, view_rotations, _reference_basis,
			perspective_radius)
	var progress := ease(_move_time / _transfer_time, -ease_exponent)
	_interpolate_path(from_transform, to_transform, progress)
	
	# Handoff at halfway point avoids precision shakes at either end.
	if progress > 0.5 and parent != _to_spatial:
		_do_handoff()


func _do_handoff() -> void:
	assert(!DPRINT or IVDebug.dprint("_do_handoff()", tr(parent.name), tr(_to_spatial.name)))
	parent.remove_child(self)
	_to_spatial.add_child(self)
	parent = _to_spatial
	parent_changed.emit(parent)


func _interpolate_path(from_transform: Transform3D, to_transform: Transform3D, progress: float) -> void:
	# Interpolate spherical coordinates around a reference Spatial. Reference
	# 'xfer' is either the parent (if 'from' or 'to' is child of the other) or
	# common ancestor. This is likely the dominant view object during
	# transition, so we want to minimize orientation change relative to it.
	# This also avoids going through a planet when moving among its moons.
	#
	# TODO: It's a little jarring when the shortest spherical path is way off
	# the ecliptic plane (or 'xfer' equitorial). Wih some work we could
	# suppress that.
	
	# translation
	var xfer_global_translation := _trasfer_spatial.global_position
	var from_global_translation := _from_spatial.global_position + from_transform.origin
	var to_global_translation := _to_spatial.global_position + to_transform.origin
	var from_xfer_translation := from_global_translation - xfer_global_translation
	var to_xfer_translation := to_global_translation - xfer_global_translation
	# Godot 3.5.2 BUG? angle_to() seems to break with large vectors. Needs testing.
	# Workaroud here is to normalize before angle operations.
	var from_xfer_direction := from_xfer_translation.normalized()
	var to_xfer_direction := to_xfer_translation.normalized()
	var rotation_axis := from_xfer_direction.cross(to_xfer_direction).normalized()
	if !rotation_axis: # edge case
		rotation_axis = Vector3(0.0, 0.0, 1.0)
	var path_angle := from_xfer_direction.angle_to(to_xfer_direction) # < PI
	var xfer_translation := from_xfer_direction.rotated(rotation_axis, path_angle * progress)
	xfer_translation *= lerp(from_xfer_translation.length(), to_xfer_translation.length(), progress)
	var translation_ := xfer_translation + xfer_global_translation - parent.global_position

	# basis
	var from_global_basis := _from_spatial.global_transform.basis * from_transform.basis
	var to_global_basis := _to_spatial.global_transform.basis * to_transform.basis
	var from_global_quat := Quaternion(from_global_basis)
	var to_global_quat := Quaternion(to_global_basis)
	var global_quat := from_global_quat.slerp(to_global_quat, progress)
	var global_basis := Basis(global_quat)
	var basis_ := parent.global_transform.basis.inverse() * global_basis
	
	# set the working transform
	_transform = Transform3D(basis_, translation_)


func _process_motions_and_rotations(delta: float) -> void:
	# maintain present position based on tracking
	_transform = _get_view_transform(view_position, view_rotations, _reference_basis,
			perspective_radius)
	# process accumulated user inputs
	if _motion_accumulator:
		_process_motion(delta)
	if _rotation_accumulator:
		_process_rotation(delta)


func _process_motion(delta: float) -> void:
	
	# take motion from accumulator
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
	
	# Apply x,y as rotation and z as scaler to our origin. Basis is treated
	# differently for the 'up locked' and 'unlocked' cases.
	var origin := _transform.origin
	var basis_ := _transform.basis

	if bool(flags & Flags.UP_LOCKED):
		# A pole limiter prevents pole traversal. A spin dampener suppresses
		# high longitudinal rate when near pole. There is NO change in
		# view_rotations.
		var spin_dampener := cos(view_position.y)
		move_now.x *= spin_dampener
		var latitude = view_position.y + move_now.y
		if latitude > POLE_LIMITER:
			move_now.y = POLE_LIMITER - view_position.y
		elif latitude < -POLE_LIMITER:
			move_now.y = -POLE_LIMITER -view_position.y
		origin = origin.rotated(basis_.y, move_now.x)
		origin = origin.rotated(basis_.x, -move_now.y)
		origin *= 1.0 + move_now.z
		view_position = math.get_rotated_spherical3(origin, _reference_basis)
		view_position.z = clamp(_get_perspective_dist(view_position.z, perspective_radius),
				MIN_DIST_RADII_METERS, _max_dist)
		_transform = _get_view_transform(view_position, view_rotations, _reference_basis,
				perspective_radius)
		
	else:
		# 'Free' rotation of origin and basis around target. Allows pole
		# traversal and camera roll. We need to back-calculate view_rotations.
		origin = origin.rotated(basis_.y, move_now.x)
		basis_ = basis_.rotated(basis_.y, move_now.x)
		origin = origin.rotated(basis_.x, -move_now.y)
		basis_ = basis_.rotated(basis_.x, -move_now.y)
		origin *= 1.0 + move_now.z
		view_position = math.get_rotated_spherical3(origin, _reference_basis)
		view_position.z = clamp(_get_perspective_dist(view_position.z, perspective_radius),
				MIN_DIST_RADII_METERS, _max_dist)
		_transform = Transform3D(basis_, origin)
		# back-calculate view_rotations
		var unrotated_transform := Transform3D(IDENTITY_BASIS, origin).looking_at(
			-origin, _reference_basis.z)
		var unrotated_basis := unrotated_transform.basis
		var rotations_basis := unrotated_basis.inverse() * basis_
		view_rotations = rotations_basis.get_euler()


func _process_rotation(delta: float) -> void:
	# Note: Although we follow z-up astronomy convention elsewhere, the camera
	# uses y-up, z-forward, x-lateral.
	var is_up_locked := bool(flags & Flags.UP_LOCKED)
	
	# take rotation from accumulator
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
	if is_up_locked:
		_rotation_accumulator.z = 0.0 # discard
	else:
		if abs(rotate_now.z) > min_action:
			rotate_now.z *= action_proportion
			_rotation_accumulator.z -= rotate_now.z
		else:
			_rotation_accumulator.z = 0.0
	
	# apply rotation to a view basis, then to _transform
	var view_basis := Basis.from_euler(view_rotations) # TEST34: default order ok?
	if is_up_locked: # use a pole limiter for pitch, don't roll
		var pitch = view_rotations.x + rotate_now.x
		if pitch > POLE_LIMITER:
			rotate_now.x = POLE_LIMITER - view_rotations.x
		elif pitch < -POLE_LIMITER:
			rotate_now.x = -POLE_LIMITER - view_rotations.x
		view_basis = view_basis.rotated(view_basis.y, rotate_now.y) # yaw
		view_basis = view_basis.rotated(view_basis.x, rotate_now.x) # pitch
		view_rotations = view_basis.get_euler()
		# remove small residual z rotation (precision error?)
		view_basis = view_basis.rotated(view_basis.z, -view_rotations.z)
		view_rotations.z = 0.0
	else:
		view_basis = view_basis.rotated(view_basis.y, rotate_now.y) # yaw
		view_basis = view_basis.rotated(view_basis.x, rotate_now.x) # pitch
		view_basis = view_basis.rotated(view_basis.z, rotate_now.z) # roll
		view_rotations = view_basis.get_euler()
	_transform = _transform.looking_at(-_transform.origin, _reference_basis.z)
	_transform.basis *= view_basis


func _get_view_transform(view_position_: Vector3, view_rotations_: Vector3,
		reference_basis: Basis, perspective_radius_: float) -> Transform3D:
	view_position_.z = clamp(_convert_perspective_dist(view_position_.z, perspective_radius_),
			MIN_DIST_RADII_METERS, _max_dist)
	var view_translation := math.convert_rotated_spherical3(view_position_, reference_basis)
	
	# FIXME: Below line breaks when METER is set to low values (e.g., ~1e-9)
	# due to Godot thinking origin == target.
	var view_transform := Transform3D(IDENTITY_BASIS, view_translation).looking_at(
			-view_translation, reference_basis.z)
	view_transform.basis *= Basis.from_euler(view_rotations_) # TEST34: default order ok?
	return view_transform


static func _get_reference_basis(selection_: IVSelection, flags_: int) -> Basis:
	if flags_ & Flags.TRACK_GROUND:
		return selection_.get_ground_basis()
	if flags_ & Flags.TRACK_ORBIT:
		return selection_.get_orbit_basis()
	return selection_.get_ecliptic_basis() # identity basis for any IVBody


func _get_perspective_dist(dist: float, radius: float) -> float:
	# 'Perspective' distance allows camera to move among bodies maintaining the
	# same body size in the viewscreen when close. However, we don't want any
	# adjustment when very far from the body (ie, at solar system view).
	# When close, persp_dist = dist / radius.
	# When far, persp_dist = dist / 1 meter. (So radius doesn't matter.)
	if dist >= perspective_far_dist:
		return dist
	if radius > max_perspective_radii_meters:
		radius = max_perspective_radii_meters
	elif radius < min_perspective_radii_meters:
		radius = min_perspective_radii_meters
	var cr := perspective_close_radii * radius
	if dist <= cr:
		return METER * dist / radius
		
	# Equation covers the transition zone (continuous but not smooth).
	return ((dist - cr) # [d]
			* (perspective_far_dist - METER * perspective_close_radii) # [d]
			/ (perspective_far_dist - cr) # [d]
			+ METER * perspective_close_radii) # [d]


func _convert_perspective_dist(persp_dist: float, radius: float) -> float:
	# Inverse of _get_perspective_dist().
	if persp_dist >= perspective_far_dist:
		return persp_dist
	if radius > max_perspective_radii_meters:
		radius = max_perspective_radii_meters
	if persp_dist <= METER * perspective_close_radii:
		return persp_dist * radius / METER
	
	var cr := perspective_close_radii * radius # [d]
	return ((persp_dist - METER * perspective_close_radii) # [d]
			* (perspective_far_dist - cr) # [d]
			/ (perspective_far_dist - METER * perspective_close_radii) # [d]
			+ cr) # [d]


func _signal_range_latitude_longitude(is_refresh := false) -> void:
	if is_refresh:
		_gui_range = NAN
		_gui_latitude_longitude = Vector2(NAN, NAN)
	var gui_translation: Vector3
	if _to_spatial == parent:
		gui_translation = position
	else: # move in progress: GUI is showing _to_spatial, not current parent
		gui_translation = global_position - _to_spatial.global_position
	var dist := gui_translation.length()
	if _gui_range != dist:
		_gui_range = dist
		range_changed.emit(dist)
		
		# debug
#		var radius := selection.get_perspective_radius()
#		var persp_dist := _get_perspective_dist(dist, radius)
#		var conv := _convert_perspective_dist(persp_dist, radius)
#		prints(persp_dist, conv, dist, conv / dist, dist / persp_dist)
		
		
	var is_ecliptic := dist > gui_ecliptic_coordinates_dist
	var lat_long: Vector2
	if is_ecliptic:
		var ecliptic_translation = global_position - _universe.position
		lat_long = math.get_latitude_longitude(ecliptic_translation)
	else:
		lat_long = selection.get_latitude_longitude(gui_translation)
	if _gui_latitude_longitude != lat_long:
		_gui_latitude_longitude = lat_long
		latitude_longitude_changed.emit(lat_long, is_ecliptic, selection)


func _send_gui_refresh() -> void:
	parent_changed.emit(parent)
	focal_length_changed.emit(focal_length)
	up_lock_changed.emit(flags, disabled_flags)
	tracking_changed.emit(flags, disabled_flags)
	_signal_range_latitude_longitude(true)


func _settings_listener(setting: StringName, value: Variant) -> void:
	match setting:
		&"camera_transfer_time":
			_transfer_time = value

