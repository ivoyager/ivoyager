# gregorian_timekeeper.gd
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
# Maintains "time" and provides Gregorian calendar & clock elements and 
# related conversion functions.
# For calandar calculations see https://en.wikipedia.org/wiki/Julian_day &
# https://en.wikipedia.org/wiki/Epoch_(astronomy)#Julian_years_and_J2000.
# Project vars set in _init(), but can be modified as usual by hooking up to
# ProjectBuilder "project_objects_instantiated" signal.

extends Timekeeper
class_name GregorianTimekeeper

signal year_changed(year)
signal quarter_changed(quarter)
signal month_changed(month)
signal day_changed(day)

var regex_compile: String

# ******************************* PERSISTED ***********************************

# public read-only
var year := -1 # 2000, etc...
var quarter := -1 # 1-4
var month := -1 # 1-12
var day := -1 # 1-31
var y_m_d := [-1, -1, -1] # use get functions for current hour, minute, second

# private
var _last_process_time := 0.0
var _speed_memory := -1
var _date_str := ""
var _hour_str := ""
var _seconds_str := ""
var _is_year_changed := true
var _is_quarter_changed := true
var _is_month_changed := true
var _is_day_changed := true

# persistence
const PERSIST_AS_PROCEDURAL_OBJECT := false
const PERSIST_PROPERTIES := ["time", "speed_index",
	"speed_multiplier", "is_paused", "year", "quarter", "month", "day", "y_m_d",
	"_last_process_time", "_speed_memory", "_date_str", "_hour_str", "_seconds_str"]

# ****************************** UNPERSISTED **********************************

var _tree: SceneTree
var _allow_time_reversal: bool = Global.allow_time_reversal
var _h_m := [-1, -1] # only updated when clock displayed!
var _last_yqmd := [-1, -1, -1, -1]
var _day_rollover := -INF
var _minute_rollover := -INF
var _second_rollover := -INF
var _date_time_regex: RegEx
var _is_started := false

# *************************** PUBLIC FUNCTIONS ********************************

func set_time(new_time: float, is_init := false) -> void:
	time = new_time
	_global_time_array[0] = new_time
	_last_process_time = new_time
	if !is_init:
		reset()

func increment_speed(increment: int) -> void:
	assert(increment == 1 or increment == -1)
	if _tree.paused: # unpause instead
		_tree.paused = false
		return
	var time_direction := 1 if speed_index > 0 else -1
	var new_speed_index := speed_index + increment * time_direction
	var n_speeds := speeds.size()
	if new_speed_index >= n_speeds:
		new_speed_index = n_speeds - 1
	elif new_speed_index <= -n_speeds:
		new_speed_index = -n_speeds + 1
	elif new_speed_index == 0:
		new_speed_index = time_direction
	if !_allow_time_reversal and new_speed_index < 1:
		new_speed_index = 1
	change_speed(new_speed_index)

func can_incr_speed() -> bool:
	return speed_index < speeds.size() - 1 and speed_index > 1 - speeds.size()

func can_decr_speed() -> bool:
	return speed_index > 1 or speed_index < -1

func is_real_time() -> bool:
	return speed_index == realtime_speed

func set_real_time(is_real_time: bool) -> void:
	if is_real_time == (speed_index == realtime_speed):
		return
	var new_speed_index = realtime_speed if is_real_time else _speed_memory
	change_speed(new_speed_index)

func reverse_time():
	if _allow_time_reversal:
		change_speed(-speed_index)

func set_reverse_time(is_reverse: bool):
	if _allow_time_reversal and is_reverse == (speed_index > 0):
		change_speed(-speed_index)

func change_speed(new_speed_index: int) -> void:
	assert(_allow_time_reversal or new_speed_index > 0)
	if speed_index == new_speed_index:
		return
	if new_speed_index == realtime_speed:
		_speed_memory = speed_index
	speed_index = new_speed_index
	if speed_index > 0:
		speed_multiplier = speeds[speed_index][1]
	else:
		speed_multiplier = -speeds[-speed_index][1]
	reset()
	signal_speed_changed()

func reset() -> void:
	_day_rollover = -INF
	_minute_rollover = -INF
	_second_rollover = -INF
	
func signal_speed_changed() -> void:
	if _tree.paused:
		emit_signal("speed_changed", "GAME_SPEED_PAUSED")
		return
	if speed_index > 0:
		emit_signal("speed_changed", tr(speeds[speed_index][0]))
	else:
		emit_signal("speed_changed", "-" + tr(speeds[-speed_index][0]))

func get_hour(time: float) -> int:
	return wrapi(int(floor(time * 24.0 + 12.0)), 0, 24)

func get_hour_minute_second(time: float) -> Array:
	var hour = wrapi(int(floor(time * 24.0 + 12.0)), 0, 24)
	var minute = wrapi(int(floor(time * 1440.0)), 0, 60)
	var second = wrapi(int(floor(time * 86400.0)), 0, 60)
	return [hour, minute, second]

func get_current_date_string(separator := "-") -> String:
	return str(year) + separator + ("%02d" % month) + separator + ("%02d" % day)
	
static func get_date_time_string(time_: float, separator := "-", n_elements := 6) -> String:
	# Convert J2000 to Julian Day Number, then to Gregorian date integers.
	# In-line calculations copied in _process().
	var julian_day_number := int(floor(time_ + 0.5)) + 2451545 # Julian Day Number
	#warning-ignore:integer_division
	#warning-ignore:integer_division
	var f := julian_day_number + 1401 + ((((4 * julian_day_number + 274277) / 146097) * 3) / 4) - 38
	var e := 4 * f + 3
	#warning-ignore:integer_division
	var g := ((e % 1461) / 4)
	var h := 5 * g + 2
	#warning-ignore:integer_division
	var day_ := ((h % 153) / 5) + 1
	#warning-ignore:integer_division
	var month_ := (((h / 153) + 2) % 12) + 1
	#warning-ignore:integer_division
	#warning-ignore:integer_division
	var year_ := (e / 1461) - 4716 + ((14 - month_) / 12)
	if n_elements == 1:
		return "%s" % year_
	if n_elements == 2:
		return "%s%s%02d" % [year_, separator, month_]
	if n_elements == 3:
		return "%s%s%02d%s%02d" % [year_, separator, month_, separator, day_]
	var hour := wrapi(int(floor(time_ * 24.0 + 12.0)), 0, 24)
	if n_elements == 4:
		return "%s%s%02d%s%02d %02d" % [year_, separator, month_, separator, day_, hour]
	var minute := wrapi(int(floor(time_ * 1440.0)), 0, 60)
	if n_elements == 5:
		return "%s%s%02d%s%02d %02d:%02d" % [year_, separator, month_, separator, day_, hour, minute]
	var second := wrapi(int(floor(time_ * 86400.0)), 0, 60)
	if n_elements == 6:
		return "%s%s%02d%s%02d %02d:%02d:%02d" % [year_, separator, month_, separator, day_, hour, minute, second]
	var sixtieth_second := wrapi(int(floor(time_ * 5184000.0)), 0, 60)
	return "%s%s%02d%s%02d %02d:%02d:%02d:%02d" % \
			[year_, separator, month_, separator, day_, hour, minute, second, sixtieth_second] 

func convert_date_time_string(date_time_string: String, min_elements := 1) -> float:
	# Valid string must follow "0000-00-00 00:00:00:00" format, where "/" or "."
	# can substitute for "-" and string can be truncated after any time unit.
	# E.g., "2000", "2000-06", "2000/06/01 12:12" are ok.
	# A date without hour will be interpreted as 12:00, not 00:00! Thus, "2000"
	# returns 0.0 (=J2000 epoch).
	# Returns -INF if can't parse format or not provided min_elements (e.g.,
	# min_elements = 3 requires year, month, day, or more).
	var regex_match := _date_time_regex.search(date_time_string)
	if regex_match == null:
		return -INF
	var match_array := regex_match.strings
	if match_array[min_elements - 1] == null:
		return -INF
	var y := int(match_array[1])
	var m := int(match_array[2]) if match_array[2] else 0
	var d := int(match_array[3]) if match_array[3] else 0
	var hour := float(match_array[4]) if match_array[4] else 12.0
	var minute := float(match_array[5]) if match_array[5] else 0.0
	var second := float(match_array[6]) if match_array[6] else 0.0
	var sixtieth_second := float(match_array[7]) if match_array[7] else 0.0
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	var julian_day_number: int = (1461 * (y + 4800 + (m - 14) / 12)) / 4
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	julian_day_number += (367 * (m - 2 - 12 * ((m - 14) / 12))) / 12
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	julian_day_number += -(3 * ((y + 4900 + (m - 14) / 12) / 100)) / 4 + d - 32075
	if hour < 12:
		julian_day_number -= 1
	return float(julian_day_number - 2451545) + ((hour - 12.0) / 24.0) \
			+ (minute / 1440.0) + (second / 86400.0) + (sixtieth_second / 5184000.0)

# *********************** VIRTUAL & PRIVATE FUNCTIONS *************************

func _on_init() -> void:
	_global_time_array.resize(4)
	# Project vars below are inited here, but can be modified as usual by
	# connecting to ProjectBuilder "project_objects_instantiated" signal.
	# Regex format "2000-01-01 00:00:00:00". Optional [./-] for date separator.
	# Can truncate after any time unit after year.
	regex_compile = "^(-?\\d+)(?:[\\.\\/\\-](\\d\\d))?(?:[\\.\\/\\-](\\d\\d))?(?: (\\d\\d))?(?::(\\d\\d))?(?::(\\d\\d))?(?::(\\d\\d))?$"
	speeds = [
		[], # 0-element not used
		["GAME_SPEED_REAL_TIME", 1.0 / 86400.0],
		["GAME_SPEED_MINUTE_PER_SECOND", 1.0 / 1440.0],
		["GAME_SPEED_HOUR_PER_SECOND", 1.0 / 24.0],
		["GAME_SPEED_DAY_PER_SECOND", 1.0], # time is days; Godot delta is seconds
		["GAME_SPEED_WEEK_PER_SECOND", 7.0],
		["GAME_SPEED_MONTH_PER_SECOND", 30.0]
	]
	default_speed = 3
	realtime_speed = 1
	show_clock_speed = 3
	show_seconds_speed = 2

func _init_after_load() -> void:
	_is_started = false
	_global_time_array[0] = time
	_global_time_array[1] = year
	_global_time_array[2] = month
	_global_time_array[3] = day

func _on_ready() -> void:
	_tree = Global.objects.tree
	Global.connect("game_load_finished", self, "_init_after_load")
	Global.connect("gui_refresh_requested", self, "reset")
	Global.connect("gui_refresh_requested", self, "signal_speed_changed")
	Global.connect("run_state_changed", self, "_set_run_state")
	time = Global.start_time
	_global_time_array[0] = time
	_update_yqmd(time)
	_last_process_time = time
	is_paused = _tree.paused
	speed_index = default_speed
	speed_multiplier = speeds[default_speed][1]
	_speed_memory = default_speed
	_date_time_regex = RegEx.new()
	_date_time_regex.compile(regex_compile)
	_set_run_state(Global.state.is_running)
	
func _set_run_state(is_running: bool) -> void:
	set_process(is_running)

func _on_process(delta: float) -> void:
	# detect and signal changes in pause state 
	if _tree.paused:
		if !is_paused:
			is_paused = true
			reset()
			signal_speed_changed()
		if _is_started:
			emit_signal("processed", time, 0.0, delta)
			return
	elif is_paused:
		is_paused = false
		reset()
		signal_speed_changed()
	if !_is_started:
		print("starting Timekeeper")
	_is_started = true
	# simulator time
	time += delta * speed_multiplier # speed_multiplier < 0 for time reversal
	_global_time_array[0] = time
	# display & caledar
	var update_display := false
	if time > _day_rollover or (speed_index < 0 and time < _day_rollover - 1.0):
		_update_yqmd(time)
		_day_rollover = ceil(time - 0.5) + 0.5
		_date_str = "%s-%02d-%02d" % y_m_d
		update_display = true
	var show_clock := speed_index <= show_clock_speed and speed_index >= -show_clock_speed
	if show_clock and (time > _minute_rollover or speed_index < 0):
		var total_minutes := time * 1440.0
		_h_m[0] = wrapi(int(floor(time * 24.0 + 12.0)), 0, 24) # hour
		_h_m[1] = wrapi(int(floor(total_minutes)), 0, 60) # minute
		_minute_rollover = ceil(total_minutes) / 1440.0
		_hour_str = " %02d:%02d" % _h_m
		update_display = true
	var show_seconds := show_clock and speed_index <= show_seconds_speed and speed_index >= -show_seconds_speed
	if show_seconds and (time > _second_rollover or speed_index < 0):
		var total_seconds := time * 86400.0
		var second := wrapi(int(floor(total_seconds)), 0, 60)
		_second_rollover = ceil(total_seconds) / 86400.0
		_seconds_str = ":%02d" % second
		update_display = true
	if update_display:
		var date_time_str := _date_str
		if show_clock:
			date_time_str += _hour_str
			if show_seconds:
				date_time_str += _seconds_str
		emit_signal("display_date_time_changed", date_time_str)
	if _is_day_changed:
		_is_day_changed = false
		emit_signal("day_changed", day)
	if _is_month_changed:
		_is_month_changed = false
		emit_signal("month_changed", month)
	if _is_quarter_changed:
		_is_quarter_changed = false
		emit_signal("quarter_changed", quarter)
	if _is_year_changed:
		_is_year_changed = false
		emit_signal("year_changed", year)
	var sim_delta := time - _last_process_time
	_last_process_time = time
	emit_signal("processed", time, sim_delta, delta)

func _update_yqmd(time: float) -> void:
	var julian_day_number := int(floor(time + 0.5)) + 2451545
	#warning-ignore:integer_division
	#warning-ignore:integer_division
	var f := julian_day_number + 1401 + ((((4 * julian_day_number + 274277) / 146097) * 3) / 4) - 38
	var e := 4 * f + 3
	#warning-ignore:integer_division
	var g := ((e % 1461) / 4)
	var h := 5 * g + 2
	#warning-ignore:integer_division
	day = ((h % 153) / 5) + 1
	#warning-ignore:integer_division
	month = (((h / 153) + 2) % 12) + 1
	#warning-ignore:integer_division
	#warning-ignore:integer_division
	year = (e / 1461) - 4716 + ((14 - month) / 12)
	if y_m_d[0] != year:
		_is_year_changed = true
		y_m_d[0] = year
		_global_time_array[1] = year
	if y_m_d[1] != month:
		_is_month_changed = true
		y_m_d[1] = month
		_global_time_array[2] = month
	if y_m_d[2] != day:
		_is_day_changed = true
		y_m_d[2] = day
		_global_time_array[3] = day
	#warning-ignore:integer_division
	var new_quarter: int = (month - 1) / 3 + 1
	if quarter != new_quarter:
		_is_quarter_changed = true
		quarter = new_quarter
