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
# Maintains "time" and provides Gregorian calendar & clock elements and related
# conversion functions. For calendar calculations see:
# https://en.wikipedia.org/wiki/Julian_day
# https://en.wikipedia.org/wiki/Epoch_(astronomy)#Julian_years_and_J2000
# The sim runs in s from J2000 (=2000-01-01 12:00). However, this class could
# be subclassed to provide alternative time display and calendar signals, for
# example, a Martian calendar/clock.
# Processes through pause; stops/starts processing on run_state_changed signals.

extends Node
class_name Timekeeper

signal processed(time, sim_delta, engine_delta)
signal display_date_time_changed(date_time_str)
signal speed_changed(speed_str) # includes pause change
signal year_changed(year)
signal quarter_changed(quarter)
signal month_changed(month)
signal day_changed(day)

# project vars
var speeds := [
		[], # 0-element not used
		["GAME_SPEED_REAL_TIME", 1.0],
		["GAME_SPEED_MINUTE_PER_SECOND", 60.0],
		["GAME_SPEED_HOUR_PER_SECOND", Conv.HOUR],
		["GAME_SPEED_DAY_PER_SECOND", Conv.DAY],
		["GAME_SPEED_WEEK_PER_SECOND", Conv.DAY * 7.0],
		["GAME_SPEED_MONTH_PER_SECOND", Conv.DAY * 30.0]
	]
var default_speed := 3
var realtime_speed := 1
var show_clock_speed := 3
var show_seconds_speed := 2
# Regex format "2000-01-01 00:00:00:00". Optional [./-] for date separator.
# Can truncate after any time unit after year.
var regexpr := "^(-?\\d+)(?:[\\.\\/\\-](\\d\\d))?(?:[\\.\\/\\-](\\d\\d))?(?: " \
		+ "(\\d\\d))?(?::(\\d\\d))?(?::(\\d\\d))?(?::(\\d\\d))?$"

# public persisted - read-only!
var time: float # seconds from J2000 epoch
var speed_index := 0 # negative if time reversed
var speed_multiplier := 0.0 # negative if time reversed
var is_paused := false # lags 1 frame behind actual tree pause
var year := -1 # 2000, etc...
var quarter := -1 # 1-4
var month := -1 # 1-12
var day := -1 # 1-31
var ymd := [-1, -1, -1]
var yqmd := [-1, -1, -1, -1]

# private persisted
var _last_process_time: float
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
	"speed_multiplier", "is_paused", "year", "quarter", "month", "day", "ymd", "yqmd",
	"_last_process_time", "_speed_memory", "_date_str", "_hour_str", "_seconds_str"]

var _time_date: Array = Global.time_date
var _allow_time_reversal: bool = Global.allow_time_reversal
var _tree: SceneTree
var _hm := [-1, -1] # only updated when clock displayed!
var _day_rollover := -INF
var _minute_rollover := -INF
var _second_rollover := -INF
var _date_time_regex: RegEx
var _is_started := false


func project_init() -> void:
	Global.connect("game_load_finished", self, "_init_after_load")
	Global.connect("gui_refresh_requested", self, "reset")
	Global.connect("gui_refresh_requested", self, "_signal_speed_changed")
	Global.connect("run_state_changed", self, "set_process")
	_tree = Global.program.tree
	time = Global.start_time
	_time_date.resize(5)
	_time_date[0] = time
	set_yqmd(time, yqmd)
	_update_from_yqmd()
	_last_process_time = time
	is_paused = _tree.paused
	speed_index = default_speed
	speed_multiplier = speeds[default_speed][1]
	_speed_memory = default_speed
	_date_time_regex = RegEx.new()
	_date_time_regex.compile(regexpr)

static func get_hour(time_: float) -> int:
	return wrapi(int(floor(time_ / 3600.0 + 12.0)), 0, 24)

static func get_hour_minute_second(time_: float) -> Array:
	var h := wrapi(int(floor(time_ / 3600.0 + 12.0)), 0, 24)
	var m := wrapi(int(floor(time_ / 60.0)), 0, 60)
	var s := wrapi(int(floor(time_)), 0, 60)
	return [h, m, s]

static func set_yqmd(time_: float, yqmd_: Array) -> void:
	# Convert to Julian Day Number, then calendar integers.
	var jdn := int(floor(time_ * 86400.0 + 0.5)) + 2451545
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	var f := jdn + 1401 + ((((4 * jdn + 274277) / 146097) * 3) / 4) - 38
	var e := 4 * f + 3
	# warning-ignore:integer_division
	var g := (e % 1461) / 4
	var h := 5 * g + 2
	# warning-ignore:integer_division
	var m := (((h / 153) + 2) % 12) + 1
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	yqmd_[0] = (e / 1461) - 4716 + ((14 - m) / 12) # year
	# warning-ignore:integer_division
	yqmd_[1] = (m - 1) / 3 + 1 # quarter
	yqmd_[2] = m # month
	# warning-ignore:integer_division
	yqmd_[3] = ((h % 153) / 5) + 1 # day

static func get_date_time_string(time_: float, sep := "-", n_elements := 6) -> String:
	var yqmd_ := [-1, -1, -1, -1]
	set_yqmd(time_, yqmd_)
	if n_elements == 1:
		return "%s" % yqmd_[0]
	if n_elements == 2:
		return "%s%s%02d" % [yqmd_[0], sep, yqmd_[2]]
	if n_elements == 3:
		return "%s%s%02d%s%02d" % [yqmd_[0], sep, yqmd_[2], sep, yqmd_[3]]
	var hour := wrapi(int(floor(time_ / 3600.0 + 12.0)), 0, 24)
	if n_elements == 4:
		return "%s%s%02d%s%02d %02d" % [yqmd_[0], sep, yqmd_[2], sep, yqmd_[3], hour]
	var minute := wrapi(int(floor(time_ / 60.0)), 0, 60)
	if n_elements == 5:
		return "%s%s%02d%s%02d %02d:%02d" % [yqmd_[0], sep, yqmd_[2], sep, yqmd_[3],
				hour, minute]
	var second := wrapi(int(floor(time_)), 0, 60)
	if n_elements == 6:
		return "%s%s%02d%s%02d %02d:%02d:%02d" % [yqmd_[0], sep, yqmd_[2], sep, yqmd_[3],
				hour, minute, second]
	var sixtieth := wrapi(int(floor(time_ * 60.0)), 0, 60)
	return "%s%s%02d%s%02d %02d:%02d:%02d:%02d" % [yqmd_[0], sep, yqmd_[2], sep, yqmd_[3],
			hour, minute, second, sixtieth] 

func convert_date_time_string(string: String, min_elements := 1) -> float:
	# Inverse of get_date_time_string(). Valid string must follow format
	# "0000-00-00 00:00:00:00" where "/" or "." can substitute for "-" and
	# string can be truncated after any element. E.g., "2000", "2000-06",
	# "2000/06/01 12:12" are ok. A date without hour will be interpreted as
	# 12:00, not 00:00! Thus, "2000" returns 0.0 (=J2000 epoch).
	# Returns -INF if can't parse format or not provided min_elements (e.g.,
	# min_elements = 3 requires year, month, day, or more). Does not check for
	# input errors such as month > 12 or day > days in month.
	var regex_match := _date_time_regex.search(string)
	if !regex_match:
		return -INF
	var strings := regex_match.strings
	if !strings[min_elements - 1]:
		return -INF
	var y := int(strings[1]) # required
	var m := int(strings[2]) if strings[2] else 1 # default January
	var d := int(strings[3]) if strings[3] else 1 # default 1st
	var hour := float(strings[4]) if strings[4] else 12.0 # default noon
	var minute := float(strings[5]) if strings[5] else 0.0
	var second := float(strings[6]) if strings[6] else 0.0
	var sixtieth := float(strings[7]) if strings[7] else 0.0
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	var jdn: int = (1461 * (y + 4800 + (m - 14) / 12)) / 4
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	jdn += (367 * (m - 2 - 12 * ((m - 14) / 12))) / 12
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	jdn += -(3 * ((y + 4900 + (m - 14) / 12) / 100)) / 4 + d - 32075
	return float(jdn - 2451545) * 86400.0 + ((hour - 12.0) * 3600.0) \
			+ (minute * 60.0) + second + (sixtieth / 60.0)

func set_time(new_time: float) -> void:
	time = new_time
	_time_date[0] = new_time
	_last_process_time = new_time
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
	_signal_speed_changed()

func reset() -> void:
	_day_rollover = -INF
	_minute_rollover = -INF
	_second_rollover = -INF

func get_current_date_string(sep := "-") -> String:
	return str(year) + sep + ("%02d" % month) + sep + ("%02d" % day)

func _init_after_load() -> void:
	_is_started = false
	_time_date[0] = time
	_time_date[1] = year
	_time_date[2] = month
	_time_date[3] = day

func _ready() -> void:
	set_process(Global.state.is_running) # should be false

func _process(delta: float) -> void:
	_on_process(delta) # so subclass can override

func _on_process(delta: float) -> void:
	# detect and signal changes in pause state 
	if _tree.paused:
		if !is_paused:
			is_paused = true
			reset()
			_signal_speed_changed()
		if _is_started:
			emit_signal("processed", time, 0.0, delta)
			return
	elif is_paused:
		is_paused = false
		reset()
		_signal_speed_changed()
	if !_is_started:
		_is_started = true
		print("Starting Timekeeper")
	# simulator time
	time += delta * speed_multiplier # speed_multiplier < 0 for time reversal
	_time_date[0] = time
	_update_display_and_calendar()
	var sim_delta := time - _last_process_time
	_last_process_time = time
	emit_signal("processed", time, sim_delta, delta)

func _update_display_and_calendar() -> void:
	# Override this function for alternative calendar/clock
	var update_display := false
	if time > _day_rollover or (speed_index < 0 and time < _day_rollover - 1.0):
		set_yqmd(time, yqmd)
		_update_from_yqmd()
		_day_rollover = ceil(time * 86400.0 - 0.5) + 0.5
		_date_str = "%s-%02d-%02d" % ymd
		update_display = true
	var show_clock := speed_index <= show_clock_speed and speed_index >= -show_clock_speed
	if show_clock and (time > _minute_rollover or speed_index < 0):
		var total_minutes := time / 60.0
		_hm[0] = wrapi(int(floor(time / 3600.0 + 12.0)), 0, 24) # hour
		_hm[1] = wrapi(int(floor(total_minutes)), 0, 60) # minute
		_minute_rollover = ceil(total_minutes) * 60.0
		_hour_str = " %02d:%02d" % _hm
		update_display = true
	var show_seconds := show_clock and speed_index <= show_seconds_speed and speed_index >= -show_seconds_speed
	if show_seconds and (time > _second_rollover or speed_index < 0):
		var second := wrapi(int(floor(time)), 0, 60)
		_second_rollover = ceil(time)
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

func _update_from_yqmd() -> void:
	if year != yqmd[0]:
		year = yqmd[0]
		ymd[0] = year
		_time_date[1] = year
		_is_year_changed = true
	if quarter != yqmd[1]:
		quarter = yqmd[1]
		_time_date[2] = quarter
		_is_quarter_changed = true
	if month != yqmd[2]:
		month = yqmd[2]
		ymd[1] = month
		_time_date[3] = month
		_is_month_changed = true
	if day != yqmd[3]:
		day = yqmd[3]
		ymd[2] = day
		_time_date[4] = day
		_is_day_changed = true
	
func _signal_speed_changed() -> void:
	if _tree.paused:
		emit_signal("speed_changed", "GAME_SPEED_PAUSED")
		return
	if speed_index > 0:
		emit_signal("speed_changed", tr(speeds[speed_index][0]))
	else:
		emit_signal("speed_changed", "-" + tr(speeds[-speed_index][0]))
