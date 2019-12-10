# gui_navigation.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2019 Charlie Whitfield
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

extends Control

const NAV_OFFSET := Vector2(-30.0, -10.0)
onready var _system_navigator: HBoxContainer = $SystemNavigator
onready var _viewport := get_viewport()
var _is_mouse_button_pressed := false

func _ready() -> void:
	_system_navigator.rect_min_size = Vector2(0.0, 185.0)
	_system_navigator.rect_position += NAV_OFFSET
	_system_navigator.size_proportions_exponent = 0.5
	_system_navigator.horizontal_expansion = 450.0
	_system_navigator.min_width = 10.0
	_system_navigator.hide()
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _is_mouse_button_pressed:
			return
		var mouse_pos := _viewport.get_mouse_position()
		var x_boundary := rect_position.x + rect_size.x + NAV_OFFSET.x
		var y_boundary := rect_position.y + NAV_OFFSET.y
		var show_navigator := mouse_pos.x < x_boundary and mouse_pos.y > y_boundary
		if show_navigator != _system_navigator.visible:
			_system_navigator.visible = show_navigator
			mouse_filter = MOUSE_FILTER_PASS if show_navigator else MOUSE_FILTER_IGNORE
	elif event is InputEventMouseButton:
		_is_mouse_button_pressed = event.pressed
