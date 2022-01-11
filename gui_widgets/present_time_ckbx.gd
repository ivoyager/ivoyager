# present_time_ckbx.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2022 Charlie Whitfield
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
# UI widget. Used in Planetarium to select real-world present time.

extends CheckBox

const IS_CLIENT := IVEnums.NetworkState.IS_CLIENT

var _state: Dictionary = IVGlobal.state
onready var _timekeeper: Timekeeper = IVGlobal.program.Timekeeper

func _ready() -> void:
	_timekeeper.connect("speed_changed", self, "_on_speed_changed")
	_timekeeper.connect("time_altered", self, "_on_time_altered")
	connect("pressed", self, "_set_real_world")

func _on_speed_changed(_speed_index: int, _is_reversed: bool, _is_paused: bool,
		_show_clock: bool, _show_seconds: bool, _is_real_world_time: bool) -> void:
	pressed = _timekeeper.is_real_world_time

func _on_time_altered(_previous_time: float) -> void:
	pressed = _timekeeper.is_real_world_time
	
func _set_real_world() -> void:
	if _state.network_state != IS_CLIENT:
		_timekeeper.set_real_world()
		pressed = true
