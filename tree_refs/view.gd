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

# Can optionally keep selection, camera state (position & rotations), HUDs
# visibilities, HUDs colors, and/or time state. The object can be persisted
# via gamesave or cache.

# WIP - move here!
enum { # view_flags
	CAMERA_STATE = 1,
	HUDS_VISIBILITY_STATE = 1 << 1,
	HUDS_COLOR_STATE = 1 << 2,
	TIME_STATE = 1 << 3,
	# flag sets
	ALL_NON_TIME_STATE = (1 << 3) - 1,
	ALL_VIEW_STATE = (1 << 4) - 1,
}


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
var body_orbit_colors := {} # has non-default only
var sbg_points_colors := {} # has non-default only
var sbg_orbits_colors := {} # has non-default only

var has_time_state := false # used by Planetarium
var time := 0.0
var speed_index := 0
var is_reversed := false


# private
var _camera_handler: IVCameraHandler = IVGlobal.program.CameraHandler
var _body_huds_state: IVBodyHUDsState = IVGlobal.program.BodyHUDsState
var _sbg_huds_state: IVSBGHUDsState = IVGlobal.program.SBGHUDsState
var _timekeeper: IVTimekeeper = IVGlobal.program.Timekeeper
var _version_hash := PERSIST_PROPERTIES.hash()



# all state

func set_state(is_camera_instant_move := false) -> void:
	set_camera_state(is_camera_instant_move)
	set_huds_visibility_state()
	set_huds_color_state()
	set_time_state()


# camera state

func save_camera_state() -> void:
	has_camera_state = true
	var view_state := _camera_handler.get_camera_view_state()
	selection_name = view_state[0]
	camera_flags = view_state[1]
	view_position = view_state[2]
	view_rotations = view_state[3]


func set_camera_state(is_instant_move := false) -> void:
	if !has_camera_state:
		return
	_camera_handler.move_to_by_name(selection_name, camera_flags, view_position, view_rotations,
			is_instant_move)


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
	body_orbit_colors = _body_huds_state.get_non_default_orbit_colors() # ref safe
	sbg_points_colors = _sbg_huds_state.get_non_default_points_colors()
	sbg_orbits_colors = _sbg_huds_state.get_non_default_orbits_colors()


func set_huds_color_state() -> void:
	if !has_huds_color_state:
		return
	_body_huds_state.set_all_orbit_colors(body_orbit_colors) # ref safe
	_sbg_huds_state.set_all_points_colors(sbg_points_colors)
	_sbg_huds_state.set_all_orbits_colors(sbg_orbits_colors)


# time state

func save_time_state() -> void:
	has_time_state = true
	time = _timekeeper.time
	speed_index = _timekeeper.speed_index
	is_reversed = _timekeeper.is_reversed


func set_time_state() -> void:
	if !has_time_state:
		return
	_timekeeper.set_time(time)
	_timekeeper.change_speed(0, speed_index)
	_timekeeper.set_time_reversed(is_reversed)


# IVViewManager

func reset() -> void:
	has_camera_state = false
	has_huds_visibility_state = false
	has_huds_color_state = false
	has_time_state = false
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

