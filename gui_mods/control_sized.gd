# control_sized.gd
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
class_name IVControlSized
extends Node

# Use only one of the Control mods:
#    ControlSized - resizes with Options/GUI Size
#    ControlDraggable - above plus user draggable
#    ControlDynamic - above plus user resizing margins
#
# Add to Control (eg, a PanelContainer or PopupPanel) for resizing based on
# Options/gui_size. Maintains position based on existing anchors.
# Assumes anchor_left == anchor_right and anchor_top == anchor_bottom (i.e.,
# the parent Control is fixed-size for a given gui_size and not expected to
# stretch with screen resize).
#
# Modify sizes values from _ready() in the parent Control.
#
# For draggable and user resizable windows, use ControlDynamic instead.

# project vars
var min_sizes: Array[Vector2] = [
	# Use init_min_size() to set.
	Vector2(435.0, 291.0), # GUI_SMALL
	Vector2(575.0, 354.0), # GUI_MEDIUM
	Vector2(712.0, 421.0), # GUI_LARGE
]
var max_default_screen_proportions := Vector2(0.45, 0.45) # can override above

# private
var _settings: Dictionary = IVGlobal.settings

@onready var _viewport := get_viewport()
@onready var _parent: Control = get_parent()


func _ready() -> void:
	IVGlobal.setting_changed.connect(_settings_listener)
	IVGlobal.simulator_started.connect(resize_and_position_to_anchor)
	_parent.resized.connect(resize_and_position_to_anchor)
	resize_and_position_to_anchor()


func init_min_size(gui_size: int, size: Vector2) -> void:
	# 'gui_size' is one of IVEnums.GUISize, or use -1 to set all.
	# Set x or y or both to zero for shrink to content.
	# Args [-1, Vector2.ZERO] sets all GUI sizes to shrink to content. 
	if gui_size != -1:
		min_sizes[gui_size] = size
	else:
		for i in min_sizes.size():
			min_sizes[i] = size


func resize_and_position_to_anchor() -> void:
	var default_size := _get_default_size()
	# Some content needs immediate resize (eg, PlanetMoonButtons so it can
	# conform to its parent container). Other content needs delayed resize.
	_parent.size = default_size
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_parent.size = default_size
	var viewport_size := _viewport.get_visible_rect().size
	_parent.position.x = _parent.anchor_left * (viewport_size.x - _parent.size.x)
	_parent.position.y = _parent.anchor_top * (viewport_size.y - _parent.size.y)


func _get_default_size() -> Vector2:
	var gui_size: int = _settings.gui_size
	var default_size: Vector2 = min_sizes[gui_size]
	var viewport_size := _viewport.get_visible_rect().size
	var max_x := roundf(viewport_size.x * max_default_screen_proportions.x)
	var max_y := roundf(viewport_size.y * max_default_screen_proportions.y)
	if default_size.x > max_x:
		default_size.x = max_x
	if default_size.y > max_y:
		default_size.y = max_y
	return default_size


func _settings_listener(setting: String, _value) -> void:
	if setting == "gui_size":
		resize_and_position_to_anchor()

