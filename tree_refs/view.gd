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

# Can optionally keep camera state, HUDs visibility and/or time. The object is
# structured for persistence via game save or cache.

const CACHE_VERSION := 101 # increment after any property change
const NULL_ROTATION := Vector3(-INF, -INF, -INF)

const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL
const PERSIST_PROPERTIES := [
	"has_camera_state",
	"selection_name",
	"camera_flags",
	"view_position",
	"view_rotations",
	"has_huds_state",
	"orbit_visible_flags",
	"name_visible_flags",
	"symbol_visible_flags",
	"visible_points_groups",
	"visible_orbits_groups",
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

var has_huds_state := false
var orbit_visible_flags := 0
var name_visible_flags := 0 # exclusive w/ symbol_visible_flags
var symbol_visible_flags := 0 # exclusive w/ name_visible_flags
var visible_points_groups := []
var visible_orbits_groups := []

var has_time_state := false # used by planetarium
var time := 0.0
var speed_index := 0
var is_reversed := false


func get_cache_data() -> Array:
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


# camera state

func remember_camera_state(camera: IVCamera) -> void:
	has_camera_state = true
	selection_name = camera.selection.name
	camera_flags = camera.flags
	view_position = camera.view_position
	view_rotations = camera.view_rotations


func set_camera_state(camera: IVCamera, is_instant_move := true) -> void:
	if !has_camera_state:
		return
	var _SelectionManager_: Script = IVGlobal.script_classes._SelectionManager_
	var selection: IVSelection = _SelectionManager_.get_or_make_selection(selection_name)
	assert(selection)
	camera.move_to(selection, camera_flags, view_position, view_rotations, is_instant_move)


# HUDs state

func remember_huds_visibility() -> void:
	has_huds_state = true
	var body_huds_visibility: IVBodyHUDsVisibility = IVGlobal.program.BodyHUDsVisibility
	orbit_visible_flags = body_huds_visibility.orbit_visible_flags
	name_visible_flags = body_huds_visibility.name_visible_flags
	symbol_visible_flags = body_huds_visibility.symbol_visible_flags
	var sbg_huds_visibility: IVSBGHUDsVisibility = IVGlobal.program.SBGHUDsVisibility
	visible_points_groups = sbg_huds_visibility.get_visible_points_groups()
	visible_orbits_groups = sbg_huds_visibility.get_visible_orbits_groups()


func set_huds_visibility() -> void:
	if !has_huds_state:
		return
	var body_huds_visibility: IVBodyHUDsVisibility = IVGlobal.program.BodyHUDsVisibility
	body_huds_visibility.set_orbit_visible_flags(orbit_visible_flags)
	body_huds_visibility.set_name_visible_flags(name_visible_flags)
	body_huds_visibility.set_symbol_visible_flags(symbol_visible_flags)
	var sbg_huds_visibility: IVSBGHUDsVisibility = IVGlobal.program.SBGHUDsVisibility
	sbg_huds_visibility.set_visible_points_groups(visible_points_groups)
	sbg_huds_visibility.set_visible_orbits_groups(visible_orbits_groups)


# time state

func remember_time_state() -> void:
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


