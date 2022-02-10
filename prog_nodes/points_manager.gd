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
const PERSIST_PROPERTIES := ["_show_points"]

# persisted
var _show_points := {}

# unpersisted
var _points_groups := {}
var _points_categories := {} # holds arrays of group names


func _ready():
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_restore_init_state")
	IVGlobal.connect("update_gui_requested", self, "_refresh_gui")


func _restore_init_state() -> void:
	_show_points.clear()
	_points_groups.clear()
	_points_categories.clear()


func show_points(group_or_category: String, is_show: bool) -> void:
	assert(DPRINT and prints("show_points", group_or_category, is_show) or true)
	if !_show_points.has(group_or_category):
		return # without error for skip_asteroids = true
	_show_points[group_or_category] = is_show
	if _points_categories.has(group_or_category): # category
		for group in _points_categories[group_or_category]:
			assert(_show_points.has(group))
			_show_points[group] = is_show
			if is_show:
				_points_groups[group].show()
			else:
				_points_groups[group].hide()
			emit_signal("show_points_changed", group, is_show)
	else: # group
		if is_show:
			_points_groups[group_or_category].show()
		else:
			_points_groups[group_or_category].hide()
	emit_signal("show_points_changed", group_or_category, is_show)


func register_points_group(hud_points: IVHUDPoints, group: String) -> void:
	if !_show_points.has(group):
		_show_points[group] = false
	elif _show_points[group]: # was shown in loaded save
		hud_points.show()
	_points_groups[group] = hud_points


func forget_points_group(group: String) -> void: # not needed for load
	_show_points.erase(group)
	_points_groups.erase(group)


func register_points_group_in_category(group: String, category: String) -> void:
	if !_show_points.has(category):
		_show_points[category] = false
	if !_points_categories.has(category):
		_points_categories[category] = []
	_points_categories[category].append(group)


func forget_points_category(category: String) -> void: # not needed for load
	_show_points.erase(category)
	_points_categories.erase(category)


func _refresh_gui() -> void:
	for group_or_category in _show_points:
		emit_signal("show_points_changed", group_or_category, _show_points[group_or_category])
