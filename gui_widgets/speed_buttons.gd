# speed_buttons.gd
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
class_name IVSpeedButtons
extends HBoxContainer

# UI widget.

const IS_CLIENT := IVEnums.NetworkState.IS_CLIENT

var _state: Dictionary = IVGlobal.state

onready var _tree := get_tree()
onready var _timekeeper: IVTimekeeper = IVGlobal.program.Timekeeper
onready var _minus: Button = $Minus
onready var _plus: Button = $Plus
onready var _pause: Button = $Pause
onready var _reverse: Button = $Reverse


func _ready() -> void:
	IVGlobal.connect("update_gui_requested", self, "_update_buttons")
	IVGlobal.connect("paused_changed", self, "_update_buttons")
	_timekeeper.connect("speed_changed", self, "_update_buttons")
	_minus.connect("pressed", self, "_increment_speed", [-1])
	_plus.connect("pressed", self, "_increment_speed", [1])
	if !IVGlobal.disable_pause:
		_pause.connect("pressed", self, "_change_paused")
	else:
		_pause.queue_free()
		_pause = null
	if IVGlobal.allow_time_reversal:
		_reverse.connect("pressed", self, "_change_reversed")
	else:
		_reverse.queue_free()
		_reverse = null
	_update_buttons()


func remove_pause_button() -> void:
	# not nessessary to call if IVGlobal.disable_pause
	if _pause:
		_pause.queue_free()
		_pause = null


func remove_reverse_button() -> void:
	# not nessessary to call if !IVGlobal.allow_time_reversal
	if _reverse:
		_reverse.queue_free()
		_reverse = null


func _update_buttons(_dummy := false) -> void:
	if _state.network_state == IS_CLIENT:
		if _pause:
			_pause.disabled = true
		if _reverse:
			_reverse.disabled = true
		_plus.disabled = true
		_minus.disabled = true
		return
	if _pause:
		_pause.disabled = false
		_pause.pressed = _tree.paused
	if _reverse:
		_reverse.disabled = false
		_reverse.pressed = _timekeeper.is_reversed
	_plus.disabled = !_timekeeper.can_incr_speed()
	_minus.disabled = !_timekeeper.can_decr_speed()


func _increment_speed(increment: int) -> void:
	_timekeeper.change_speed(increment)


func _change_paused() -> void:
	IVGlobal.emit_signal("change_pause_requested", false, _pause.pressed)


func _change_reversed() -> void:
	_timekeeper.set_time_reversed(_reverse.pressed)
