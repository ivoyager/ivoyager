# points_manager.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2019 Charlie Whitfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# *****************************************************************************
#

extends Node
class_name PointsManager

const DPRINT := false

signal show_points_changed(group_or_category, is_show)

# persisted
var _show_points := {}
const PERSIST_AS_PROCEDURAL_OBJECT := false
const PERSIST_PROPERTIES := ["_show_points"]

# unpersisted
var _points_groups := {}
var _points_categories := {} # holds arrays of group names

func show_points(group_or_category: String, is_show: bool) -> void:
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

func register_points_group(hud_points: HUDPoints, group: String) -> void:
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


func project_init():
	Global.connect("gui_refresh_requested", self, "_refresh_gui")
	Global.connect("about_to_free_procedural_nodes", self, "_clear_procedural")

func _refresh_gui() -> void:
	for group_or_category in _show_points:
		emit_signal("show_points_changed", group_or_category, _show_points[group_or_category])

func _clear_procedural() -> void:
	_points_groups.clear()
	_points_categories.clear()
