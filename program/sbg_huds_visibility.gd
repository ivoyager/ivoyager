# sbg_huds_visibility.gd
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
class_name IVSBGHUDsVisibility
extends Node

# Maintains visibility state for SmallBodiesGroup HUDs. HUD Nodes (or thier
# visibility managers) must connect and set visibility on changed signals.

signal points_visibility_changed()
signal orbits_visibility_changed()


const PERSIST_MODE := IVEnums.PERSIST_PROPERTIES_ONLY
const PERSIST_PROPERTIES := [
	"points_visibility",
	"orbits_visibility",
]

# persisted - read-only except at project init
var points_visibility := {} # indexed by group_name; false is same as missing
var orbits_visibility := {} # indexed by group_name



func _ready() -> void:
	IVGlobal.connect("update_gui_requested", self, "_on_update_gui_requested")


# public

func hide_all() -> void:
	for key in points_visibility:
		points_visibility[key] = false
	for key in orbits_visibility:
		orbits_visibility[key] = false
	emit_signal("points_visibility_changed")
	emit_signal("orbits_visibility_changed")
	

func is_points_visible(group: String) -> bool:
	return points_visibility.get(group, false)


func change_points_visibility(group: String, is_show: bool) -> void:
	points_visibility[group] = is_show
	emit_signal("points_visibility_changed")


func is_orbits_visible(group: String) -> bool:
	return orbits_visibility.get(group, false)


func change_orbits_visibility(group: String, is_show: bool) -> void:
	orbits_visibility[group] = is_show
	emit_signal("orbits_visibility_changed")


func get_visible_points_groups() -> Array:
	var array := []
	for key in points_visibility:
		if points_visibility[key]:
			array.append(key)
	return array


func get_visible_orbits_groups() -> Array:
	var array := []
	for key in orbits_visibility:
		if orbits_visibility[key]:
			array.append(key)
	return array


func set_visible_points_groups(array: Array) -> void:
	points_visibility.clear()
	for key in array:
		points_visibility[key] = true
	emit_signal("points_visibility_changed")


func set_visible_orbits_groups(array: Array) -> void:
	orbits_visibility.clear()
	for key in array:
		orbits_visibility[key] = true
	emit_signal("orbits_visibility_changed")
	

# private

func _on_update_gui_requested() -> void:
	emit_signal("points_visibility_changed")
	emit_signal("orbits_visibility_changed")

