# time_control.gd
# This file is part of I, Voyager
# https://ivoyager.dev
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
# UI widget.

extends HBoxContainer

var include_game_speed_label := true
var include_pause_button := true
var include_reverse_time_button := Global.allow_time_reversal
var include_real_time_button := Global.allow_real_world_time
var forward_color: Color = Global.colors.normal
var reverse_color: Color = Global.colors.danger

onready var _tree: SceneTree = get_tree()
onready var _timekeeper: Timekeeper = Global.program.Timekeeper
onready var _minus: Button = $Minus
onready var _plus: Button = $Plus
onready var _reverse: Button = $Reverse
onready var _pause: Button = $Pause
onready var _real: Button = $Real
onready var _game_speed: Label = $GameSpeed

func _ready() -> void:
	_timekeeper.connect("speed_changed", self, "_on_speed_changed")
	_minus.connect("pressed", self, "_increment_speed", [-1])
	_plus.connect("pressed", self, "_increment_speed", [1])
	if Global.state.is_system_built:
		_on_system_built(false)
	else:
		Global.connect("system_tree_built_or_loaded", self, "_on_system_built", [], CONNECT_ONESHOT)

func _on_system_built(_is_loaded_game: bool) -> void:
	if !include_game_speed_label:
		_game_speed.queue_free()
	if include_reverse_time_button:
		_timekeeper.connect("time_altered", self, "_on_time_altered")
		_reverse.connect("pressed", self, "_set_reverse")
	else:
		_reverse.queue_free()
	if include_pause_button:
		_pause.connect("pressed", self, "_change_paused")
	else:
		_pause.queue_free()
	if include_real_time_button:
		_real.connect("pressed", self, "_set_real_world")
	else:
		_real.queue_free()

func _on_speed_changed(_speed_index: int, is_reversed: bool, is_paused: bool,
		_show_clock: bool, _show_seconds: bool) -> void:
	if include_game_speed_label:
		_game_speed.text = _timekeeper.speed_name
		_game_speed.set("custom_colors/font_color", reverse_color if is_reversed else forward_color)
	if include_reverse_time_button:
		_reverse.pressed = is_reversed
	if include_pause_button:
		_pause.pressed = is_paused
	_plus.disabled = !_timekeeper.can_incr_speed()
	_minus.disabled = !_timekeeper.can_decr_speed()
	if include_real_time_button:
		_real.pressed = _timekeeper.is_real_world_time

func _on_time_altered() -> void:
	_real.pressed = _timekeeper.is_real_world_time

func _increment_speed(increment: int) -> void:
	_timekeeper.change_speed(increment)

func _set_reverse() -> void:
	_timekeeper.set_time_reversed(_reverse.pressed)

func _change_paused() -> void:
	_tree.paused = _pause.pressed
	
func _set_real_world() -> void:
	_timekeeper.set_real_world()
	_real.pressed = true

