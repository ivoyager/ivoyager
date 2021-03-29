# table_reader.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield
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

var _table_data: Dictionary # arrays of arrays by "moons", "planets", etc.
var _table_fields: Dictionary # a dict of columns for each table
var _table_data_types: Dictionary # an array for each table
var _table_units: Dictionary # an array for each table
var _table_row_dicts: Dictionary
var _table_rows: Dictionary = Global.table_rows # indexed by ALL table rows
var _bodies_by_name: Dictionary = Global.bodies_by_name
var _enums: Script
var _unit_multipliers: Dictionary
var _unit_functions: Dictionary


func get_n_rows(table_name: String) -> int:
	var data: Array = _table_data[table_name]
	return data.size()

func get_row_name(table_name: String, row: int) -> String:
	var row_data: Array = _table_data[table_name][row]
	return row_data[0]

func get_row(table_name: String, row_name: String) -> int:
	# Returns -1 if missing.
	# Since all table row names are checked to be globaly unique, you can
	# obtain the same result using Global.table_rows[row_name]. 
	var table_rows: Dictionary = _table_row_dicts[table_name]
	if table_rows.has(row_name):
		return table_rows[row_name]
	return -1

func get_rows_dict(table_name: String) -> Dictionary:
	# Returns an enum-like dict of row number keyed by row names. Don't modify!
	return _table_row_dicts[table_name]

func has_row_name(table_name: String, row_name: String) -> bool:
	var table_rows: Dictionary = _table_row_dicts[table_name]
	return table_rows.has(row_name)

func has_value(table_name: String, field_name: String, row := -1, row_name := "") -> bool:
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var column_fields: Dictionary = _table_fields[table_name]
	if !column_fields.has(field_name):
		return false
	if row_name:
		row = _table_rows[row_name]
	var data: Array = _table_data[table_name]
	var row_data: Array = data[row]
	var column = column_fields[field_name]
	return bool(row_data[column])

func get_string(table_name: String, field_name: String, row := -1, row_name := "") -> String:
	# Use for STRING or to obtain a "raw", unconverted table value.
	# Returns "" if missing.
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var column_fields: Dictionary = _table_fields[table_name]
	if !column_fields.has(field_name):
		return ""
	if row_name:
		row = _table_rows[row_name]
	var data: Array = _table_data[table_name]
	var row_data: Array = data[row]
	var column = column_fields[field_name]
	return row_data[column]

func get_bool(table_name: String, field_name: String, row := -1, row_name := "") -> bool:
	# Use for table DataType "BOOL" or "X"; returns false if missing
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var column_fields: Dictionary = _table_fields[table_name]
	if !column_fields.has(field_name):
		return false
	if row_name:
		row = _table_rows[row_name]
	var data: Array = _table_data[table_name]
	var row_data: Array = data[row]
	var column = column_fields[field_name]
	return bool(row_data[column])

func get_int(table_name: String, field_name: String, row := -1, row_name := "") -> int:
	# Returns -1 if missing.
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var column_fields: Dictionary = _table_fields[table_name]
	if !column_fields.has(field_name):
		return -1
	if row_name:
		row = _table_rows[row_name]
	var data: Array = _table_data[table_name]
	var row_data: Array = data[row]
	var column = column_fields[field_name]
	return convert_int(row_data[column])

func get_real(table_name: String, field_name: String, row := -1, row_name := "") -> float:
	# Returns NAN if missing.
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var column_fields: Dictionary = _table_fields[table_name]
	if !column_fields.has(field_name):
		return NAN
	if row_name:
		row = _table_rows[row_name]
	var data: Array = _table_data[table_name]
	var row_data: Array = data[row]
	var column = column_fields[field_name]
	var units: Array = _table_units[table_name]
	var unit: String = units[column]
	return convert_real(row_data[column], unit)

func get_real_precision(table_name: String, field_name: String, row := -1, row_name := "") -> int:
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var real_str := get_string(table_name, field_name, row, row_name)
	if !real_str:
		return -1 # missing value
	return get_real_str_precision(real_str)
	
func get_least_real_precision(table_name: String, field_names: Array, row := -1, row_name := "") -> int:
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var min_precision := 9999
	for field_name in field_names:
		var real_str := get_string(table_name, field_name, row, row_name)
		if !real_str:
			return -1 # missing value
		var precission := get_real_str_precision(real_str)
		if min_precision > precission:
			min_precision = precission
	return min_precision

func get_body(table_name: String, field_name: String, row := -1, row_name := "") -> Body:
	# Use for DataType = "BODY" to get the Body instance.
	# Returns null if missing (from table) or no such Body exists in the tree.
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var column_fields: Dictionary = _table_fields[table_name]
	if !column_fields.has(field_name):
		return null
	if row_name:
		row = _table_rows[row_name]
	var data: Array = _table_data[table_name]
	var row_data: Array = data[row]
	var column = column_fields[field_name]
	return convert_body(row_data[column])

func get_data(table_name: String, field_name: String, row := -1, row_name := "") -> int:
	# Use for DataType = "DATA" to get row number of the cell item.
	# Returns -1 if missing.
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var column_fields: Dictionary = _table_fields[table_name]
	if !column_fields.has(field_name):
		return -1
	if row_name:
		row = _table_rows[row_name]
	var data: Array = _table_data[table_name]
	var row_data: Array = data[row]
	var column = column_fields[field_name]
	return convert_data(row_data[column])

func get_enum(table_name: String, field_name: String, row := -1, row_name := "") -> int:
	# Returns -1 if missing.
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var column_fields: Dictionary = _table_fields[table_name]
	if !column_fields.has(field_name):
		return -1
	if row_name:
		row = _table_rows[row_name]
	var data: Array = _table_data[table_name]
	var row_data: Array = data[row]
	var column = column_fields[field_name]
	var data_types: Array = _table_data_types[table_name]
	var enum_name: String = data_types[column]
	return convert_enum(row_data[column], enum_name)

func build_dictionary_from_keys(dict: Dictionary, table_name: String, row: int) -> void:
	# Sets dict value for each dict key that exactly matches a column field
	# in table. Missing value in table without default will not be set.
	var column_fields: Dictionary = _table_fields[table_name]
	var data_types: Array = _table_data_types[table_name]
	var units: Array = _table_units[table_name]
	var row_data: Array = _table_data[table_name][row]
	for column_field in dict:
		var column: int = column_fields.get(column_field, -1)
		if column == -1:
			continue
		var value: String = row_data[column]
		if !value:
			continue
		var data_type: String = data_types[column]
		var unit: String = units[column]
		dict[column_field] = convert_value(value, data_type, unit)

func build_dictionary(dict: Dictionary, fields: Array, table_name: String, row: int) -> void:
	# Sets dict value for each fields that exactly matches a column field in
	# table. Missing value in table without default will not be set.
	var column_fields: Dictionary = _table_fields[table_name]
	var data_types: Array = _table_data_types[table_name]
	var units: Array = _table_units[table_name]
	var row_data: Array = _table_data[table_name][row]
	for column_field in fields:
		var column: int = column_fields.get(column_field, -1)
		if column == -1:
			continue
		var value: String = row_data[column]
		if !value:
			continue
		var data_type: String = data_types[column]
		var unit: String = units[column]
		dict[column_field] = convert_value(value, data_type, unit)

func build_object(object: Object, fields: Array, table_name: String, row: int) -> void:
	# Sets object property for each fields that exactly matches a column field
	# in table. Missing value in table without default will not be set.
	var column_fields: Dictionary = _table_fields[table_name]
	var data_types: Array = _table_data_types[table_name]
	var units: Array = _table_units[table_name]
	var row_data: Array = _table_data[table_name][row]
	for column_field in fields:
		var column: int = column_fields.get(column_field, -1)
		if column == -1:
			continue
		var value: String = row_data[column]
		if !value:
			continue
		var data_type: String = data_types[column]
		var unit: String = units[column]
		object[column_field] = convert_value(value, data_type, unit)

func build_flags(flags: int, flag_fields: Dictionary, table_name: String, row: int) -> int:
	# Sets flag if table value exists and would evaluate true in get_bool(),
	# i.e., is true or x. Does not unset.
	var column_fields: Dictionary = _table_fields[table_name]
	var data_types: Array = _table_data_types[table_name]
	var row_data: Array = _table_data[table_name][row]
	for flag in flag_fields:
		var column_field: String = flag_fields[flag]
		if !column_fields.has(column_field):
			continue
		var column: int = column_fields[column_field]
		var value: String = row_data[column]
		var data_type: String = data_types[column]
		assert(data_type == "BOOL" or data_type == "X", "Expected table DataType = 'BOOL' or 'X'")
		if bool(value):
			flags |= flag
	return flags

func get_real_precisions(fields: Array, table_name: String, row: int) -> Array:
	# Return array is same size as fields. Missing and non-REALs are -1.
	var result := []
	var column_fields: Dictionary = _table_fields[table_name]
	var data_types: Array = _table_data_types[table_name]
	var row_data: Array = _table_data[table_name][row]
	for column_field in fields:
		var column: int = column_fields.get(column_field, -1)
		if column == -1:
			result.append(-1)
			continue
		var value: String = row_data[column]
		if !value:
			result.append(-1)
			continue
		var data_type: String = data_types[column]
		if data_type != "REAL":
			result.append(-1)
			continue
		var precision := get_real_str_precision(value)
		result.append(precision)
	return result

func get_real_str_precision(real_str: String) -> int:
	# See table REAL format rules in solar_system/planets.tsv.
	# TableImporter has stripped leading "_" and converted "E" to "e".
	# We ignore leading zeroes before the decimal place.
	# We count trailing zeroes IF there is a decimal place.
	if real_str == "?":
		return -1
	if real_str.begins_with("~"):
		return 0
	var length := real_str.length()
	var n_digits := 0
	var started := false
	var n_unsig_zeros := 0
	var deduct_zeroes := true
	var i := 0
	while i < length:
		var chr: String = real_str[i]
		if chr == ".":
			started = true
			deduct_zeroes = false
		elif chr == "e":
			break
		elif chr == "0":
			if started:
				n_digits += 1
				if deduct_zeroes:
					n_unsig_zeros += 1
		elif chr != "-":
			assert(chr.is_valid_integer(), "Unknown REAL character: " + chr)
			started = true
			n_digits += 1
			n_unsig_zeros = 0
		i += 1
	if deduct_zeroes:
		n_digits -= n_unsig_zeros
	return n_digits

func convert_value(value: String, data_type: String, unit := ""): # untyped return
	match data_type:
		"REAL":
			return convert_real(value, unit)
		"BOOL":
			return bool(value) # False is internally ""
		"STRING":
			return value
		"INT":
			return convert_int(value)
		"DATA":
			return convert_data(value)
		"BODY":
			return convert_body(value)
		_: # must be valid enum name (this was verified on import)
			return convert_enum(value, data_type)

func convert_int(value: String) -> int:
	return int(value) if value else -1

func convert_real(value: String, unit := "") -> float:
	if !value:
		return NAN
	if value == "?":
		return INF
	value = value.lstrip("~")
	var real := float(value)
	if unit:
		real = unit_defs.conv(real, unit, false, true, _unit_multipliers, _unit_functions)
	return float(real)

func convert_data(value: String) -> int:
	if !value:
		return -1
	assert(_table_rows.has(value), "Unknown table row name " + value)
	return _table_rows[value]

func convert_body(value: String) -> Body:
	if !value:
		return null
	return _bodies_by_name.get(value)

func convert_enum(value: String, enum_name: String) -> int:
	if !value:
		return -1
	var dict: Dictionary = _enums[enum_name]
	return dict[value]

# *****************************************************************************
# init

func init_tables(table_data: Dictionary, table_fields: Dictionary, table_data_types: Dictionary,
		table_units: Dictionary, table_row_dicts: Dictionary) -> void:
	_table_data = table_data
	_table_fields = table_fields
	_table_data_types = table_data_types
	_table_units = table_units
	_table_row_dicts = table_row_dicts

func _project_init() -> void:
	_enums = Global.enums
	_unit_multipliers = Global.unit_multipliers
	_unit_functions = Global.unit_functions
