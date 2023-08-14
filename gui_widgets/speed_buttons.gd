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

# UI widget. Requires IVTimekeeper and IVStateManager.

const IS_CLIENT := IVEnums.NetworkState.IS_CLIENT

var _state: Dictionary = IVGlobal.state

@onready var _timekeeper: IVTimekeeper = IVGlobal.program.Timekeeper
@onready var _state_manager: IVStateManager = IVGlobal.program.StateManager
@onready var _minus: Button = $Minus
@onready var _plus: Button = $Plus
@onready var _pause: Button = $Pause
@onready var _reverse: Button = $Reverse


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	IVGlobal.update_gui_requested.connect(_update_buttons)
	IVGlobal.user_pause_changed.connect(_update_buttons)
	_timekeeper.speed_changed.connect(_update_buttons)
	_minus.pressed.connect(_increment_speed.bind(-1))
	_plus.pressed.connect(_increment_speed.bind(1))
	if !IVGlobal.disable_pause:
		_pause.pressed.connect(_change_paused)
	else:
		_pause.queue_free()
		_pause = null
	if IVGlobal.allow_time_reversal:
		_reverse.pressed.connect(_change_reversed)
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
		_pause.button_pressed = _state_manager.is_user_paused
	if _reverse:
		_reverse.disabled = false
		_reverse.button_pressed = _timekeeper.is_reversed
	_plus.disabled = !_timekeeper.can_incr_speed()
	_minus.disabled = !_timekeeper.can_decr_speed()


func _increment_speed(increment: int) -> void:
	_timekeeper.change_speed(increment)


func _change_paused() -> void:
	IVGlobal.change_pause_requested.emit(false, _pause.button_pressed)


func _change_reversed() -> void:
	_timekeeper.set_time_reversed(_reverse.button_pressed)

