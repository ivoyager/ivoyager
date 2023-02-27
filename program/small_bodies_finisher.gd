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

# Adds HUDPoints and HUDOrbits for SmallBodiesGroup instances.

var _HUDPoints_: Script
var _HUDOrbits_: Script
var _settings: Dictionary = IVGlobal.settings


func _project_init() -> void:
	IVGlobal.get_tree().connect("node_added", self, "_on_node_added")
	_HUDPoints_ = IVGlobal.script_classes._HUDPoints_
	_HUDOrbits_ = IVGlobal.script_classes._HUDOrbits_


func _on_node_added(node: Node) -> void:
	var sbg := node as IVSmallBodiesGroup
	if sbg:
		_init_hud_points(sbg)
		_init_hud_orbits(sbg)


func _init_hud_points(sbg: IVSmallBodiesGroup) -> void:
	var hud_points: IVHUDPoints = _HUDPoints_.new(sbg)
	var primary_body := sbg.primary_body
	primary_body.add_child(hud_points)


func _init_hud_orbits(sbg: IVSmallBodiesGroup) -> void:
	var hud_orbits: IVHUDOrbits = _HUDOrbits_.new(sbg)
	var primary_body := sbg.primary_body
	primary_body.add_child(hud_orbits)


