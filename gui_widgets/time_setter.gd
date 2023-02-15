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

# GUI widget. For usage in a setter popup, see gui_widgets/time_set_popup.tscn.

onready var _timekeeper: IVTimekeeper = IVGlobal.program.Timekeeper


func _ready() -> void:
	$Set.connect("pressed", self, "_on_set")
	$Year.connect("value_changed", self, "_on_date_changed")
	$Month.connect("value_changed", self, "_on_date_changed")
	$Day.connect("value_changed", self, "_on_date_changed")


func set_current() -> void:
	var date_time := _timekeeper.get_gregorian_date_time()
	var date_array: Array = date_time[0]
	var time_array: Array = date_time[1]
	$Year.value = date_array[0]
	$Month.value = date_array[1]
	$Day.value = date_array[2]
	$Hour.value = time_array[0]
	$Minute.value = time_array[1]
	$Second.value = time_array[2]


func _on_set() -> void:
	var year := int($Year.value)
	var month := int($Month.value)
	var day := int($Day.value)
	var hour := int($Hour.value)
	var minute := int($Minute.value)
	var second := int($Second.value)
	var new_time := _timekeeper.get_sim_time(year, month, day, hour, minute, second)
	_timekeeper.set_time(new_time)


func _on_date_changed(_value: float) -> void:
	var day := int($Day.value)
	if day < 29:
		return
	var year := int($Year.value)
	var month := int($Month.value)
	if !_timekeeper.is_valid_gregorian_date(year, month, day):
		$Day.value = day - 1
