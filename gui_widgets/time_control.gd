# time_control.gd
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
	