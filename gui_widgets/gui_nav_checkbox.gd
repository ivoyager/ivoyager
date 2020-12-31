# gui_nav_checkbox.gd
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
# GUI widget. When selected, arrows change GUI selection (action "ui_left",
# etc.). When unselected, arrows move the camera ("camera_left", etc.).
# This code controls only widget buttons and Global signal emission. Actual
# changes are done elsewhere (search "gui_nav_checkbox_toggled").

extends CheckBox
class_name GUINavCheckbox
const SCENE := "res://ivoyager/gui_widgets/gui_nav_checkbox.tscn"

var _suppress_global_signal := false

func _ready():
	connect("toggled", self, "_on_toggled")
	Global.connect("gui_nav_checkbox_toggled", self, "_on_global_toggled")

func _on_toggled(is_pressed: bool) -> void:
	if !_suppress_global_signal:
		Global.emit_signal("gui_nav_checkbox_toggled", is_pressed)
	_suppress_global_signal = false

func _on_global_toggled(is_pressed: bool) -> void:
	if pressed != is_pressed: # wasn't this instance
		_suppress_global_signal = true
		pressed = is_pressed
