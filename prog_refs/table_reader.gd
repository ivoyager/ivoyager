# table_reader.gd
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
class_name IVTableReader

# You can access data directly from IVGlobal dictionaries using indexing:
#
#    tables[table_name][column_field][row_name or row_int] -> typed_value
#    table_rows[row_name] -> row_int (row_name's are globally unique)
#    table_types[table_name][column_field] -> Type string in table
#    table_precisions[][][] indexed as tables but only REAL fields -> sig digits
#
# API here provides protections for missing fields/values and constructor
# methods.

const units := preload("res://ivoyager/static/units.gd")
const utils := preload("res://ivoyager/static/utils.gd")
const math := preload("res://ivoyager/static/math.gd")

var _tables: Dictionary = IVGlobal.tables # indexed [table][field][row_name or _int]
var _table_rows: Dictionary = IVGlobal.table_rows # indexed by ALL table row names
var _table_types: Dictionary = IVGlobal.table_types # indexed [table][field]
var _table_precisions: Dictionary = IVGlobal.table_precisions # as _tables for REAL fields
var _enums: Script = IVGlobal.enums


# *****************************************************************************
# init

func _project_init() -> void:
	pass


# *****************************************************************************
# public functions
# For get functions, table is "planets", "moons", etc. Most get functions
# will take either row or row_name.


func get_n_rows(table: String) -> int:
	return _tables[table].n_rows


func get_row_name(table: String, row: int) -> String:
	return _tables[table]["name"][row]


func get_row(row_name: String) -> int:
	# Returns -1 if missing.
	return _table_rows.get(row_name, -1)


func get_names_dict(table: String) -> Dictionary:
	# Returns an enum-like dict of row number keyed by row names.
	var dict := {}
	for key in _tables[table]["name"]:
		if typeof(key) == TYPE_STRING:
			dict[key] = _table_rows[key]
	return dict


func get_column_array(table: String, field: String) -> Array:
	# field must exist in specified table
	var array := []
	var n_rows: int = _tables[table].n_rows
	array.resize(n_rows)
	var field_dict: Dictionary = _tables[table][field]
	var i := 0
	while i < n_rows:
		array[i] = field_dict[i]
		i += 1
	return array


func get_n_matching(table: String, field: String, match_value) -> int:
	# field must exist in specified table
	# match_value type must mach column type
	var count := 0
	var n_rows: int = _tables[table].n_rows
	var field_dict: Dictionary = _tables[table][field]
	var i := 0
	while i < n_rows:
		if field_dict[i] == match_value:
			count += 1
		i += 1
	return count


func get_matching_rows(table: String, field: String, match_value) -> Array:
	# field must exist in specified table
	# match_value type must mach column type
	var array := []
	var n_rows: int = _tables[table].n_rows
	var field_dict: Dictionary = _tables[table][field]
	var i := 0
	while i < n_rows:
		if field_dict[i] == match_value:
			array.append(i)
		i += 1
	return array


func get_true_rows(table: String, field: String) -> Array:
	# field must exist in specified table
	var array := []
	var n_rows: int = _tables[table].n_rows
	var field_dict: Dictionary = _tables[table][field]
	var i := 0
	while i < n_rows:
		if field_dict[i]:
			array.append(i)
		i += 1
	return array


func has_row_name(table: String, row_name: String) -> bool:
	return _tables[table].has("name") and _tables[table]["name"].has(row_name)


func has_value(table: String, field: String, row := -1, row_name := "") -> bool:
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	if !_tables[table].has(field):
		return false
	if row_name:
		row = _table_rows[row_name]
	var type: String = _table_types[table][field]
	match type:
		"X", "BOOL":
			return true
		"STRING":
			return _tables[table][field][row] != ""
		"REAL":
			return !is_nan(_tables[table][field][row])
		_: # INT, TABLE_ROW or enum name
			return _tables[table][field][row] != -1


func has_real_value(table: String, field: String, row := -1, row_name := "") -> bool:
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	if !_tables[table].has(field):
		return false
	if row_name:
		row = _table_rows[row_name]
	return !is_nan(_tables[table][field][row])


func get_string(table: String, field: String, row := -1, row_name := "") -> String:
	# Use for table Type STRING; returns "" if missing
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	if !_tables[table].has(field):
		return ""
	if row_name:
		row = _table_rows[row_name]
	return _tables[table][field][row]


func get_bool(table: String, field: String, row := -1, row_name := "") -> bool:
	# Use for table Type "BOOL" or "X"; returns false if missing
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	if !_tables[table].has(field):
		return false
	if row_name:
		row = _table_rows[row_name]
	return _tables[table][field][row]


func get_int(table: String, field: String, row := -1, row_name := "") -> int:
	# Returns -1 if missing
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	if !_tables[table].has(field):
		return -1
	if row_name:
		row = _table_rows[row_name]
	return _tables[table][field][row]


func get_real(table: String, field: String, row := -1, row_name := "") -> float:
	# Returns NAN if missing
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	if !_tables[table].has(field):
		return NAN
	if row_name:
		row = _table_rows[row_name]
	return _tables[table][field][row]


func get_real_precision(table: String, field: String, row := -1, row_name := "") -> int:
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	if row_name:
		row = _table_rows[row_name]
	return _table_precisions[table][field][row]


func get_least_real_precision(table: String, fields: Array, row := -1, row_name := "") -> int:
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	if row_name:
		row = _table_rows[row_name]
	var min_precision := 9999
	for field in fields:
		var precission: int = _table_precisions[table][field][row]
		if min_precision > precission:
			min_precision = precission
	return min_precision


func get_table_row(table: String, field: String, row := -1, row_name := "") -> int:
	# Use for Type = "TABLE_ROW" to get row number of the cell item.
	# Returns -1 if missing.
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	if !_tables[table].has(field):
		return -1
	if row_name:
		row = _table_rows[row_name]
	return _tables[table][field][row]


func get_enum(table: String, field: String, row := -1, row_name := "") -> int:
	# Returns -1 if missing.
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	if !_tables[table].has(field):
		return -1
	if row_name:
		row = _table_rows[row_name]
	return _tables[table][field][row]


func build_dictionary_from_keys(dict: Dictionary, table: String, row: int) -> void:
	# Sets dict value for each dict key that exactly matches a column field
	# in table. Missing value in table without default will not be set.
	for field in dict:
		if has_value(table, field, row):
			dict[field] = _tables[table][field][row]


func get_data(fields: Array, table: String, row: int) -> Array:
	# Sets array value for each field that exactly matches a field in
	# table. Missing value in table without default will not be set.
	var n_fields := fields.size()
	var data := []
	data.resize(n_fields)
	var i := 0
	while i < n_fields:
		var field: String = fields[i]
		if has_value(table, field, row):
			data[i] = _tables[table][field][row]
		i += 1
	return data


func build_dictionary(dict: Dictionary, fields: Array, table: String, row: int) -> void:
	# Sets dict value for each field that exactly matches a field in
	# table. Missing value in table without default will not be set.
	var n_fields := fields.size()
	var i := 0
	while i < n_fields:
		var field: String = fields[i]
		if has_value(table, field, row):
			dict[field] = _tables[table][field][row]
		i += 1


func build_object(object: Object, fields: Array, table: String, row: int) -> void:
	# Sets object property for each field that exactly matches a field
	# in table. Missing value in table without default will not be set.
	var n_fields := fields.size()
	var i := 0
	while i < n_fields:
		var field: String = fields[i]
		if has_value(table, field, row):
			object.set(field, _tables[table][field][row])
		i += 1


func build_flags(flags: int, flag_fields: Dictionary, table: String, row: int) -> int:
	# Sets flag if table value exists and would evaluate true in get_bool(),
	# i.e., is true or x. Does not unset.
	for flag in flag_fields:
		var field: String = flag_fields[flag]
		if get_bool(table, field, row):
			flags |= flag
	return flags


func get_real_precisions(fields: Array, table: String, row: int) -> Array:
	# Missing or non-REAL values will have precision -1.
	var n_fields := fields.size()
	var data := utils.init_array(n_fields, -1)
	var i := 0
	while i < n_fields:
		var field: String = fields[i]
		if _table_types[table].has(field):
			var type: String = _table_types[table][field]
			if type == "REAL":
				data[i] = _table_precisions[table][field][row]
		i += 1
	return data
