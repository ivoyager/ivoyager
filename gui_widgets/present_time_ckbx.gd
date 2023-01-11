# present_time_ckbx.gd
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
extends CheckBox

# UI widget. Used in Planetarium to select real-world present time.

const IS_CLIENT := IVEnums.NetworkState.IS_CLIENT

var _state: Dictionary = IVGlobal.state

onready var _timekeeper: IVTimekeeper = IVGlobal.program.Timekeeper


func _ready() -> void:
	IVGlobal.connect("update_gui_requested", self, "_update_ckbx")
	_timekeeper.connect("speed_changed", self, "_update_ckbx")
	_timekeeper.connect("time_altered", self, "_on_time_altered")
	connect("pressed", self, "_set_real_world")


func _update_ckbx() -> void:
	pressed = _timekeeper.is_real_world_time


func _on_time_altered(_previous_time: float) -> void:
	pressed = _timekeeper.is_real_world_time


func _set_real_world() -> void:
	if _state.network_state != IS_CLIENT:
		_timekeeper.set_real_world()
		pressed = true
