# speed_label.gd
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
# UI widget.

extends Label

var forward_color: Color = Global.colors.normal
var reverse_color: Color = Global.colors.danger

onready var _timekeeper: Timekeeper = Global.program.Timekeeper

func _ready() -> void:
	_timekeeper.connect("speed_changed", self, "_on_speed_changed")

func _on_speed_changed(_speed_index: int, is_reversed: bool, _is_paused: bool,
		_show_clock: bool, _show_seconds: bool, _is_real_world_time: bool) -> void:
		text = _timekeeper.speed_name
		set("custom_colors/font_color", reverse_color if is_reversed else forward_color)
