# sim_timer.gd
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
# This works very differently than Godot's core Timer class! There is only one
# SimTimer. However, any number of objects can obtain and hook up to their
# own timer signals using make_interval_signal(). Max signal frequency will be
# once per frame.

# WIP - Make work in reverse time!


class_name SimTimer

var _times: Array = Global.times
var _timekeeper: Timekeeper
var _allow_time_reversal: bool = Global.allow_time_reversal
var _forward_signals := [[INF]] # last element in array is next to signal

var _reverse_signals := [[-INF]] # ???? Or reverse above ????

var _recycled_signals := []
var _counter := 0
var _is_reversed := false


func make_interval_signal(interval: float, one_time := false) -> String:
	# Returns a signal string for caller to connect to. If one_time == true,
	# be sure to connect using CONNECT_ONESHOT (the signal will be recycled and
	# used again for something else). If one_time == false but the caller is
	# done with the signal for some reason, it should be returned via
	# recycle_signal(). Use UnitDefs constants to convert to sim_time. E.g.,
	# for 2 days, use interval = 2.0 * UnitDefs.DAY.
	var signal_str: String
	if _recycled_signals:
		signal_str = _recycled_signals.pop_back()
	else:
		_counter += 1
		signal_str = str(_counter)
		add_user_signal(signal_str)
	var signal_time: float = _times[0] + interval
	var signal_info := [signal_time, interval, signal_str, one_time]
	var index := _forward_signals.bsearch_custom(signal_time, self, "_order")
	_forward_signals.insert(index, signal_info)
	return signal_str

func recycle_signal(signal_str: String) -> void:
	# Recycle signal when it's safe for another subscriber to change & use it.
	assert(!_recycled_signals.has(signal_str), "Signal already recycled")
	var n_signals := _forward_signals.size()
	var index := 1 # skip 0th element which is always [INF]
	while index < n_signals:
		if signal_str == _forward_signals[index][2]:
			_forward_signals.remove(index)
			call_deferred("_append_recycled", signal_str)
			return
		index += 1
	assert(false, "Attept to recycle non-active signal")

func project_init():
	_timekeeper = Global.program.Timekeeper
	_timekeeper.connect("processed", self, "_timekeeper_process")
	_timekeeper.connect("speed_changed", self, "_on_speed_changed")

func _on_speed_changed(_speed_index: int, is_reversed: bool, _is_paused: bool,
		_show_clock: bool, _show_seconds: bool, _is_real_world_time: bool) -> void:
	_is_reversed = is_reversed

func _timekeeper_process(sim_time: float, _engine_delta: float) -> void:
	while sim_time > _forward_signals[-1][0]: # fast negative result!
		var signal_info: Array = _forward_signals.pop_back()
		var signal_str: String = signal_info[2]
		var one_time: bool = signal_info[3]
		if one_time:
			call_deferred("_append_recycled", signal_str)
		else:
			var signal_time: float = signal_info[0]
			var interval: float = signal_info[1]
			signal_time += interval
			if signal_time < sim_time:
				signal_time = sim_time # will signal next frame
			signal_info[0] = signal_time
			# high frequency will be near end, reducing insert cost
			var index := _forward_signals.bsearch_custom(signal_time, self, "_order")
			_forward_signals.insert(index, signal_info)
		emit_signal(signal_str)

func _append_recycled(signal_str: String) -> void:
	_recycled_signals.append(signal_str)

func _order(signal_info: Array, signal_time: float) -> bool:
	return signal_info[0] > signal_time # smallest signal_time will be last
