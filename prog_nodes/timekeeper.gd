# timekeeper.gd
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
# Maintains "time" and provides Gregorian calendar & clock elements and related
# conversion functions.
#
# For definitions of Julian Day and Julian Day Number (jdn: int), see:
# https://en.wikipedia.org/wiki/Julian_day.
#
# "time" here always refers to sim time, which runs in seconds (assuming
# UnitDefs.SECOND = 1.0) from J2000 epoch, which was at 2000-01-01 12:00.
# "j2000days" is just time / UnitDefs.DAY. We avoid using Julian Day for
# float calculations due to precision loss.
#
# In priciple, "UT", "UT1", etc., are all approximations (in some way) of solar
# day, which is not equal to a Julian Day and (in the real world) varies. For
# now, we are using ut = j2000days + 0.5. But UT conversion functions are non-
# static in case we hook up to sim solar day in the future.
#
# For calendar calculations see:
# https://en.wikipedia.org/wiki/Julian_day
# https://en.wikipedia.org/wiki/Epoch_(astronomy)#Julian_years_and_J2000
#
# This node processes during SceneTree pause, but stops and starts processing
# following StateManager "is_running" state. StateManager has authority over
# pause, but we signal pause changes here as a "speed_changed" event.

extends Node
class_name Timekeeper

signal processed(sim_time, engine_delta) # this drives the simulator
signal speed_changed(speed_index, is_reversed, is_paused, show_clock, show_seconds, is_real_world_time)
signal date_changed() # normal day rollover
signal time_altered(previous_time) # someone manipulated time!

const SECOND := UnitDefs.SECOND # sim_time conversion
const MINUTE := UnitDefs.MINUTE
const HOUR := UnitDefs.HOUR
const DAY := UnitDefs.DAY
const J2000_JDN := 2451545 # Julian Day Number (JDN) of J2000 epoch time
const NO_NETWORK = Enums.NetworkState.NO_NETWORK
const IS_SERVER = Enums.NetworkState.IS_SERVER
const IS_CLIENT = Enums.NetworkState.IS_CLIENT

# project vars
var sync_tolerance := 0.2 # engine time (seconds)
var start_real_world_time := false # true overrides other start settings
var speeds := [ # sim_units / delta
		UnitDefs.SECOND, # real-time if UnitDefs.SECOND = 1.0
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
var real_time_speed := 0
var start_speed := 2
var show_clock_speed := 2 # this index and lower
var show_seconds_speed := 1 # this index and lower
var date_format_for_file := "%02d-%02d-%02d" # keep safe for file name!

# public persisted - read-only!
var time: float # seconds from J2000 epoch
var solar_day: float # calculate UT from the fractional part
var speed_index: int
var is_paused := false # always same as Global.state.is_paused
var is_reversed := false

# persistence
const PERSIST_AS_PROCEDURAL_OBJECT := false
const PERSIST_PROPERTIES := ["time", "solar_day", "speed_index", "is_paused", "is_reversed"]

# public - read only!
var is_real_world_time := false
var engine_time: float # accumulated delta
var speed_multiplier: float # negative if is_reversed
var show_clock := false
var show_seconds := false
var speed_name: String
var speed_symbol: String
var times: Array = Global.times # [0] time (s, J2000) [1] engine_time [2] UT1
var date: Array = Global.date # Gregorian [0] year [1] month [2] day (ints)
var clock: Array = Global.clock # UT1 [0] hour [1] minute [2] second (ints)

# private
var _state: Dictionary = Global.state
onready var _tree := get_tree()
onready var _allow_real_world_time: bool = Global.allow_real_world_time
onready var _allow_time_reversal: bool = Global.allow_time_reversal
var _network_state := NO_NETWORK
var _is_sync := false
var _sync_engine_time := -INF
var _adj_sync_tolerance := 0.0
var _prev_whole_solar_day := NAN


static func get_sim_time(Y: int, M: int, D: int, h := 12, m := 0, s := 0) -> float:
	# Simulator "time" is seconds since J2000 epoch; see details above.
	# Return not exact depending on input type (UT1, UTC, etc.) but very close.
	# Does not test for valid input! Use is_valid_gregorian_date().
	var jdn := gregorian2jdn(Y, M, D)
	var j2000days := float(jdn - J2000_JDN)
	var sim_time := (j2000days - 0.5) * DAY
	sim_time += h * HOUR
	sim_time += m * MINUTE
	sim_time += s * SECOND
	return sim_time

static func is_valid_gregorian_date(Y: int, M: int, D: int) -> bool:
	if M < 1 or M > 12 or D < 1 or D > 31:
		return false
	if D < 29:
		return true
	var jdn := gregorian2jdn(Y, M, D)
	var test_date := [0, 0, 0]
	set_gregorian_date_array(jdn, test_date)
	return test_date == [Y, M, D]

static func gregorian2jdn(Y: int, M: int, D: int) -> int:
	# Does not test for valid input date!
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	var jdn := (1461 * (Y + 4800 + (M - 14) / 12)) / 4
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	jdn += (367 * (M - 2 - 12 * ((M - 14) / 12))) / 12
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	jdn += -(3 * ((Y + 4900 + (M - 14) / 12) / 100)) / 4 + D - 32075
	return jdn

static func set_gregorian_date_array(jdn: int, date_array: Array) -> void:
	# Expects date_array of size 3
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
	date_array[0] = (e / 1461) - 4716 + ((14 - m) / 12) # year
	# warning-ignore:integer_division
	date_array[1] = m # month
	# warning-ignore:integer_division
	date_array[2] = ((h % 153) / 5) + 1 # day

static func get_clock_elements(fractional_day: float) -> Array:
	# returns [h, m, s]
	var clock_array := [0, 0, 0]
	set_clock_array(fractional_day, clock_array)
	return clock_array
	
static func set_clock_array(fractional_day: float, clock_array: Array) -> void:
	# Expects clock_ of size 3. It's possible to have second > 59 if fractional
	# day > 1.0 (which can happen when solar day > Julian Day).
	var total_seconds := int(fractional_day * 86400.0)
	# warning-ignore:integer_division
	var h := total_seconds / 3600
	# warning-ignore:integer_division
	var m := (total_seconds / 60) % 60
	clock_array[0] = h
	clock_array[1] = m
	clock_array[2] = total_seconds - h * 3600 - m * 60

func get_gregorian_date(sim_time := NAN) -> Array:
	# returns [Y, M, D]
	if is_nan(sim_time):
		sim_time = time
	var solar_day_ := get_solar_day(sim_time)
	var jdn := get_jdn_for_solar_day(solar_day_)
	var date_array := [0, 0, 0]
	set_gregorian_date_array(jdn, date_array)
	return date_array

func get_gregorian_date_time(sim_time := NAN) -> Array:
	# returns [[Y, M, D], [h, m, s]]
	if is_nan(sim_time):
		sim_time = time
	var solar_day_ := get_solar_day(sim_time)
	var jdn := get_jdn_for_solar_day(solar_day_)
	var date_array := [0, 0, 0]
	set_gregorian_date_array(jdn, date_array)
	var fractional_day := fposmod(solar_day_, 1.0)
	var clock_array := get_clock_elements(fractional_day)
	return [date_array, clock_array]

func get_solar_day(sim_time := NAN) -> float:
	if is_nan(sim_time):
		sim_time = time
	# TODO: Return days corresponding to simulated Earth solar day.
	# For now, we use approximation Julian Day == solar day.
	return sim_time / DAY + 0.5

func get_time_from_solar_day(solar_day_: float) -> float:
	# Inverse of whatever we do above.
	return (solar_day_ - 0.5) * DAY

func get_jdn_for_solar_day(solar_day_: float) -> int:
	var solar_day_noon := floor(solar_day_) + 0.5
	var sim_time := get_time_from_solar_day(solar_day_noon)
	var j2000day := sim_time / DAY
	return int(floor(j2000day)) + J2000_JDN

func get_real_world_time() -> float:
	var sys_msec := OS.get_system_time_msecs() # is this ok for all systems?
	var j2000sec := (sys_msec - 946728000000) * 0.001
	return j2000sec * SECOND

func get_current_date_for_file() -> String:
	return date_format_for_file % date

func set_paused(pause: bool, is_toggle := false) -> void:
	# 1st arg ignored if is_toggle. Timekeeper has authority over pause, so
	# all changes should use this function or Global signal "pause_requested".
	var new_paused: bool
	if is_toggle:
		new_paused = !is_paused
	else:
		new_paused = pause
	if is_paused != new_paused:
		is_paused = new_paused
		_state.is_paused = new_paused
		Global.emit_signal("sim_pause_changed", new_paused)
		emit_signal("speed_changed", speed_index, is_reversed, is_paused, show_clock,
				show_seconds, is_real_world_time)

func set_real_world() -> void:
	if _network_state == IS_CLIENT:
		return
	if !_allow_real_world_time:
		return
	if !is_real_world_time:
		set_time_reversed(false)
		change_speed(0, real_time_speed)
		is_real_world_time = true
	var previous_time := time
	time = get_real_world_time()
	_reset_time()
	emit_signal("time_altered", previous_time)

func set_time(new_time: float) -> void:
	if _network_state == IS_CLIENT:
		return
	var previous_time := time
	time = new_time
	is_real_world_time = false
	_reset_time()
	emit_signal("time_altered", previous_time)

func set_time_reversed(new_is_reversed: bool) -> void:
	if _network_state == IS_CLIENT:
		return
	if !_allow_time_reversal or is_reversed == new_is_reversed:
		return
	is_reversed = new_is_reversed
	speed_multiplier *= -1.0
	is_real_world_time = false
	emit_signal("speed_changed", speed_index, is_reversed, is_paused, show_clock,
			show_seconds, is_real_world_time)

func change_speed(delta_index: int, new_index := -1) -> void:
	if _network_state == IS_CLIENT:
		return
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
	is_real_world_time = false
	_reset_speed()
	emit_signal("speed_changed", speed_index, is_reversed, is_paused, show_clock,
			show_seconds, is_real_world_time)

func can_incr_speed() -> bool:
	return speed_index < speeds.size() - 1

func can_decr_speed() -> bool:
	return speed_index > 0

# *****************************************************************************

func _project_init() -> void:
	times.resize(3)
	date.resize(3)
	clock.resize(3)
	_set_init_state()

func _ready() -> void:
	_on_ready() # subclass can override

func _on_ready() -> void:
	Global.connect("pause_requested", self, "set_paused")
	Global.connect("network_state_changed", self, "_on_network_state_changed")
	Global.connect("run_state_changed", self, "_on_run_state_changed") # starts/stops
	Global.connect("about_to_free_procedural_nodes", self, "_set_init_state")
	Global.connect("game_load_finished", self, "_set_ready_state")
	Global.connect("simulator_exited", self, "_set_ready_state")
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator")
	Global.connect("update_gui_needed", self, "_refresh_gui")
	connect("speed_changed", self, "_on_speed_changed")
	_set_ready_state()
	set_process(false) # changes with "run_state_changed" signal
	set_process_priority(-100) # always first!

func _on_network_state_changed(network_state: int) -> void:
	_network_state = network_state

func _set_init_state() -> void:
	if start_real_world_time:
		time = get_real_world_time()
	else:
		time = Global.start_time
	engine_time = 0.0
	times[0] = time
	times[1] = engine_time
	is_paused = false
	_state.is_paused = false
	speed_index = start_speed

func _set_ready_state() -> void:
	_reset_time()
	_reset_speed()

func _reset_time() -> void:
	solar_day = get_solar_day(time)
	times[0] = time
	times[2] = solar_day
	var jdn := get_jdn_for_solar_day(solar_day)
	set_gregorian_date_array(jdn, date)
	set_clock_array(fposmod(solar_day, 1.0), clock)

func _reset_speed() -> void:
	speed_multiplier = speeds[speed_index]
	if is_reversed:
		speed_multiplier *= -1.0
	speed_name = speed_names[speed_index]
	speed_symbol = speed_symbols[speed_index]
	show_clock = speed_index <= show_clock_speed
	show_seconds = show_clock and speed_index <= show_seconds_speed

func _refresh_gui() -> void:
	emit_signal("speed_changed", speed_index, is_reversed, is_paused, show_clock,
			show_seconds, is_real_world_time)

func _on_about_to_start_simulator(is_new_game: bool) -> void:
	if is_new_game:
		if start_real_world_time:
			set_real_world()
	else:
		is_paused = is_paused or Global.settings.loaded_game_is_paused
		_state.is_paused = is_paused

func _on_run_state_changed(is_running: bool) -> void:
	set_process(is_running)
	if is_running and is_real_world_time:
		yield(_tree, "idle_frame")
		set_real_world()

remote func _time_sync(time_: float, engine_time_: float, speed_multiplier_: float) -> void:
	# client-side network game only
	if _tree.get_rpc_sender_id() != 1:
		return # from server only
	if engine_time_ < _sync_engine_time: # out-of-order packet
		return
	_sync_engine_time = engine_time_
	if speed_multiplier != speed_multiplier_:
		speed_multiplier = speed_multiplier_
		_adj_sync_tolerance = sync_tolerance * abs(speed_multiplier_)
	var time_diff := time_ - time
	if abs(time_diff) < _adj_sync_tolerance:
		return
	# <1% in LAN test w/ sync_tolerance = 0.1
	_is_sync = true
	# move 1/4 toward the sync value
	time = time_ - 0.75 * time_diff
	engine_time = 0.75 * engine_time + 0.25 * engine_time_

remote func _speed_changed_sync(speed_index_: int, is_reversed_: bool, is_paused_: bool,
		show_clock_: bool, show_seconds_: bool, is_real_world_time_: bool) -> void:
	# client-side network game only
	if _tree.get_rpc_sender_id() != 1:
		return # from server only
	speed_index = speed_index_
	speed_name = speed_names[speed_index_]
	speed_symbol = speed_symbols[speed_index_]
	is_reversed = is_reversed_
	show_clock = show_clock_
	show_seconds = show_seconds_
	is_real_world_time = is_real_world_time_
	if is_paused != is_paused_:
		Global.emit_signal("pause_requested", is_paused_) # will trigger update
	else:
		emit_signal("speed_changed", speed_index_, is_reversed_, is_paused_, show_clock_,
				show_seconds_, is_real_world_time_)

func _on_speed_changed(speed_index_: int, is_reversed_: bool, is_paused_: bool,
		show_clock_: bool, show_seconds_: bool, is_real_world_time_: bool) -> void:
	if _network_state != IS_SERVER:
		return
	rpc("_speed_changed_sync", speed_index_, is_reversed_, is_paused_, show_clock_,
			show_seconds_, is_real_world_time_)

func _process(delta: float) -> void:
	_on_process(delta) # subclass can override

func _on_process(delta: float) -> void:
	if !_is_sync:
		engine_time += delta
	times[1] = engine_time
	var is_date_change := false
	if !is_paused:
		if !_is_sync:
			time += delta * speed_multiplier
		solar_day = get_solar_day(time)
		var whole_solar_day := floor(solar_day)
		if _prev_whole_solar_day != whole_solar_day:
			var jdn := get_jdn_for_solar_day(solar_day)
			set_gregorian_date_array(jdn, date)
			is_date_change = true
			_prev_whole_solar_day = whole_solar_day
		set_clock_array(solar_day - whole_solar_day, clock)
		times[0] = time
		times[2] = solar_day
	# network sync
	if _network_state == IS_SERVER:
		rpc_unreliable("_time_sync", time, engine_time, speed_multiplier)
	_is_sync = false
	# signal time and date
	if is_date_change:
		emit_signal("date_changed")
	emit_signal("processed", time, delta)
