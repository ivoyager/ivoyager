# table_helper.gd
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

class_name TableHelper

var _table_data: Dictionary = Global.table_data
var _table_fields: Dictionary = Global.table_fields
var _table_rows: Dictionary = Global.table_rows
var _bodies_by_name: Dictionary = Global.bodies_by_name
var _enums: Script


func project_init() -> void:
	_enums = Global.enums

func get_value(table_name: String, field_name: String, row := -1, row_name := ""):
	# Returns null if missing or field doesn't exist in table.
	# Otherwise, return type depends on table DataType:
	#   "BOOL" or "X" -> bool
	#   "INT" or any enum name -> int
	#   "REAL" -> float
	#   all others -> String (see functions below for "DATA", "BODY")
	assert((row == -1) != (row_name == ""))
	var fields: Dictionary = _table_fields[table_name]
	if !fields.has(field_name):
		return null
	if row_name:
		row = _table_rows[row_name]
	var data: Array = _table_data[table_name]
	var row_data: Array = data[row]
	var column = fields[field_name]
	return row_data[column]

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
	if row_data[column] == null:
		return -1
	var table_type: String = row_data[column]
	return _table_rows[table_type]

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
	if row_data[column] == null:
		return null
	var body_key: String = row_data[column]
	return _bodies_by_name[body_key]

func build_object(object: Object, row_data: Array, fields: Dictionary, data_types: Array,
		property_fields: Dictionary, required_fields := []) -> void:
	# This function helps a builder class build an object from table row data.
	for property in property_fields:
		var field: String = property_fields[property]
		if !fields.has(field):
			assert(!required_fields.has(field), "Missing table column: " + row_data[0] + " " + field)
			continue
		var column: int = fields[field]
		var value = row_data[column]
		if value == null:
			assert(!required_fields.has(field), "Missing table value: " + row_data[0] + " " + field)
			continue
		var data_type: String = data_types[column]
		match data_type:
			"DATA":
				object[property] = _table_rows[value]
			"BODY":
				object[property] = _bodies_by_name[value]
			_:
				object[property] = value

func build_dictionary(dict: Dictionary, row_data: Array, fields: Dictionary, data_types: Array,
		property_fields: Dictionary, required_fields := []) -> void:
	# This function helps a builder class build a dict from table row data.
	for property in property_fields:
		var field: String = property_fields[property]
		if !fields.has(field):
			assert(!required_fields.has(field), "Missing table column: " + row_data[0] + " " + field)
			continue
		var column: int = fields[field]
		var value = row_data[column]
		if value == null:
			assert(!required_fields.has(field), "Missing table value: " + row_data[0] + " " + field)
			continue
		var data_type: String = data_types[column]
		match data_type:
			"DATA":
				dict[property] = _table_rows[value]
			"BODY":
				dict[property] = _bodies_by_name[value]
			_:
				dict[property] = value

func build_flags(flags: int, row_data: Array, fields: Dictionary, flag_fields: Dictionary,
		required_fields := []) -> int:
	# Assumes relevant flag already in off state; only sets for TRUE or x values in table.
	for flag in flag_fields:
		var field: String = flag_fields[flag]
		if !fields.has(field):
			assert(!required_fields.has(field), "Missing table column: " + row_data[0] + " " + field)
			continue
		var column: int = fields[field]
		var value = row_data[column]
		if value == null:
			assert(!required_fields.has(field), "Missing table value: " + row_data[0] + " " + field)
			continue
		assert(typeof(value) == TYPE_BOOL, "Expected table DataType = 'BOOL' or 'X'") # 
		if value:
			flags |= flag
	return flags
