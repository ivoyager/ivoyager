# date_time_label.gd
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
extends Label

# GUI widget.

var show_pause := true
var date_format := "%02d/%02d/%02d"
var clock_hms_format := "  %02d:%02d:%02d" # to incl UT, "  %02d:%02d:%02d UT"
var clock_hm_format := "  %02d:%02d" # to incl UT, "  %02d:%02d UT"
var forward_color: Color = IVGlobal.colors.normal
var reverse_color: Color = IVGlobal.colors.danger


var _date: Array = IVGlobal.date
var _clock: Array = IVGlobal.clock
#var _is_paused := false
var _show_clock := false
var _show_seconds := false
var _is_reversed := false
var _hm := [0, 0]

onready var _timekeeper: IVTimekeeper = IVGlobal.program.Timekeeper


func _ready() -> void:
	IVGlobal.connect("update_gui_requested", self, "_update_all")
	_timekeeper.connect("speed_changed", self, "_update_all")
	_timekeeper.connect("processed", self, "_update_label")
	set("custom_colors/font_color", forward_color)


func _update_all() -> void:
	_show_clock = _timekeeper.show_clock
	_show_seconds = _timekeeper.show_seconds
	if _is_reversed != _timekeeper.is_reversed:
		_is_reversed = !_is_reversed
		set("custom_colors/font_color", reverse_color if _is_reversed else forward_color)
	_update_label(0.0, 0.0)


func _update_label(_time: float, _e_delta: float) -> void:
	var new_text := date_format % _date
	if _show_clock:
		if _show_seconds:
			new_text += clock_hms_format % _clock
		else:
			_hm[0] = _clock[0]
			_hm[1] = _clock[1]
			new_text += clock_hm_format % _hm
#	if _is_paused and show_pause:
#		new_text += " " + tr("LABEL_PAUSED")
	text = new_text
