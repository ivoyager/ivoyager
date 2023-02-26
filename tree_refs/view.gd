# view.gd
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
class_name IVView
extends Reference

# Can optionally keep camera state, HUDs visibilities & colors, and/or time
# state. The object is structured for persistence via game save or cache.


const NULL_ROTATION := Vector3(-INF, -INF, -INF)

const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL
const PERSIST_PROPERTIES := [
	"has_camera_state",
	"selection_name",
	"camera_flags",
	"view_position",
	"view_rotations",
	
	"has_huds_visibility_state",
	"name_visible_flags",
	"symbol_visible_flags",
	"orbit_visible_flags",
	"visible_points_groups",
	"visible_orbits_groups",
	
	"has_huds_color_state",
	"body_orbit_colors",
	
	
	"has_time_state",
	"is_real_world_time",
	"time",
	"speed_index",
	"is_reversed",
]

# persisted
var has_camera_state := false
var selection_name := ""
var camera_flags := 0 # IVEnums.CameraFlags
var view_position := Vector3.ZERO # spherical; relative to orbit or ground ref
var view_rotations := NULL_ROTATION # euler; relative to looking_at(-origin, north)

var has_huds_visibility_state := false
var name_visible_flags := 0 # exclusive w/ symbol_visible_flags
var symbol_visible_flags := 0 # exclusive w/ name_visible_flags
var orbit_visible_flags := 0
var visible_points_groups := []
var visible_orbits_groups := []

var has_huds_color_state := false
var body_orbit_colors := {}

var has_time_state := false # used by Planetarium
var is_real_world_time := false
var time := 0.0
var speed_index := 0
var is_reversed := false


# private
var _viewport := IVGlobal.get_viewport()
var _SelectionManager_: Script = IVGlobal.script_classes._SelectionManager_
var _body_huds_state: IVBodyHUDsState = IVGlobal.program.BodyHUDsState
var _sbg_huds_state: IVSBGHUDsState = IVGlobal.program.SBGHUDsState
var _timekeeper: IVTimekeeper = IVGlobal.program.Timekeeper
var _version_hash := PERSIST_PROPERTIES.hash()


func reset() -> void:
	has_camera_state = false
	has_huds_visibility_state = false
	has_huds_color_state = false
	has_time_state = false
	# below not needed except to reduce storage size
	selection_name = ""
	visible_points_groups.clear()
	visible_orbits_groups.clear()
	body_orbit_colors.clear()


func get_cache_data() -> Array:
	var data := []
	data.append(has_camera_state)
	if has_camera_state:
		data.append(selection_name)
		data.append(camera_flags)
		data.append(view_position)
		data.append(view_rotations)
	data.append(has_huds_visibility_state)
	if has_huds_visibility_state:
		data.append(name_visible_flags)
		data.append(symbol_visible_flags)
		data.append(orbit_visible_flags)
		data.append(visible_points_groups)
		data.append(visible_orbits_groups)
	data.append(has_huds_color_state)
	if has_huds_color_state:
		data.append(body_orbit_colors)
	data.append(has_time_state)
	if has_time_state:
		data.append(is_real_world_time)
		data.append(time)
		data.append(speed_index)
		data.append(is_reversed)
	data.append(_version_hash)
	return data


func set_cache_data(data) -> bool:
	# Tests data integrity and returns false on failure.
	if typeof(data) != TYPE_ARRAY:
		return false
	if !data:
		return false
	var version_hash = data[-1] # untyped for safety
	if typeof(version_hash) != TYPE_INT:
		return false
	if version_hash != _version_hash:
		return false
	var i := 0
	has_camera_state = data[i]
	i += 1
	if has_camera_state:
		selection_name = data[i]
		camera_flags = data[i + 1]
		view_position = data[i + 2]
		view_rotations = data[i + 3]
		i += 4
	has_huds_visibility_state = data[i]
	i += 1
	if has_huds_visibility_state:
		name_visible_flags = data[i]
		symbol_visible_flags = data[i + 1]
		orbit_visible_flags = data[i + 2]
		visible_points_groups = data[i + 3]
		visible_orbits_groups = data[i + 4]
		i += 5
	has_huds_color_state = data[i]
	i += 1
	if has_huds_color_state:
		body_orbit_colors = data[i]
		i += 1
	has_time_state = data[i]
	i += 1
	if has_time_state:
		is_real_world_time = data[i]
		time = data[i + 1]
		speed_index = data[i + 2]
		is_reversed = data[i + 3]
	return true


func set_camera_data(has_camera_state_: bool, selection_name_: String, camera_flags_: int,
		view_position_: Vector3, view_rotations_: Vector3) -> void:
	has_camera_state = has_camera_state_
	selection_name = selection_name_
	camera_flags = camera_flags_
	view_position = view_position_
	view_rotations = view_rotations_


func set_huds_visibility_data(has_huds_visibility_state_: bool, name_visible_flags_: int,
		symbol_visible_flags_: int, orbit_visible_flags_: int, visible_points_groups_: Array,
		visible_orbits_groups_: Array) -> void:
	# Keeps arrays!
	has_huds_visibility_state = has_huds_visibility_state_
	name_visible_flags = name_visible_flags_
	symbol_visible_flags = symbol_visible_flags_
	orbit_visible_flags = orbit_visible_flags_
	visible_points_groups = visible_points_groups_
	visible_orbits_groups = visible_orbits_groups_


func set_huds_color_data(has_huds_color_state_: bool, body_orbit_colors_: Dictionary) -> void:
	# Keeps dictionaries!
	has_huds_color_state = has_huds_color_state_
	body_orbit_colors = body_orbit_colors_


func set_time_data(has_time_state_: bool, time_: float, speed_index_: int, is_reversed_: int
		) -> void:
	has_time_state = has_time_state_
	time = time_
	speed_index = speed_index_
	is_reversed = is_reversed_


# camera state

func save_camera_state() -> void:
	has_camera_state = true
	var camera: IVCamera = _viewport.get_camera()
	selection_name = camera.selection.name
	camera_flags = camera.flags
	view_position = camera.view_position
	view_rotations = camera.view_rotations


func set_camera_state(is_instant_move := false) -> void:
	if !has_camera_state:
		return
	var camera: IVCamera = _viewport.get_camera()
	var selection: IVSelection = _SelectionManager_.get_or_make_selection(selection_name)
	assert(selection)
	camera.move_to(selection, camera_flags, view_position, view_rotations, is_instant_move)


# HUDs visibility state

func save_huds_visibility_state() -> void:
	has_huds_visibility_state = true
	name_visible_flags = _body_huds_state.name_visible_flags
	symbol_visible_flags = _body_huds_state.symbol_visible_flags
	orbit_visible_flags = _body_huds_state.orbit_visible_flags
	visible_points_groups = _sbg_huds_state.get_visible_points_groups()
	visible_orbits_groups = _sbg_huds_state.get_visible_orbits_groups()


func set_huds_visibility_state() -> void:
	if !has_huds_visibility_state:
		return
	_body_huds_state.set_name_visible_flags(name_visible_flags)
	_body_huds_state.set_symbol_visible_flags(symbol_visible_flags)
	_body_huds_state.set_orbit_visible_flags(orbit_visible_flags)
	_sbg_huds_state.set_visible_points_groups(visible_points_groups)
	_sbg_huds_state.set_visible_orbits_groups(visible_orbits_groups)


# HUDs color state

func save_huds_color_state() -> void:
	has_huds_color_state = true
	body_orbit_colors = _body_huds_state.get_orbit_colors_dict() # ref safe


func set_huds_color_state() -> void:
	if !has_huds_color_state:
		return
	_body_huds_state.set_orbit_colors_dict(body_orbit_colors) # ref safe


# time state

func save_time_state() -> void:
	has_time_state = true
	is_real_world_time = _timekeeper.is_real_world_time
	if !is_real_world_time:
		time = _timekeeper.time
		speed_index = _timekeeper.speed_index
		is_reversed = _timekeeper.is_reversed


func set_time_state() -> void:
	if !has_time_state:
		return
	if is_real_world_time:
		_timekeeper.set_real_world()
	else:
		_timekeeper.set_time(time)
		_timekeeper.change_speed(0, speed_index)
		_timekeeper.set_time_reversed(is_reversed)


