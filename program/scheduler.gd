# scheduler.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2023 Charlie Whitfield
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
class_name IVScheduler
extends Node

# Creates interval signals using simulation time. Max signal frequency will be
# once per frame if interval is very small and/or game speed is very fast.
# There is no save/load persistence! Interval connections must be remade.

var _times: Array = IVGlobal.times
var _ordered_signal_infos := [] # array "top" is always the next signal
var _counter := 0
var _signal_intervals := []
var _available_signals := []
var _is_reversed := false

@onready var _timekeeper: IVTimekeeper = IVGlobal.program.Timekeeper


# *****************************************************************************

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	IVGlobal.connect("about_to_free_procedural_nodes", Callable(self, "_clear"))
	_timekeeper.connect("time_altered", Callable(self, "_on_time_altered"))
	if IVGlobal.allow_time_reversal:
		_timekeeper.connect("speed_changed", Callable(self, "_update_for_time_reversal"))


func _clear() -> void:
	_ordered_signal_infos.clear()
	_signal_intervals.clear()
	_available_signals.clear()
	var i := 0
	while i < _counter:
		var signal_str := str(i)
		_signal_intervals.append(0.0)
		_available_signals.append(signal_str)
		var connection_list := get_signal_connection_list(signal_str)
		if connection_list:
			assert(connection_list.size() == 1)
			var connection_dict: Dictionary = connection_list[0] # never >1
			var target: Object = connection_dict.target
			var method: String = connection_dict.method
			disconnect(signal_str, Callable(target, method))
		i += 1


# *****************************************************************************

func interval_connect(interval: float, target: Object, method: String, binds := [],
		flags := 0) -> void:
	# E.g., for 2-day repeating signal, use interval = 2.0 * IVUnits.DAY.
	# Note: IVScheduler will disconnet all interval signals on IVGlobal signal
	# "about_to_free_procedural_nodes".
	assert(interval > 0.0)
	var one_shot := bool(flags & CONNECT_ONE_SHOT)
	var signal_str := _make_interval_signal(interval, one_shot)
	connect(signal_str, Callable(target, method).bind(binds), flags)


func interval_disconnect(interval: float, target: Object, method: String) -> void:
	# Note: IVScheduler will disconnet all interval signals on IVGlobal signal
	# "about_to_free_procedural_nodes".
	var i := 0
	var signal_str := ""
	while i < _counter:
		if interval == _signal_intervals[i]:
			var test_signal_str = str(i)
			var connection_list := get_signal_connection_list(test_signal_str)
			if connection_list:
				var connection_dict: Dictionary = connection_list[0] # only one
				if target == connection_dict.target and method == connection_dict.method:
					signal_str = test_signal_str
					disconnect(signal_str, Callable(target, method))
					break
		i += 1
	if !signal_str: # doesn't exist; return w/out error
		return
	_remove_active_interval_signal(signal_str)


# *****************************************************************************

func _make_interval_signal(interval: float, one_shot := false) -> String:
	var signal_str: String
	if _available_signals:
		signal_str = _available_signals.pop_back()
		_signal_intervals[int(signal_str)] = interval
	else:
		signal_str = str(_counter)
		_signal_intervals.append(interval)
		add_user_signal(signal_str)
		_counter += 1
	var signal_time: float = _times[0]
	var index: int
	if !_is_reversed:
		signal_time += interval
		index = _ordered_signal_infos.bsearch_custom(signal_time, self, "_bsearch_forward")
	else:
		signal_time -= interval
		index = _ordered_signal_infos.bsearch_custom(signal_time, self, "_bsearch_reverse")
	var signal_info := [signal_time, interval, signal_str, one_shot]
	_ordered_signal_infos.insert(index, signal_info)
	return signal_str


func _remove_active_interval_signal(signal_str: String) -> void:
	var ordered_size := _ordered_signal_infos.size()
	var i := 0
	while i < ordered_size:
		if signal_str == _ordered_signal_infos[i][2]:
			_ordered_signal_infos.remove(i)
			_signal_intervals[i] = 0.0
			_available_signals.append(signal_str)
			return
		i += 1
	assert(false, "Attept to remove non-active signal")


func _update_for_time_reversal() -> void:
	# Connected only if IVGlobal.allow_time_reversal.
	if _is_reversed == _timekeeper.is_reversed:
		return
	_is_reversed = !_is_reversed
	var n_signals := _ordered_signal_infos.size()
	var i := 0
	while i < n_signals:
		var signal_info: Array = _ordered_signal_infos[i]
		signal_info[0] += (-signal_info[1] if _is_reversed else signal_info[1])
		i += 1
	_ordered_signal_infos.sort_custom(Callable(self, "_sort_reverse" if _is_reversed else "_sort_forward"))


func _on_time_altered(previous_time: float) -> void:
	var time_diff: float = _times[0] - previous_time
	var n_signals := _ordered_signal_infos.size()
	var i := 0
	while i < n_signals:
		var signal_info: Array = _ordered_signal_infos[i]
		signal_info[0] += time_diff
		i += 1


func _process(_delta: float) -> void:
	if !_ordered_signal_infos:
		return
	var time: float = _times[0]
	if !_is_reversed:
		while time > _ordered_signal_infos[-1][0]: # test last element
			var signal_info: Array = _ordered_signal_infos.pop_back()
			var signal_str: String = signal_info[2]
			var one_shot: bool = signal_info[3]
			if one_shot:
				_signal_intervals[int(signal_str)] = 0.0
				_available_signals.append(signal_str)
			else:
				var signal_time: float = signal_info[0]
				var interval: float = signal_info[1]
				signal_time += interval
				if signal_time < time:
					signal_time = time # will signal next frame
				signal_info[0] = signal_time
				# high frequency will be near end, reducing insert cost
				var index := _ordered_signal_infos.bsearch_custom(signal_time, self, "_bsearch_forward")
				_ordered_signal_infos.insert(index, signal_info)
			emit_signal(signal_str)
			if !_ordered_signal_infos:
				return
	else:
		while time < _ordered_signal_infos[-1][0]: # test last element
			var signal_info: Array = _ordered_signal_infos.pop_back()
			var signal_str: String = signal_info[2]
			var one_shot: bool = signal_info[3]
			if one_shot:
				_signal_intervals[int(signal_str)] = 0.0
				_available_signals.append(signal_str)
			else:
				var signal_time: float = signal_info[0]
				var interval: float = signal_info[1]
				signal_time -= interval
				if signal_time > time:
					signal_time = time # will signal next frame
				signal_info[0] = signal_time
				# high frequency will be near end, reducing insert cost
				var index := _ordered_signal_infos.bsearch_custom(signal_time, self, "_bsearch_reverse")
				_ordered_signal_infos.insert(index, signal_info)
			emit_signal(signal_str)
			if !_ordered_signal_infos:
				return


func _bsearch_forward(signal_info: Array, signal_time: float) -> bool:
	return signal_info[0] > signal_time # earliest signal_time will be on "top"


func _sort_forward(a: Array, b: Array) -> bool:
	return a[0] > b[0] # earliest signal_time will be on "top"


func _bsearch_reverse(signal_info: Array, signal_time: float) -> bool:
	return signal_info[0] < signal_time # latest signal_time will be on "top"


func _sort_reverse(a: Array, b: Array) -> bool:
	return a[0] < b[0] # latest signal_time will be on "top"
