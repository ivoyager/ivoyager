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
	"sbg_points_colors",
	"sbg_orbits_colors",
	
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
var sbg_points_colors := {}
var sbg_orbits_colors := {}

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
	sbg_points_colors.clear()
	sbg_orbits_colors.clear()


func get_cache_data() -> Array:
	var data := []
	for property in PERSIST_PROPERTIES:
		data.append(get(property))
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
	if data.size() != PERSIST_PROPERTIES.size() + 1:
		return false
	for i in PERSIST_PROPERTIES.size():
		set(PERSIST_PROPERTIES[i], data[i])
	return true


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
	sbg_points_colors = _sbg_huds_state.get_points_colors_dict()
	sbg_orbits_colors = _sbg_huds_state.get_orbits_colors_dict()


func set_huds_color_state() -> void:
	if !has_huds_color_state:
		return
	_body_huds_state.set_orbit_colors_dict(body_orbit_colors) # ref safe
	_sbg_huds_state.set_points_colors_dict(sbg_points_colors)
	_sbg_huds_state.set_orbits_colors_dict(sbg_orbits_colors)


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


