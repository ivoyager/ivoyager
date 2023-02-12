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

# Remembers camera state and/or HUDs visibility for persistence via game save
# or cache. For example cache usage, see:
# https://github.com/ivoyager/planetarium/blob/master/planetarium/view_cacher.gd


const NULL_ROTATION := Vector3(-INF, -INF, -INF)

const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL
const PERSIST_PROPERTIES := [
	"has_camera_state",
	"selection_name",
	"view_type",
	"view_position",
	"view_rotations",
	"track_type",
	"up_lock_type",
	"has_huds_state",
	"orbit_visible_flags",
	"name_visible_flags",
	"symbol_visible_flags",
	"sbg_points_visibility",
	"sbg_orbits_visibility",
]

# persisted
var has_camera_state := false
var selection_name := ""
var view_type := -1 # IVEnums.ViewType (may or may not specify var values below)
var view_position := Vector3.ZERO # spherical; relative to orbit or ground ref
var view_rotations := NULL_ROTATION # euler; relative to looking_at(-origin, north)
var track_type := -1 # IVEnums.TrackType
var up_lock_type := -1 # IVEnums.UpLockType
var has_huds_state := false
var orbit_visible_flags := 0
var name_visible_flags := 0 # exclusive w/ symbol_visible_flags
var symbol_visible_flags := 0 # exclusive w/ name_visible_flags
var sbg_points_visibility := {}
var sbg_orbits_visibility := {}


func remember_camera_state(camera: IVCamera) -> void:
	has_camera_state = true
	selection_name = camera.selection.name
	view_type = camera.view_type
	view_position = camera.view_position
	view_rotations = camera.view_rotations
	track_type = camera.track_type
	up_lock_type = camera.up_lock_type


func remember_huds_visibility() -> void:
	has_huds_state = true
	var huds_visibility: IVHUDsVisibility = IVGlobal.program.HUDsVisibility
	orbit_visible_flags = huds_visibility.orbit_visible_flags
	name_visible_flags = huds_visibility.name_visible_flags
	symbol_visible_flags = huds_visibility.symbol_visible_flags
	sbg_points_visibility = huds_visibility.sbg_points_visibility.duplicate()
	sbg_orbits_visibility = huds_visibility.sbg_orbits_visibility.duplicate()


func set_camera_state(camera: IVCamera, is_instant_move := true) -> void:
	if !has_camera_state:
		return
	var _SelectionManager_: Script = IVGlobal.script_classes._SelectionManager_
	var selection: IVSelection = _SelectionManager_.get_or_make_selection(selection_name)
	assert(selection)
	camera.move_to(selection, view_type, view_position, view_rotations, track_type, up_lock_type,
			is_instant_move)


func set_huds_visibility() -> void:
	if !has_huds_state:
		return
	var program: Dictionary = IVGlobal.program
	var huds_visibility: IVHUDsVisibility = program.HUDsVisibility
	huds_visibility.set_orbit_visible_flags(orbit_visible_flags)
	huds_visibility.set_name_visible_flags(name_visible_flags)
	huds_visibility.set_symbol_visible_flags(symbol_visible_flags)
	for group in sbg_points_visibility:
		huds_visibility.change_sbg_points_visibility(group, sbg_points_visibility[group])
	for group in sbg_orbits_visibility:
		huds_visibility.change_sbg_orbits_visibility(group, sbg_orbits_visibility[group])

