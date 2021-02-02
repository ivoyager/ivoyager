# timekeeper.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# "I, Voyager" is a registered trademark of Charlie Whitfield
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
# This node processes during pause, but stops and starts processing on
# "run_state_changed" signal.
#
# Also provides dynamic signal creation for timer function, using either engine
# time (w/ or w/out pause) or sim time.

extends Node
class_name Timekeeper

signal processed(sim_time, engine_delta) # this drives the simulator
signal speed_changed(speed_index, is_reversed, is_paused, show_clock, show_seconds, is_real_world_time)
signal date_changed() # normal day rollover
signal time_altered() # someone manipulated time!

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
var default_speed := 2
var show_clock_speed := 2 # this index and lower
var show_seconds_speed := 1 # this index and lower
var date_format_for_file := "%02d-%02d-%02d" # keep safe for file name!
# Regex format "2000-01-01 00:00:00:00". Optional [./-] for date separator.
# Can truncate after any time element after year.
var regexpr := "^(-?\\d+)(?:[\\.\\/\\-](\\d\\d))?(?:[\\.\\/\\-](\\d\\d))?(?: " \
		+ "(\\d\\d))?(?::(\\d\\d))?(?::(\\d\\d))?(?::(\\d\\d))?$"

# public persisted - read-only!
var time: float # seconds from J2000 epoch (= 2000-01-01 12:00:00)
var ut1: float # UT1 (mean solar days from J2000 - 0.5)
var speed_index: int
var is_paused := true # lags 1 frame behind actual tree pause
var is_reversed := false

# persistence
const PERSIST_AS_PROCEDURAL_OBJECT := false
const PERSIST_PROPERTIES := ["time", "ut1", "speed_index", "is_paused", "is_reversed"]

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
var _date_time_regex := RegEx.new()
onready var _tree := get_tree()
onready var _allow_real_world_time: bool = Global.allow_real_world_time
onready var _allow_time_reversal: bool = Global.allow_time_reversal
var _network_state := NO_NETWORK
var _is_sync := false
var _sync_engine_time := -INF
var _adj_sync_tolerance := 0.0
var _prev_ut1_floor := -INF


static func set_ut1_clock_array(ut1_: float, clock_: Array) -> void:
	# Expects clock_ of size 3
	ut1_ = fposmod(ut1_, 1.0)
	var total_seconds := int(ut1_ * 86400.0)
	# warning-ignore:integer_division
	clock_[0] = total_seconds / 3600
	# warning-ignore:integer_division
	clock_[1] = (total_seconds / 60) % 60
	clock_[2] = total_seconds % 60

static func set_gregorian_date_array(ut1_: float, date_: Array) -> void:
	# Expects date_ of size 3
	var jdn := int(floor(ut1_)) + J2000_JDN 
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

func get_real_world_time() -> float:
	var sys_msec := OS.get_system_time_msecs() # is this ok for all systems?
	var j2000_s := (sys_msec - 946728000000) * 0.001
	return j2000_s * SECOND # this is sim_time

func get_ut1(sim_time: float) -> float:
	# This is close for J2000 +- 1000 yrs. Beyond that, Julian days diverge
	# significantly from solar days. Note that our sim solar days are somewhat
	# but not entirely simplified: sidereal day is constant but orbit is
	# adjusted from 3000BCE - 3000CE. Conceptually, UT1 should be coupled to
	# simulated Earth's solar day, whatever that happens to be. To do so, we
	# would need to account for Earth's dynamic orbit (rates of Om & w).
	return sim_time / DAY + 0.5

func get_time_from_ut1(ut1_: float) -> float:
	# see comment above
	return (ut1_ - 0.5) * DAY

func get_current_date_for_file() -> String:
	return date_format_for_file % date

func set_real_world() -> void:
	if _network_state == IS_CLIENT:
		return
	if !_allow_real_world_time:
		return
	if !is_real_world_time:
		set_time_reversed(false)
		change_speed(0, real_time_speed)
		is_real_world_time = true
	time = get_real_world_time()
	_reset_time()
	emit_signal("time_altered")

func set_time(new_time: float) -> void:
	if _network_state == IS_CLIENT:
		return
	time = new_time
	is_real_world_time = false
	_reset_time()
	emit_signal("time_altered")

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

func project_init() -> void:
	Global.connect("run_state_changed", self, "_on_run_state_changed") # starts/stops
	Global.connect("about_to_free_procedural_nodes", self, "_set_init_state")
	Global.connect("game_load_finished", self, "_set_ready_state")
	Global.connect("simulator_exited", self, "_set_ready_state")
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator")
	Global.connect("gui_refresh_requested", self, "_refresh_gui")
	_date_time_regex.compile(regexpr)
	times.resize(3)
	date.resize(3)
	clock.resize(3)
	_set_init_state()
	_set_ready_state()

# **************************** VIRTUAL & PRIVATE ******************************

func _ready() -> void:
	_on_ready() # subclass can override

func _on_ready() -> void:
	connect("speed_changed", self, "_on_speed_changed")
	set_process(false) # changes with "run_state_changed" signal

func _on_network_state_changed(network_state: int) -> void:
	# this function is hooked up from StateManager
	_network_state = network_state

func _set_init_state() -> void:
	if start_real_world_time:
		time = get_real_world_time()
	else:
		time = Global.start_time
	engine_time = 0.0
	times[0] = time
	times[1] = engine_time
	is_paused = true
	speed_index = default_speed

func _set_ready_state() -> void:
	_reset_time()
	_reset_speed()

func _reset_time() -> void:
	ut1 = get_ut1(time)
	times[0] = time
	times[2] = ut1
	set_gregorian_date_array(ut1, date)
	set_ut1_clock_array(ut1, clock)

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

func _on_about_to_start_simulator(_is_new_game: bool) -> void:
	if start_real_world_time:
		set_real_world()

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
	is_paused = is_paused_
	_tree.paused = is_paused_
	show_clock = show_clock_
	show_seconds = show_seconds_
	is_real_world_time = is_real_world_time_
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
	if is_paused != _tree.paused:
		is_paused = !is_paused
		emit_signal("speed_changed", speed_index, is_reversed, is_paused,
				show_clock, show_seconds, is_real_world_time)
	if !_is_sync:
		engine_time += delta
	times[1] = engine_time
	var is_date_change := false
	if !is_paused:
		if !_is_sync:
			time += delta * speed_multiplier
		var new_ut1 := get_ut1(time)
		var new_ut1_floor := floor(new_ut1)
		if new_ut1_floor != _prev_ut1_floor: # new solar day
			set_gregorian_date_array(new_ut1_floor, date)
			is_date_change = true
			_prev_ut1_floor = new_ut1_floor
		set_ut1_clock_array(new_ut1, clock)
		ut1 = new_ut1
		times[0] = time
		times[2] = new_ut1
	# network sync
	if _network_state == IS_SERVER:
		rpc_unreliable("_time_sync", time, engine_time, speed_multiplier)
	_is_sync = false
	# signal time and date
	if is_date_change:
		emit_signal("date_changed")
	emit_signal("processed", time, delta)
