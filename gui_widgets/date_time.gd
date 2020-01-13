# date_time.gd
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
# GUI widget.

extends Label

var forward_color: Color = Global.colors.normal
var reverse_color: Color = Global.colors.danger

func _ready() -> void:
	var timekeeper: Timekeeper = Global.objects.Timekeeper
	timekeeper.connect("display_date_time_changed", self, "set_text")
	timekeeper.connect("speed_changed", self, "_on_speed_changed")

func _on_speed_changed(speed_str: String) -> void:
	if speed_str.begins_with("-"):
		set("custom_colors/font_color", reverse_color)
	else:
		set("custom_colors/font_color", forward_color)

