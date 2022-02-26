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


const DPRINT := false

signal show_points_changed(group_or_category, is_show)

const PERSIST_MODE := IVEnums.PERSIST_PROPERTIES_ONLY
const PERSIST_PROPERTIES := ["groups_visible", "categories_visible"]

# persisted
var groups_visible := {}
var categories_visible := {}

# unpersisted
var _points_groups := {} # holds IVHUDPoints instances
var _points_categories := {} # holds arrays of group names


func _ready():
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_restore_init_state")
	IVGlobal.connect("update_gui_requested", self, "_refresh_gui")


func _restore_init_state() -> void:
	groups_visible.clear()
	categories_visible.clear()
	_points_groups.clear()
	_points_categories.clear()


func show_points(group_or_category: String, is_show: bool) -> void:
	# does not error if missing for skip_asteroids = true
	assert(DPRINT and prints("show_points", group_or_category, is_show) or true)
	if _points_categories.has(group_or_category): # category
		if categories_visible[group_or_category] == is_show:
			return
		categories_visible[group_or_category] = is_show
		for group in _points_categories[group_or_category]:
			var hud_points: IVHUDPoints = _points_groups[group]
			hud_points.visible = is_show
			groups_visible[group] = is_show
			emit_signal("show_points_changed", group, is_show)
	elif _points_groups.has(group_or_category): # group
		if groups_visible[group_or_category] == is_show:
			return
		var hud_points: IVHUDPoints = _points_groups[group_or_category]
		hud_points.visible = is_show
		groups_visible[group_or_category] = is_show
		emit_signal("show_points_changed", group_or_category, is_show)


func register_points_group(hud_points: IVHUDPoints, group: String) -> void:
	if !groups_visible.has(group):
		groups_visible[group] = false
	elif groups_visible[group]: # was shown in loaded save
		hud_points.show()
	_points_groups[group] = hud_points


func forget_points_group(group: String) -> void: # not needed for load
	groups_visible.erase(group)
	_points_groups.erase(group)


func register_points_group_in_category(group: String, category: String) -> void:
	if !categories_visible.has(category):
		categories_visible[category] = false
	if !_points_categories.has(category):
		_points_categories[category] = []
	_points_categories[category].append(group)


func forget_points_category(category: String) -> void: # not needed for load
	categories_visible.erase(category)
	_points_categories.erase(category)


func _refresh_gui() -> void:
	for group in groups_visible:
		emit_signal("show_points_changed", group, groups_visible[group])
	for category in categories_visible:
		emit_signal("show_points_changed", category, categories_visible[category])
