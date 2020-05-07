# table_reader.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
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
# For get functions, table_name is "planets", "moons", etc. Supply either row
# or row_name.

class_name TableReader

const unit_defs := preload("res://ivoyager/static/unit_defs.gd")
const math := preload("res://ivoyager/static/math.gd")

var _values: Array
var _table_data: Dictionary # arrays of arrays by "moons", "planets", etc.
var _table_fields: Dictionary # a dict of columns for each table
var _table_data_types: Dictionary # an array for each table
var _table_units: Dictionary # an array for each table
var _table_rows: Dictionary = Global.table_rows
var _table_row_dicts: Dictionary = Global.table_row_dicts
var _bodies_by_name: Dictionary = Global.bodies_by_name
var _enums: Script
var _unit_multipliers: Dictionary
var _unit_functions: Dictionary


func project_init() -> void:
	_enums = Global.enums
	_unit_multipliers = Global.unit_multipliers
	_unit_functions = Global.unit_functions

func init_tables(table_data: Dictionary, table_fields: Dictionary, table_data_types: Dictionary,
		table_units: Dictionary, values: Array) -> void:
	_table_data = table_data
	_table_fields = table_fields
	_table_data_types = table_data_types
	_table_units = table_units
	_values = values

func get_n_table_rows(table_name: String) -> int:
	var data: Array = _table_data[table_name]
	return data.size()

func get_row_key(table_name: String, row: int) -> String:
	var row_data: Array = _table_data[table_name][row]
	return _values[row_data[0]]

func is_value(table_name: String, field_name: String, row := -1, row_name := "") -> bool:
	# use for STRING or to get unconverted table value; returns "" if missing
	assert((row == -1) != (row_name == ""))
	var fields: Dictionary = _table_fields[table_name]
	if !fields.has(field_name):
		return false
	if row_name:
		row = _table_rows[row_name]
	var data: Array = _table_data[table_name]
	var row_data: Array = data[row]
	var column = fields[field_name]
	return bool(_values[row_data[column]])

func get_string(table_name: String, field_name: String, row := -1, row_name := "") -> String:
	# use for STRING or to get unconverted table value; returns "" if missing
	assert((row == -1) != (row_name == ""))
	var fields: Dictionary = _table_fields[table_name]
	if !fields.has(field_name):
		return ""
	if row_name:
		row = _table_rows[row_name]
	var data: Array = _table_data[table_name]
	var row_data: Array = data[row]
	var column = fields[field_name]
	return _values[row_data[column]]

func get_bool(table_name: String, field_name: String, row := -1, row_name := "") -> bool:
	# use for table DataType "BOOL" or "X"; returns false if missing
	assert((row == -1) != (row_name == ""))
	var fields: Dictionary = _table_fields[table_name]
	if !fields.has(field_name):
		return false
	if row_name:
		row = _table_rows[row_name]
	var data: Array = _table_data[table_name]
	var row_data: Array = data[row]
	var column = fields[field_name]
	return conv_bool(_values[row_data[column]])

func get_int(table_name: String, field_name: String, row := -1, row_name := "") -> int:
	# returns -1 if missing
	assert((row == -1) != (row_name == ""))
	var fields: Dictionary = _table_fields[table_name]
	if !fields.has(field_name):
		return -1
	if row_name:
		row = _table_rows[row_name]
	var data: Array = _table_data[table_name]
	var row_data: Array = data[row]
	var column = fields[field_name]
	return conv_int(_values[row_data[column]])

func get_real(table_name: String, field_name: String, row := -1, row_name := "") -> float:
	# returns -INF if missing
	assert((row == -1) != (row_name == ""))
	var fields: Dictionary = _table_fields[table_name]
	if !fields.has(field_name):
		return -INF
	if row_name:
		row = _table_rows[row_name]
	var data: Array = _table_data[table_name]
	var row_data: Array = data[row]
	var column = fields[field_name]
	var units: Array = _table_units[table_name]
	var unit: String = units[column]
	return conv_real(_values[row_data[column]], unit)

func get_real_precision(table_name: String, field_name: String, row := -1, row_name := "") -> int:
	var num_str := get_string(table_name, field_name, row, row_name)
	if !num_str:
		return 0 # missing value
	return math.get_str_decimal_precision(num_str)
	
func get_least_real_precision(table_name: String, field_names: Array, row := -1, row_name := "") -> int:
	var num_strs := []
	for field_name in field_names:
		var num_str := get_string(table_name, field_name, row, row_name)
		if !num_str:
			return 0 # missing value
		num_strs.append(num_str)
	return math.get_least_str_decimal_precision(num_strs)

func get_enum(table_name: String, field_name: String, row := -1, row_name := "") -> int:
	# returns -1 if missing
	assert((row == -1) != (row_name == ""))
	var fields: Dictionary = _table_fields[table_name]
	if !fields.has(field_name):
		return -1
	if row_name:
		row = _table_rows[row_name]
	var data: Array = _table_data[table_name]
	var row_data: Array = data[row]
	var column = fields[field_name]
	var data_types: Array = _table_data_types[table_name]
	var enum_name: String = data_types[column]
	return conv_enum(_values[row_data[column]], enum_name)

func get_table_type(table_name: String, field_name: String, row := -1, row_name := "") -> int:
	# Use for DataType = "DATA" to get row number (= "type") of the cell item.
	# Returns -1 if missing!
	assert((row == -1) != (row_name == ""))
	var fields: Dictionary = _table_fields[table_name]
	if !fields.has(field_name):
		return -1
	if row_name:
		row = _table_rows[row_name]
	var data: Array = _table_data[table_name]
	var row_data: Array = data[row]
	var column = fields[field_name]
	return conv_data(_values[row_data[column]])

func get_body(table_name: String, field_name: String, row := -1, row_name := "") -> Body:
	# Use for DataType = "BODY" to get the Body instance.
	# Returns null if missing!
	assert((row == -1) != (row_name == ""))
	var fields: Dictionary = _table_fields[table_name]
	if !fields.has(field_name):
		return null
	if row_name:
		row = _table_rows[row_name]
	var data: Array = _table_data[table_name]
	var row_data: Array = data[row]
	var column = fields[field_name]
	return conv_body(_values[row_data[column]])

func build_object(object: Object, table_name: String, table_row: int, property_fields: Dictionary,
		required_fields := []) -> void:
	var fields: Dictionary = _table_fields[table_name]
	var data_types: Array = _table_data_types[table_name]
	var units: Array = _table_units[table_name]
	var row_data: Array = _table_data[table_name][table_row]
	for property in property_fields:
		var field: String = property_fields[property]
		if !fields.has(field):
			assert(!required_fields.has(field), "Missing table column: " + _values[row_data[0]] + " " + field)
			continue
		var column: int = fields[field]
		var value_index: int = row_data[column]
		var value: String = _values[value_index]
		if !value:
			assert(!required_fields.has(field), "Missing table value: " + _values[row_data[0]] + " " + field)
			continue
		var data_type: String = data_types[column]
		var unit: String = units[column]
		object[property] = conv_value(value, data_type, unit)

func build_dictionary(dict: Dictionary, table_name: String, table_row: int, property_fields: Dictionary,
		required_fields := []) -> void:
	var fields: Dictionary = _table_fields[table_name]
	var data_types: Array = _table_data_types[table_name]
	var units: Array = _table_units[table_name]
	var row_data: Array = _table_data[table_name][table_row]
	for property in property_fields:
		var field: String = property_fields[property]
		if !fields.has(field):
			assert(!required_fields.has(field), "Missing table column: " + _values[row_data[0]] + " " + field)
			continue
		var column: int = fields[field]
		var value_index: int = row_data[column]
		var value: String = _values[value_index]
		if !value:
			assert(!required_fields.has(field), "Missing table value: " + _values[row_data[0]] + " " + field)
			continue
		var data_type: String = data_types[column]
		var unit: String = units[column]
		dict[property] = conv_value(value, data_type, unit)

func build_flags(flags: int, table_name: String, table_row: int, flag_fields: Dictionary,
		required_fields := []) -> int:
	# Assumes relevant flag already in off state; only sets for TRUE or x values in table.
	var fields: Dictionary = _table_fields[table_name]
	var data_types: Array = _table_data_types[table_name]
	var row_data: Array = _table_data[table_name][table_row]
	for flag in flag_fields:
		var field: String = flag_fields[flag]
		if !fields.has(field):
			assert(!required_fields.has(field), "Missing table column: " + _values[row_data[0]] + " " + field)
			continue
		var column: int = fields[field]
		var value_index: int = row_data[column]
		var value: String = _values[value_index]
		var data_type: String = data_types[column]
		assert(data_type == "BOOL" or data_type == "X", "Expected table DataType = 'BOOL' or 'X'")
		if conv_bool(value):
			flags |= flag
	return flags

func conv_value(value: String, data_type: String, unit := ""):
	# untyped return
	match data_type:
		"REAL":
			return conv_real(value, unit)
		"BOOL", "X":
			return conv_bool(value)
		"STRING":
			return value
		"INT":
			return conv_int(value)
		"DATA":
			return conv_data(value)
		"BODY":
			return conv_body(value)
		_: # valid enum name (tested on import)
			return conv_enum(value, data_type)

func conv_bool(value: String) -> bool:
	# for "BOOL" or "X"
	return value == "x" or value.matchn("true")

func conv_int(value: String) -> int:
	if !value:
		return -1
	return int(value)

func conv_real(value: String, unit := "") -> float:
	if !value:
		return -INF
	var real := float(value)
	if unit:
		var sig_digits := math.get_str_decimal_precision(value)
		real = unit_defs.conv(real, unit, false, true, _unit_multipliers, _unit_functions)
		real = math.set_decimal_precision(real, sig_digits)
	return float(real)

func conv_data(value: String) -> int:
	if !value:
		return -1
	assert(_table_rows.has(value), "Unknown table row key " + value)
	return _table_rows[value]

func conv_body(value: String) -> Body:
	if !value:
		return null
	return _bodies_by_name.get(value)

func conv_enum(value: String, enum_name: String) -> int:
	if !value:
		return -1
	var dict: Dictionary = _enums[enum_name]
	return dict[value]
