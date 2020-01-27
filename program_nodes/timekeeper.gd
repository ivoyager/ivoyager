# timekeeper.gd
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
#
# Abstract base class. Subclass must provide actual timekeeping functionality
# and persistence; see GregorianTimekeeper for example.
# For orbital mechanics, member "time" must always represent days from J2000
# epoch (2000/01/01 12:00 Terrestrial Time). But implmentation of this class
# can provide arbitrary "year", "month", "hour" or whatever for UI display
# and associated calendar-based signals (for example, a Martian calendar and 
# clock).

extends Node
class_name Timekeeper

signal processed(time, sim_delta, engine_delta)
signal display_date_time_changed(date_time_str)
signal speed_changed(speed_str) # includes pause change

# project vars - subclass must init these!
var speeds: Array
var default_speed: int
var realtime_speed: int
var show_clock_speed: int
var show_seconds_speed: int

# public read-only - subclass must persist these!
var time: float # days from J2000 epoch
var speed_index := 0 # negative if time reversed
var speed_multiplier := 0.0 # negative if time reversed
var is_paused := false

# private - subclass must init and maintain this!
var _global_time_array: Array = Global.time_array

func set_time(_new_time: float, _is_init := false) -> void:
	pass

func change_speed(_new_speed: int) -> void:
	pass

func increment_speed(_increment: int) -> void:
	pass

func set_real_time(_is_real_time: bool) -> void:
	pass

func reset() -> void:
	pass

func get_current_date_string(_separator := "-") -> String:
	return ""

static func get_date_time_string(_time_: float, _date_separator_ := "-", _time_units := 6) -> String:
	return ""

func convert_date_time_string(_date_time_string: String, _min_time_units := 1) -> float:
	return 0.0

func _init() -> void:
	_on_init()

func _on_init() -> void:
	pass

func _ready() -> void:
	_on_ready()
	
func _on_ready() -> void:
	pass

func project_init() -> void:
	pass

func _process(delta: float) -> void:
	_on_process(delta)

func _on_process(_delta: float) -> void:
	pass
