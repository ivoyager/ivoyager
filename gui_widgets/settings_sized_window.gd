# settings_sized_window.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
# Copyright (c) 2017-2020 Charlie Whitfield
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
# For  

extends Node

var default_sizes := [
	Vector2(435.0, 291.0), # GUI_SMALL
	Vector2(575.0, 354.0), # GUI_MEDIUM
	Vector2(712.0, 421.0), # GUI_LARGE
]

onready var _parent: Container = get_parent()

#func _ready() -> void:
#	Global.connect("gui_refresh_requested", self, "_resize")
#	Global.connect("setting_changed", self, "_settings_listener")
#	# widget mods here
#	$VBox/BottomHBox/ViewButtons/Outward.hide()
#
#func _resize() -> void:
#	# assumes anchor_left == anchor_right and anchor_top == anchor_bottom
#	var gui_size: int = Global.settings.gui_size
#	var viewport := get_viewport()
#	rect_size = default_sizes[gui_size]
#	rect_position.x = anchor_left * (viewport.size.x - rect_size.x)
#	rect_position.y = anchor_top * (viewport.size.y - rect_size.y)
#
#func _settings_listener(setting: String, _value) -> void:
#	match setting:
#		"gui_size":
#			_resize()

