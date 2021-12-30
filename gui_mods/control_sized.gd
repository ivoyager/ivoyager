# control_sized.gd
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
# Use only one of the Control mods:
#    ControlSized - resizes with Options/GUI Size
#    ControlDraggable - above plus user draggable
#    ControlDynamic - above plus user resizing margins
#
# This widget will resize a Control (eg, a PanelContainer or PopupPanel) with
# changes in Options/gui_size, maintaining position based on existing anchors.
# Assumes anchor_left == anchor_right and anchor_top == anchor_bottom (i.e.,
# the parent Control is fixed-size for a given gui_size and not expected to
# stretch with screen resize).
#
# Modify sizes values from _ready() in the parent Control.
#
# For draggable and user resizable windows, use ControlDynamic instead.

extends Node

# project vars
var default_sizes := [
	# Use rounded floats. Values applied at runtime may be reduced by
	# max_default_screen_proportions, below.
	Vector2(435.0, 291.0), # GUI_SMALL
	Vector2(575.0, 354.0), # GUI_MEDIUM
	Vector2(712.0, 421.0), # GUI_LARGE
]
var max_default_screen_proportions := Vector2(0.45, 0.45)

# private
var _settings: Dictionary = Global.settings
onready var _viewport := get_viewport()
onready var _parent: Control = get_parent()
var _default_size: Vector2

func _ready() -> void:
	Global.connect("update_gui_needed", self, "_resize")
	Global.connect("setting_changed", self, "_settings_listener")
	_viewport.connect("size_changed", self, "_resize")

func _resize() -> void:
	var default_size := _get_default_size()
	if _default_size == default_size:
		return
	_default_size = default_size
	# Some content needs immediate resize (eg, PlanetMoonButtons so it can
	# conform to its parent container). Other content needs delayed resize.
	_parent.rect_size = default_size
	yield(get_tree(), "idle_frame")
	_parent.rect_size = default_size 
	_parent.rect_position.x = _parent.anchor_left * (_viewport.size.x - _parent.rect_size.x)
	_parent.rect_position.y = _parent.anchor_top * (_viewport.size.y - _parent.rect_size.y)

func _get_default_size() -> Vector2:
	var gui_size: int = _settings.gui_size
	var default_size: Vector2 = default_sizes[gui_size]
	var max_x := round(_viewport.size.x * max_default_screen_proportions.x)
	var max_y := round(_viewport.size.y * max_default_screen_proportions.y)
	if default_size.x > max_x:
		default_size.x = max_x
	if default_size.y > max_y:
		default_size.y = max_y
	return default_size

func _settings_listener(setting: String, _value) -> void:
	if setting == "gui_size":
		_resize()
