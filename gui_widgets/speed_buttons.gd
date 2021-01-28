# speed_buttons.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# "I, Voyager" is a registered trademark of Charlie Whitfield
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

onready var _tree: SceneTree = get_tree()
onready var _timekeeper: Timekeeper = Global.program.Timekeeper
onready var _minus: Button = $Minus
onready var _plus: Button = $Plus
onready var _pause: Button = $Pause
onready var _reverse: Button = $Reverse

func remove_pause_button() -> void:
	# not nessessary to call if Global.disable_pause
	if _pause:
		_pause.queue_free()
		_pause = null

func remove_reverse_button() -> void:
	# not nessessary to call if !Global.allow_time_reversal
	if _reverse:
		_reverse.queue_free()
		_reverse = null

func _ready() -> void:
	_timekeeper.connect("speed_changed", self, "_on_speed_changed")
	_minus.connect("pressed", self, "_increment_speed", [-1])
	_plus.connect("pressed", self, "_increment_speed", [1])
	if !Global.disable_pause:
		_pause.connect("pressed", self, "_change_paused")
	else:
		_pause.queue_free()
		_pause = null
	if Global.allow_time_reversal:
		_reverse.connect("pressed", self, "_change_reversed")
	else:
		_reverse.queue_free()
		_reverse = null

func _on_speed_changed(_speed_index: int, is_reversed: bool, is_paused: bool,
		_show_clock: bool, _show_seconds: bool, _is_real_world_time: bool) -> void:
	if _pause:
		_pause.pressed = is_paused
	if _reverse:
		_reverse.pressed = is_reversed
	_plus.disabled = !_timekeeper.can_incr_speed()
	_minus.disabled = !_timekeeper.can_decr_speed()

func _increment_speed(increment: int) -> void:
	_timekeeper.change_speed(increment)

func _change_paused() -> void:
	_tree.paused = _pause.pressed

func _change_reversed() -> void:
	_timekeeper.set_time_reversed(_reverse.pressed)
