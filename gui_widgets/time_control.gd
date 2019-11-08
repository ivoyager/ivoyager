# time_control.gd
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
#
# UI widget.

extends HBoxContainer
class_name TimeControl
const SCENE := "res://ivoyager/gui_widgets/time_control.tscn"

onready var _tree: SceneTree = get_tree()
onready var _timekeeper: Timekeeper = Global.objects.Timekeeper
onready var _plus: Button = $Plus
onready var _minus: Button = $Minus
onready var _real: Button = $Real
onready var _pause: Button = $Pause
onready var _game_speed: Label = $GameSpeed

func _ready() -> void:
	_timekeeper.connect("speed_changed", self, "_update")
	_plus.connect("pressed", self, "_increment_speed", [1])
	_minus.connect("pressed", self, "_increment_speed", [-1])
	_real.connect("toggled", self, "_change_real_time")
	_pause.connect("toggled", self, "_change_paused")

func _update(speed_str: String) -> void:
	_game_speed.text = speed_str
	if speed_str.begins_with("-"):
		_game_speed.set("custom_colors/font_color", Color(1.0, 0.5, 0.5))
		_plus.set("custom_colors/font_color", Color(1.0, 0.5, 0.5))
		_minus.set("custom_colors/font_color", Color(1.0, 0.5, 0.5))
		_real.set("custom_colors/font_color", Color(1.0, 0.5, 0.5))
		_pause.set("custom_colors/font_color", Color(1.0, 0.5, 0.5))
	else:
		_game_speed.set("custom_colors/font_color", Color.white)
		_plus.set("custom_colors/font_color", Color.white)
		_minus.set("custom_colors/font_color", Color.white)
		_real.set("custom_colors/font_color", Color.white)
		_pause.set("custom_colors/font_color", Color.white)
	_pause.pressed = _tree.paused
	if _tree.paused:
		_real.pressed = false
		_plus.disabled = false
		_minus.disabled = false
	else:
		_plus.disabled = !_timekeeper.can_incr_speed()
		_minus.disabled = !_timekeeper.can_decr_speed()
		_real.pressed = _timekeeper.is_real_time()

func _increment_speed(increment: int) -> void:
	_timekeeper.increment_speed(increment)

func _change_real_time(button_pressed: bool) -> void:
	_timekeeper.set_real_time(button_pressed)
	
func _change_paused(button_pressed: bool) -> void:
	_tree.paused = button_pressed
	