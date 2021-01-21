# container_sized_by_settings.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
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
# This widget will resize a Container (e.g., a GUI PanelContainer) with changes
# in Settings.gui_size, maintaining position based on existing anchors.
# Assumes anchor_left == anchor_right and anchor_top == anchor_bottom (i.e.,
# the parent container is fixed-size for a given gui_size and not expected to
# stretch with screen resize).
#
# Modify sizes values from _ready() in the parent Container.
#
# For draggable and user resizable windows, use ContainerDynamic instead.

extends Node

# project vars
var sizes := [
	Vector2(435.0, 291.0), # GUI_SMALL
	Vector2(575.0, 354.0), # GUI_MEDIUM
	Vector2(712.0, 421.0), # GUI_LARGE
]

# private
var _settings: Dictionary = Global.settings
onready var _viewport := get_viewport()
onready var _parent: Container = get_parent()

func _ready() -> void:
	Global.connect("gui_refresh_requested", self, "_resize")
	Global.connect("setting_changed", self, "_settings_listener")

func _resize() -> void:
	var gui_size: int = _settings.gui_size
	_parent.rect_size = sizes[gui_size]
	_parent.rect_position.x = _parent.anchor_left * (_viewport.size.x - _parent.rect_size.x)
	_parent.rect_position.y = _parent.anchor_top * (_viewport.size.y - _parent.rect_size.y)

func _settings_listener(setting: String, _value) -> void:
	if setting == "gui_size":
		_resize()
