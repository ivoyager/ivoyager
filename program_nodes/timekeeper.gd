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

signal processed(time, sim_delta, engine_delta) # this drives the simulator
signal speed_changed(speed_index, is_reversed, is_paused, show_clock, show_seconds)
signal date_changed() # keep date reference from Global.date

const SECOND := UnitDefs.SECOND # sim_time conversion only
const MINUTE := UnitDefs.MINUTE # sim_time conversion only
const HOUR := UnitDefs.HOUR # sim_time conversion only
const DAY := UnitDefs.DAY # sim_time conversion only
const JD_J2000 := 2451545.0 # Julian Date (JD) of J2000 epoch time 
const EARTH_ROTATION_PERIOD_D := 0.99726968 # same as planets.csv table!
const EARTH_ROTATION_PERIOD := EARTH_ROTATION_PERIOD_D * DAY # in sim_time

# project vars
var speeds := [ # sim_units / delta
		UnitDefs.SECOND, # real-time if SECOND = 1.0
		UnitDefs.MINUTE,
		UnitDefs.HOUR,
		UnitDefs.DAY,
		7.0 * UnitDefs.DAY,
		30.4375 * UnitDefs.DAY,
]
var speed_names := [
	"GAME_SPEED_REAL_TIME",
	"GAME_SPEED_MINUTE_PER_SECOND",
	"GAME_SPEED_HOUR_PER_SECOND",
	"GAME_SPEED_DAY_PER_SECOND",
	"GAME_SPEED_WEEK_PER_SECOND",
	"GAME_SPEED_MONTH_PER_SECOND",
]
var speed_symbols := [
	"GAME_SPEED_REAL_TIME",
	"GAME_SPEED_MINUTE_PER_SECOND",
	"GAME_SPEED_HOUR_PER_SECOND",
	"GAME_SPEED_DAY_PER_SECOND",
	"GAME_SPEED_WEEK_PER_SECOND",
	"GAME_SPEED_MONTH_PER_SECOND",
]
var default_speed := 2
var show_clock_speed := 2 # this index and lower
var show_seconds_speed := 1 # this index and lower
var date_format_for_file := "%02d-%02d-%02d" # keep safe for file name!

# Regex format "2000-01-01 00:00:00:00". Optional [./-] for date separator.
# Can truncate after any time element after year.
var regexpr := "^(-?\\d+)(?:[\\.\\/\\-](\\d\\d))?(?:[\\.\\/\\-](\\d\\d))?(?: " \
		+ "(\\d\\d))?(?::(\\d\\d))?(?::(\\d\\d))?(?::(\\d\\d))?$"

# public persisted - read-only!
var time: float # seconds from J2000 epoch (~12:00, 2000-01-01)
var universal_time: float # (mean solar days from J2000) - 0.5
var julian_day_number: int # for current UT1 solar day noon
var speed_index: int
var is_paused := true # lags 1 frame behind actual tree pause
var is_reversed := false

# persistence
const PERSIST_AS_PROCEDURAL_OBJECT := false
const PERSIST_PROPERTIES := ["time", "universal_time", "julian_day_number",
	"speed_index", "is_paused", "is_reversed"]

# public - read only!
var engine_time: float # accumulated delta
var speed_multiplier: float # negative if is_reversed
var show_clock := false
var show_seconds := false
var speed_name: String
var speed_symbol: String
var times: Array = Global.times # [0] time (s, J2000) [1] engine_time [2] UT1 [3] JDN
var date: Array = Global.date # Gregorian [0] year [1] month [2] day (ints)
var clock: Array = Global.clock # UT1 [0] hour [1] minute [2] second (ints)

# private
var _date_time_regex := RegEx.new()
var _signal_engine_times := []
var _signal_infos := []
var _signal_recycle := []
var _signal_counter := 0
onready var _tree := get_tree()
onready var _allow_time_reversal: bool = Global.allow_time_reversal


func project_init() -> void: # this is before _ready()
	Global.connect("run_state_changed", self, "set_process") # starts/stops
	Global.connect("about_to_free_procedural_nodes", self, "_set_init_state")
	Global.connect("game_load_finished", self, "_set_ready_state")
	Global.connect("simulator_exited", self, "_set_ready_state")
	_date_time_regex.compile(regexpr)
	times.resize(4)
	date.resize(3)
	clock.resize(3)
	_set_init_state()
	_set_ready_state()

func get_ut1(sim_time: float) -> float:
	# Use fposmod(ut1) to get fraction of day
	# From wiki:
	# ERA = TAU * (0.7790572732640 + 1.00273781191135448 * UT1)
	# Our simulator "UT1" is conceptually UT1, meaning it has to be derived
	# from our simulator Earth rotation and solar orbit. These happen to be
	# simplified somewhat, but not entirely.
	# TODO: Timekeeper has to know some facts about sim Earth state to do this
	# properly!
	var earth_rotations := sim_time / EARTH_ROTATION_PERIOD
	return (earth_rotations - 0.50137) / 1.00273781191135448

static func get_jdn_for_ut1(ut1: float) -> int:
	# Get JDN for UT1 12:00; this applies the full UT1 solar day!
	var ut1_midday := floor(ut1) + 0.5
	var earth_rotations := ut1_midday * 1.00273781191135448 + 0.50137
	var j2000_days := earth_rotations * EARTH_ROTATION_PERIOD_D
	return int(j2000_days + JD_J2000)

static func set_ut1_clock(ut1: float, clock_: Array) -> void:
	# Expects clock_ of size 3
	ut1 = fposmod(ut1, 1.0)
	var total_seconds := int(ut1 * 86400.0) # these are not SI seconds!
	# warning-ignore:integer_division
	clock_[0] = total_seconds / 3600
	# warning-ignore:integer_division
	clock_[1] = (total_seconds / 60) % 60
	clock_[2] = total_seconds % 60

static func set_gregorian_date(jdn: int, date_: Array) -> void:
	# Expects date_ of size 3
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
	date_[0] = (e / 1461) - 4716 + ((14 - m) / 12) # year
	# warning-ignore:integer_division
	date_[1] = m # month
	# warning-ignore:integer_division
	date_[2] = ((h % 153) / 5) + 1 # day

func get_current_date_for_file() -> String:
	return date_format_for_file % date

func change_time_reversed(new_is_reversed: bool) -> void:
	if !_allow_time_reversal or is_reversed == new_is_reversed:
		return
	is_reversed = new_is_reversed
	speed_multiplier *= -1.0
	emit_signal("speed_changed", speed_index, is_reversed, is_paused, show_clock, show_seconds)

func change_speed(delta_index: int, new_index := -1) -> void:
	# Supply [0, new_index] to set a specific index
	if new_index == -1:
		new_index = speed_index + delta_index
	if new_index < 0:
		new_index = 0
	elif new_index >= speeds.size():
		new_index = speeds.size() - 1
	if new_index == speed_index:
		return
	speed_index = new_index
	speed_multiplier = speeds[new_index]
	if is_reversed:
		speed_multiplier *= -1.0
	speed_name = speed_names[new_index]
	speed_symbol = speed_symbols[new_index]
	show_clock = new_index <= show_clock_speed
	show_seconds = show_clock and new_index <= show_seconds_speed
	emit_signal("speed_changed", speed_index, is_reversed, is_paused, show_clock, show_seconds)

func can_incr_speed() -> bool:
	return speed_index < speeds.size() - 1

func can_decr_speed() -> bool:
	return speed_index > 0

func make_engine_interval_signal(interval_s: float, offset_s: float) -> String:
	# Returns a signal string for caller to connect to. This is useful if you
	# have many GUIs updating at some interval and want them offset (so not on
	# same frame). The subscription is not persisted so must be renewed in a
	# loaded game.
	assert(interval_s > 0.3, "Use _process() for shorter intervals!")
	assert(offset_s <= interval_s)
	var signal_str: String
	if _signal_recycle:
		signal_str = _signal_recycle.pop_back()
	else:
		_signal_counter += 1
		signal_str = String(_signal_counter)
		add_user_signal(signal_str)
	var signal_info := [signal_str, interval_s]
	var next_signal := engine_time - fmod(engine_time, interval_s) + offset_s
	if next_signal <= engine_time:
		next_signal += interval_s
	_insert_engine_interval_signal(signal_info, next_signal)
	return signal_str

func recycle_engine_interval_signal(signal_str: String) -> void:
	# Recycle signal when it is safe for another subscriber to change & use.
	var n_signals := _signal_infos.size()
	var index := 0
	while index < n_signals:
		var test_signal_str: String = _signal_infos[index][0]
		if test_signal_str == signal_str:
			_signal_engine_times.remove(index)
			_signal_infos.remove(index)
			_signal_recycle.append(signal_str)
			return
		index += 1
	assert(false, "Attempted to recycle non-existing signal")

# PUBLIC FUNCTIONS BELOW HAVE NOT BEEN TESTED!!!


# **************************** VIRTUAL & PRIVATE ******************************

func _ready() -> void:
	_on_ready() # subclass can override

func _process(delta: float) -> void:
	_on_process(delta) # subclass can override

func _set_init_state() -> void:
	for signal_info in _signal_infos:
		var signal_str: String = signal_info[0]
		_signal_recycle.append(signal_str)
	_signal_infos.clear()
	_signal_engine_times.clear()
	_signal_engine_times.append(INF)
	time = Global.start_time
	engine_time = 0.0
	times[0] = time
	times[1] = engine_time
	is_paused = true
	speed_index = default_speed

func _set_ready_state() -> void:
	universal_time = get_ut1(time)
	julian_day_number = get_jdn_for_ut1(universal_time)
	times[2] = universal_time
	times[3] = julian_day_number
	set_gregorian_date(julian_day_number, date)
	set_ut1_clock(universal_time, clock)
	speed_multiplier = speeds[speed_index]
	speed_name = speed_names[speed_index]
	speed_symbol = speed_symbols[speed_index]
	show_clock = speed_index <= show_clock_speed
	show_seconds = show_clock and speed_index <= show_seconds_speed

func _on_ready() -> void:
	set_process(false) # changes with "run_state_changed" signal

func _on_process(delta: float) -> void:
	if is_paused != _tree.paused:
		is_paused = !is_paused
		emit_signal("speed_changed", speed_index, is_reversed, is_paused, show_clock, show_seconds)
	if is_paused:
		return
	engine_time += delta
	var sim_delta := delta * speed_multiplier
	time += sim_delta
	var new_ut1 := get_ut1(time)
	var is_date_change := false
	if floor(new_ut1) != floor(universal_time): # new solar day
		julian_day_number = get_jdn_for_ut1(new_ut1)
		set_gregorian_date(julian_day_number, date)
		is_date_change = true
	set_ut1_clock(new_ut1, clock)
	universal_time = new_ut1
	times[0] = time
	times[1] = engine_time
	times[2] = new_ut1
	times[3] = julian_day_number

	# We normally stagger engine interval signals to spread out the load on the
	# main thread (under the assumption these trigger GUI or other
	# computations).
	var process_one := true
	while engine_time > _signal_engine_times[0]: # fast negative result!
		var signal_time: float = _signal_engine_times.pop_front()
		var signal_info: Array = _signal_infos.pop_front()
		var signal_str: String = signal_info[0]
		var interval_s: float = signal_info[1]
		signal_time += interval_s
		if signal_time < engine_time: # we are way behind for some reason!
			process_one = false
			signal_time += interval_s
			while signal_time < engine_time:
				signal_time += interval_s
		_insert_engine_interval_signal(signal_info, signal_time)
		emit_signal(signal_str)
		if process_one:
			break
	if is_date_change:
		emit_signal("date_changed")
	emit_signal("processed", time, sim_delta, delta)

func _insert_engine_interval_signal(signal_info: Array, next_signal: float) -> void:
	var index := _signal_engine_times.bsearch(next_signal, false) # after equal value
	_signal_engine_times.insert(index, next_signal)
	_signal_infos.insert(index, signal_info)
