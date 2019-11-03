# timekeeper.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2019 Charlie Whitfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
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

signal processed(time, sim_delta)
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
