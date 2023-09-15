# time_setter.gd
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
class_name IVTimeSetter
extends HBoxContainer

# GUI widget. Requires IVTimekeeper.
#
# For usage in a setter popup, see IVTimeSetPopup.

signal time_set(is_close)


@onready var _year: SpinBox = $Year
@onready var _month: SpinBox = $Month
@onready var _day: SpinBox = $Day
@onready var _hour: SpinBox = $Hour
@onready var _minute: SpinBox = $Minute
@onready var _second: SpinBox = $Second

@onready var _timekeeper: IVTimekeeper = IVGlobal.program[&"Timekeeper"]


func _ready() -> void:
	($Set as Button).pressed.connect(_on_set.bind(false))
	($SetAndClose as Button).pressed.connect(_on_set.bind(true))
	_year.value_changed.connect(_on_date_changed)
	_month.value_changed.connect(_on_date_changed)
	_day.value_changed.connect(_on_date_changed)


func set_current() -> void:
	var date_time := _timekeeper.get_gregorian_date_time()
	var date_array: Array[int] = date_time[0]
	var time_array: Array[int] = date_time[1]
	_year.value = date_array[0]
	_month.value = date_array[1]
	_day.value = date_array[2]
	_hour.value = time_array[0]
	_minute.value = time_array[1]
	_second.value = time_array[2]


func _on_set(is_close: bool) -> void:
	var year := int(_year.value)
	var month := int(_month.value)
	var day := int(_day.value)
	var hour := int(_hour.value)
	var minute := int(_minute.value)
	var second := int(_second.value)
	var new_time := _timekeeper.get_sim_time(year, month, day, hour, minute, second)
	_timekeeper.set_time(new_time)
	time_set.emit(is_close)


func _on_date_changed(_value: float) -> void:
	var day := int(_day.value)
	if day < 29:
		return
	var year := int(_year.value)
	var month := int(_month.value)
	if !_timekeeper.is_valid_gregorian_date(year, month, day):
		_day.value = day - 1

