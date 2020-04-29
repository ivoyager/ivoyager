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
# See function build_object() to efficiently build objects with many properties
# from data table rows. Use get functions to get a specific value.

class_name TableHelper

enum { # read_types for for build_object()
	AS_IS,
	AS_ENUM,
	AS_TABLE_TYPE,
	AS_BODY
}
const EMPTY_ARRAY := []
const EMPTY_DICT := {}

var _table_data: Dictionary = Global.table_data
var _table_fields: Dictionary = Global.table_fields
var _table_rows: Dictionary = Global.table_rows
var _bodies_by_name: Dictionary = Global.bodies_by_name
var _enums: Script


func project_init() -> void:
	_enums = Global.enums

func get_bool(data_name: String, field_name: String, row := -1, row_name := "") -> bool:
	# data_name is "planets", "moons", etc. Supply either row or row_name.
	# Table_Types "BOOL" and "X" are both encoded internally as bool.
	var data: Array = _table_data[data_name]
	var fields: Dictionary = _table_fields[data_name]
	if row_name:
		row = _table_rows[row_name]
	var row_data: Array = data[row]
	var column = fields[field_name]
	return row_data[column]

func get_int(data_name: String, field_name: String, row := -1, row_name := "") -> int:
	# data_name is "planets", "moons", etc. Supply either row or row_name.
	var data: Array = _table_data[data_name]
	var fields: Dictionary = _table_fields[data_name]
	if row_name:
		row = _table_rows[row_name]
	var row_data: Array = data[row]
	var column = fields[field_name]
	return row_data[column]

func get_real(data_name: String, field_name: String, row := -1, row_name := "") -> float:
	# data_name is "planets", "moons", etc. Supply either row or row_name.
	var data: Array = _table_data[data_name]
	var fields: Dictionary = _table_fields[data_name]
	if row_name:
		row = _table_rows[row_name]
	var row_data: Array = data[row]
	var column = fields[field_name]
	return row_data[column]

func get_string(data_name: String, field_name: String, row := -1, row_name := "") -> String:
	# data_name is "planets", "moons", etc. Supply either row or row_name.
	var data: Array = _table_data[data_name]
	var fields: Dictionary = _table_fields[data_name]
	if row_name:
		row = _table_rows[row_name]
	var row_data: Array = data[row]
	var column = fields[field_name]
	return row_data[column]

func get_enum(data_name: String, field_name: String, row := -1, row_name := "") -> int:
	# data_name is "planets", "moons", etc. Supply either row or row_name.
	var data: Array = _table_data[data_name]
	var fields: Dictionary = _table_fields[data_name]
	if row_name:
		row = _table_rows[row_name]
	var row_data: Array = data[row]
	var column = fields[field_name]
	var enum_key: String = row_data[column]
	return _enums[enum_key]

func get_table_type(data_name: String, field_name: String, row := -1, row_name := "") -> int:
	# data_name is "planets", "moons", etc. Supply either row or row_name.
	var data: Array = _table_data[data_name]
	var fields: Dictionary = _table_fields[data_name]
	if row_name:
		row = _table_rows[row_name]
	var row_data: Array = data[row]
	var column = fields[field_name]
	var table_type: String = row_data[column]
	return _table_rows[table_type]

func get_body(data_name: String, field_name: String, row := -1, row_name := "") -> Body:
	# data_name is "planets", "moons", etc. Supply either row or row_name.
	var data: Array = _table_data[data_name]
	var fields: Dictionary = _table_fields[data_name]
	if row_name:
		row = _table_rows[row_name]
	var row_data: Array = data[row]
	var column = fields[field_name]
	var body_key: String = row_data[column]
	return _bodies_by_name[body_key]

func build_object(object: Object, row_data: Array, fields: Dictionary,
		data_parser: Dictionary, req_data := EMPTY_ARRAY, read_types := EMPTY_DICT) -> void:
	# This function helps a generator class build an object from table row data.
	for property in data_parser:
		var field: String = data_parser[property]
		var value = row_data[fields[field]] if fields.has(field) else null
		if value == null:
			assert(!req_data.has(property), "Missing required data: " + row_data[0] + " " + field)
			continue
		var read_type: int = read_types.get(property, AS_IS)
		assert(read_type == AS_IS or typeof(value) == TYPE_STRING)
		match read_type:
			AS_IS:
				object[property] = value
			AS_ENUM:
				object[property] = _enums[value]
			AS_TABLE_TYPE:
				object[property] = _table_rows[value]
			AS_BODY:
				object[property] = _bodies_by_name[value]
