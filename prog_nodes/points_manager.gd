# points_manager.gd
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
class_name IVPointsManager
extends Node


signal visibility_changed()

const PERSIST_MODE := IVEnums.PERSIST_PROPERTIES_ONLY
const PERSIST_PROPERTIES := ["groups_visible"]

# persisted
var groups_visible := {}

# unpersisted
var _points_groups := {} # holds IVHUDPoints instances (which are not persisted)


func _ready():
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_clear")
	IVGlobal.connect("update_gui_requested", self, "emit_signal", ["visibility_changed"])


func _clear() -> void:
	groups_visible.clear()
	_points_groups.clear()


func is_visible(group: String) -> bool:
	return groups_visible.get(group, false)


func show_points(group: String, is_show: bool) -> void:
	# does not error if missing for skip_asteroids = true
	if !_points_groups.has(group):
		return
	if groups_visible[group] == is_show:
		return
	var hud_points: IVHUDPoints = _points_groups[group]
	hud_points.visible = is_show
	groups_visible[group] = is_show
	emit_signal("visibility_changed")


func register_points_group(hud_points: IVHUDPoints, group: String) -> void: # new or loaded game
	if !groups_visible.has(group):
		groups_visible[group] = false
	elif groups_visible[group]: # was shown in loaded save
		hud_points.show()
	_points_groups[group] = hud_points


