# view.gd
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
class_name IVView

# Specifies (optionally) target identity, where and how camera tracks its
# target object, and HUDs visible states. Passing a null-equivalent value 
# (=init values) tells the camera to maintain its current value.
#
# This object is designed to work with ivoyager save/load system (so a game can
# save views) or for easy cache persistence via Godot's inst2dict() and
# dict2inst() (which we use in the Planetarium).

const NULL_ROTATION := Vector3(-INF, -INF, -INF)

const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL
const PERSIST_PROPERTIES := [
	"selection_name",
	"track_type",
	"view_type",
	"view_position",
	"view_rotations",
	"has_hud_states",
	"orbit_visible_flags",
	"name_visible_flags",
	"symbol_visible_flags",
	"point_groups_visible",
	"point_categories_visible",
]

# persisted
var selection_name := ""
var track_type := -1 # IVEnums.CameraTrackType
var view_type := -1 # IVEnums.ViewType (may or may not specify var values below)
var view_position := Vector3.ZERO # spherical; relative to orbit or ground ref
var view_rotations := NULL_ROTATION # euler; relative to looking_at(-origin, north)
var has_hud_states := false
var orbit_visible_flags := 0
var name_visible_flags := 0 # exclusive w/ symbol_visible_flags
var symbol_visible_flags := 0 # exclusive w/ name_visible_flags
var point_groups_visible := {}
var point_categories_visible := {}


func set_huds_visible() -> void:
	if !has_hud_states:
		return
	var program: Dictionary = IVGlobal.program
	var huds_manager: IVHUDsManager = program.HUDsManager
	var points_manager: IVPointsManager = program.PointsManager
	huds_manager.set_orbit_visible_flags(orbit_visible_flags)
	huds_manager.set_name_visible_flags(name_visible_flags)
	huds_manager.set_symbol_visible_flags(symbol_visible_flags)
	for points_category in point_categories_visible:
		points_manager.show_points(points_category, point_categories_visible[points_category])
	for points_group in point_groups_visible:
		points_manager.show_points(points_group, point_groups_visible[points_group])


func store_huds_visible() -> void:
	has_hud_states = true
	var program: Dictionary = IVGlobal.program
	var huds_manager: IVHUDsManager = program.HUDsManager
	var points_manager: IVPointsManager = program.PointsManager
	orbit_visible_flags = huds_manager.orbit_visible_flags
	name_visible_flags = huds_manager.name_visible_flags
	symbol_visible_flags = huds_manager.symbol_visible_flags
	point_groups_visible = points_manager.groups_visible.duplicate()
	point_categories_visible = points_manager.categories_visible.duplicate()

