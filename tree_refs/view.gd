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


const CACHE_VERSION := 104 # increment after any property change
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

var has_time_state := false # used by planetarium
var time := 0.0
var speed_index := 0
var is_reversed := false



func reset() -> void:
	has_camera_state = false
	has_huds_visibility_state = false
	has_time_state = false
	# below not needed except to reduce storage size
	selection_name = ""
	visible_points_groups.clear()
	visible_orbits_groups.clear()


func get_cache_data() -> Array:
	# TODO: Don't need values if has_.._state == false
	var data := []
	for property in PERSIST_PROPERTIES:
		data.append(get(property))
	data.append(CACHE_VERSION)
	return data


func set_cache_data(data) -> bool:
	# Tests data integrity and returns false on failure.
	if typeof(data) != TYPE_ARRAY:
		return false
	if data.size() != PERSIST_PROPERTIES.size() + 1:
		return false
	var version = data[-1] # keep untyped for safety
	if typeof(version) != TYPE_INT:
		return false
	if version != CACHE_VERSION:
		return false
	for i in PERSIST_PROPERTIES.size():
		set(PERSIST_PROPERTIES[i], data[i])
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
	var camera: IVCamera = IVGlobal.get_viewport().get_camera()
	selection_name = camera.selection.name
	camera_flags = camera.flags
	view_position = camera.view_position
	view_rotations = camera.view_rotations


func set_camera_state(is_instant_move := false) -> void:
	if !has_camera_state:
		return
	var camera: IVCamera = IVGlobal.get_viewport().get_camera()
	var _SelectionManager_: Script = IVGlobal.script_classes._SelectionManager_
	var selection: IVSelection = _SelectionManager_.get_or_make_selection(selection_name)
	assert(selection)
	camera.move_to(selection, camera_flags, view_position, view_rotations, is_instant_move)


# HUDs visibility state

func save_huds_visibility_state() -> void:
	has_huds_visibility_state = true
	var body_huds_state: IVBodyHUDsState = IVGlobal.program.BodyHUDsState
	name_visible_flags = body_huds_state.name_visible_flags
	symbol_visible_flags = body_huds_state.symbol_visible_flags
	orbit_visible_flags = body_huds_state.orbit_visible_flags
	var sbg_huds_visibility: IVSBGHUDsVisibility = IVGlobal.program.SBGHUDsVisibility
	visible_points_groups = sbg_huds_visibility.get_visible_points_groups()
	visible_orbits_groups = sbg_huds_visibility.get_visible_orbits_groups()


func set_huds_visibility_state() -> void:
	if !has_huds_visibility_state:
		return
	var body_huds_state: IVBodyHUDsState = IVGlobal.program.BodyHUDsState
	body_huds_state.set_name_visible_flags(name_visible_flags)
	body_huds_state.set_symbol_visible_flags(symbol_visible_flags)
	body_huds_state.set_orbit_visible_flags(orbit_visible_flags)
	var sbg_huds_visibility: IVSBGHUDsVisibility = IVGlobal.program.SBGHUDsVisibility
	sbg_huds_visibility.set_visible_points_groups(visible_points_groups)
	sbg_huds_visibility.set_visible_orbits_groups(visible_orbits_groups)


# HUDs color state

func save_huds_color_state() -> void:
	has_huds_color_state = true
	var body_huds_state: IVBodyHUDsState = IVGlobal.program.BodyHUDsState
	body_orbit_colors = body_huds_state.get_orbit_colors_dict() # ref safe


func set_huds_color_state() -> void:
	if !has_huds_color_state:
		return
	var body_huds_state: IVBodyHUDsState = IVGlobal.program.BodyHUDsState
	body_huds_state.set_orbit_colors_dict(body_orbit_colors) # ref safe


# time state

func save_time_state() -> void:
	has_time_state = true
	var timekeeper: IVTimekeeper = IVGlobal.program.Timekeeper
	time = timekeeper.time
	speed_index = timekeeper.speed_index
	is_reversed = timekeeper.is_reversed


func set_time_state() -> void:
	if !has_time_state:
		return
	var timekeeper: IVTimekeeper = IVGlobal.program.Timekeeper
	timekeeper.set_time(time)
	timekeeper.change_speed(0, speed_index)
	timekeeper.set_time_reversed(is_reversed)


