# small_bodies_finisher.gd
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
class_name IVSmallBodiesFinisher
extends Reference

# Adds HUDPoints and HUDOrbits for all SmallBodiesGroups at system tree built.

var _HUDPoints_: Script
var _HUDOrbits_: Script
var _settings: Dictionary = IVGlobal.settings


func _project_init() -> void:
	IVGlobal.connect("system_tree_built_or_loaded", self, "_init_unpersisted")
	_HUDPoints_ = IVGlobal.script_classes._HUDPoints_
	_HUDOrbits_ = IVGlobal.script_classes._HUDOrbits_


func _init_unpersisted(_is_new_game: bool) -> void:
	var small_bodies_group_indexing: IVSmallBodiesGroupIndexing \
			= IVGlobal.program.SmallBodiesGroupIndexing
	for group in small_bodies_group_indexing.groups:
		_init_hud_points(group)
		_init_hud_orbits(group)


func _init_hud_points(group: IVSmallBodiesGroup) -> void:
	var hud_points: IVHUDPoints = _HUDPoints_.new(group, "asteroid_point_color")
	var primary_body := group.primary_body
	primary_body.add_child(hud_points)


func _init_hud_orbits(group: IVSmallBodiesGroup) -> void:
	var hud_orbits: IVHUDOrbits = _HUDOrbits_.new(group, "asteroid_orbit_color")
	var primary_body := group.primary_body
	primary_body.add_child(hud_orbits)


