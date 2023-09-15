# speed_label.gd
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
class_name IVSpeedLabel
extends Label

# UI widget. Requires IVTimekeeper.

var forward_color: Color = IVGlobal.colors.normal
var reverse_color: Color = IVGlobal.colors.danger

var _is_reversed := false

@onready var _timekeeper: IVTimekeeper = IVGlobal.program[&"Timekeeper"]


func _ready() -> void:
	IVGlobal.update_gui_requested.connect(_update_speed)
	_timekeeper.speed_changed.connect(_update_speed)
	set(&"theme_override_colors/font_color", forward_color)
	_update_speed()


func _update_speed() -> void:
		text = _timekeeper.speed_name
		if _is_reversed != _timekeeper.is_reversed:
			_is_reversed = !_is_reversed
			set(&"theme_override_colors/font_color", reverse_color if _is_reversed else forward_color)

