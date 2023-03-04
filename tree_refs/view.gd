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

# Optionally keeps state related to camera, HUDs, and/or time. The object can
# be persisted via gamesave or cache.

# TODO: Hotkey bindings!

enum { # flags
	CAMERA_SELECTION = 1,
	CAMERA_LONGITUDE = 1 << 1,
	CAMERA_ORIENTATION = 1 << 2,

	HUDS_VISIBILITY = 1 << 3,
	HUDS_COLOR = 1 << 4,
	
	TIME_STATE = 1 << 5,
	
	# flag sets
	ALL_CAMERA = (1 << 3) - 1,
	ALL_HUDS = 1 << 3 | 1 << 4
	ALL_BUT_TIME = (1 << 5) - 1,
	ALL = (1 << 6) - 1,
}


const NULL_VECTOR3 := Vector3(-INF, -INF, -INF)

const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL
const PERSIST_PROPERTIES := [
	"flags",
	
	"selection_name",
	"camera_flags",
	"view_position",
	"view_rotations",
	
	"name_visible_flags",
	"symbol_visible_flags",
	"orbit_visible_flags",
	"visible_points_groups",
	"visible_orbits_groups",
	"body_orbit_colors",
	"sbg_points_colors",
	"sbg_orbits_colors",
	
	"time",
	"speed_index",
	"is_reversed",
]

# persisted
var flags := 0 # what state does this View have?

var selection_name := ""
var camera_flags := 0 # IVEnums.CameraFlags
var view_position := NULL_VECTOR3
var view_rotations := NULL_VECTOR3

var name_visible_flags := 0 # exclusive w/ symbol_visible_flags
var symbol_visible_flags := 0 # exclusive w/ name_visible_flags
var orbit_visible_flags := 0
var visible_points_groups := []
var visible_orbits_groups := []
var body_orbit_colors := {} # has non-default only
var sbg_points_colors := {} # has non-default only
var sbg_orbits_colors := {} # has non-default only

var time := 0.0
var speed_index := 0
var is_reversed := false


# private
var _camera_handler: IVCameraHandler = IVGlobal.program.CameraHandler
var _body_huds_state: IVBodyHUDsState = IVGlobal.program.BodyHUDsState
var _sbg_huds_state: IVSBGHUDsState = IVGlobal.program.SBGHUDsState
var _timekeeper: IVTimekeeper = IVGlobal.program.Timekeeper

# cache is 'bad' if _version_hash doesn't match
var _version_hash := PERSIST_PROPERTIES.hash() + 1


# public API

func save_state(save_flags: int) -> void:
	flags = save_flags
	_save_camera_state()
	_save_huds_state()
	_save_time_state()


func set_state(is_camera_instant_move := false) -> void:
	# Sets all state that this view has.
	_set_camera_state(is_camera_instant_move)
	_set_huds_state()
	_set_time_state()


# IVViewManager functions

func reset() -> void:
	# back to init state
	flags = 0
	selection_name = ""
	camera_flags = 0
	view_position = NULL_VECTOR3
	view_rotations = NULL_VECTOR3
	name_visible_flags = 0
	symbol_visible_flags = 0
	orbit_visible_flags = 0
	visible_points_groups.clear()
	visible_orbits_groups.clear()
	body_orbit_colors.clear()
	sbg_points_colors.clear()
	sbg_orbits_colors.clear()
	time = 0.0
	speed_index = 0
	is_reversed = false


func get_data_for_cache() -> Array:
	var data := []
	for property in PERSIST_PROPERTIES:
		data.append(get(property))
	data.append(_version_hash)
	return data


func set_data_from_cache(data) -> bool:
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


# private

func _save_camera_state() -> void:
	if !(flags & ALL_CAMERA):
		return
	var view_state := _camera_handler.get_camera_view_state()
	if flags & CAMERA_SELECTION:
		selection_name = view_state[0]
	if flags & CAMERA_LONGITUDE:
		view_position.x = view_state[2].x
	if flags & CAMERA_ORIENTATION:
		camera_flags = view_state[1]
		view_position.y = view_state[2].y
		view_position.z = view_state[2].z
		view_rotations = view_state[3]


func _set_camera_state(is_instant_move := false) -> void:
	if !(flags & ALL_CAMERA):
		return
	# Note: the camera ignores all null or null-equivilant args.
	_camera_handler.move_to_by_name(selection_name, camera_flags, view_position, view_rotations,
			is_instant_move)


func _save_huds_state() -> void:
	if flags & HUDS_VISIBILITY:
		name_visible_flags = _body_huds_state.name_visible_flags
		symbol_visible_flags = _body_huds_state.symbol_visible_flags
		orbit_visible_flags = _body_huds_state.orbit_visible_flags
		visible_points_groups = _sbg_huds_state.get_visible_points_groups()
		visible_orbits_groups = _sbg_huds_state.get_visible_orbits_groups()
	if flags & HUDS_COLOR:
		body_orbit_colors = _body_huds_state.get_non_default_orbit_colors()
		sbg_points_colors = _sbg_huds_state.get_non_default_points_colors()
		sbg_orbits_colors = _sbg_huds_state.get_non_default_orbits_colors()


func _set_huds_state() -> void:
	if flags & HUDS_VISIBILITY:
		_body_huds_state.set_name_visible_flags(name_visible_flags)
		_body_huds_state.set_symbol_visible_flags(symbol_visible_flags)
		_body_huds_state.set_orbit_visible_flags(orbit_visible_flags)
		_sbg_huds_state.set_visible_points_groups(visible_points_groups)
		_sbg_huds_state.set_visible_orbits_groups(visible_orbits_groups)
	if flags & HUDS_COLOR:
		_body_huds_state.set_all_orbit_colors(body_orbit_colors) # ref safe
		_sbg_huds_state.set_all_points_colors(sbg_points_colors)
		_sbg_huds_state.set_all_orbits_colors(sbg_orbits_colors)


# time state

func _save_time_state() -> void:
	if flags & TIME_STATE:
		time = _timekeeper.time
		speed_index = _timekeeper.speed_index
		is_reversed = _timekeeper.is_reversed


func _set_time_state() -> void:
	if flags & TIME_STATE:
		# Note: IVTimekeeper ignores set_time() and set_time_reversed() if
		# disallowed in IVGlobal project settings. So in most game applications
		# only speed is set.
		_timekeeper.set_time(time)
		_timekeeper.change_speed(0, speed_index)
		_timekeeper.set_time_reversed(is_reversed)


