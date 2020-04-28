# date_time.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
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

var show_pause := true
var date_format := "%02d/%02d/%02d"
var clock_hms_format := "  %02d:%02d:%02d"
var clock_hm_format := "  %02d:%02d"

var _date: Array = Global.date
var _clock: Array = Global.clock
var _is_paused := false
var _show_clock := false
var _show_seconds := false
var _hm := [0, 0]
onready var _forward_color: Color = Global.colors.normal
onready var _reverse_color: Color = Global.colors.danger


func _ready() -> void:
	var timekeeper: Timekeeper = Global.program.Timekeeper
	timekeeper.connect("processed", self, "_update")
	timekeeper.connect("speed_changed", self, "_on_speed_changed")

func _update(_time: float, _e_delta: float) -> void:
	var new_text := date_format % _date
	if _show_clock:
		if _show_seconds:
			new_text += clock_hms_format % _clock
		else:
			_hm[0] = _clock[0]
			_hm[1] = _clock[1]
			new_text += clock_hm_format % _hm
	if _is_paused and show_pause:
		new_text += " " + tr("LABEL_PAUSED")
	text = new_text

func _on_speed_changed(_speed_index: int, is_reversed: bool, is_paused: bool,
		show_clock: bool, show_seconds: bool) -> void:
	print("_on_speed_changed")
	_is_paused = is_paused
	_show_clock = show_clock
	_show_seconds = show_seconds
	if is_reversed:
		set("custom_colors/font_color", _reverse_color)
	else:
		set("custom_colors/font_color", _forward_color)
	_update(0.0, 0.0)

