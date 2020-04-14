# table_helper.gd
# This file is part of I, Voyager
# https://ivoyager.dev
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

enum { # read_type
	AS_IS,
	AS_ENUM,
	AS_TYPE,
	AS_BODY
}
const EMPTY_ARRAY := []
const EMPTY_DICT := {}

var _tables: Dictionary = Global.tables
var _types: Dictionary = Global.table_types
var _bodies_by_name: Dictionary = Global.bodies_by_name
var _enums: Script

func project_init() -> void:
	_enums = Global.enums

func get_value(table_prefix: String, field_name: String, row := -1, row_name := "",
		read_type := AS_IS):
	# table_prefix is "Planet", "Moon", "Body", etc. Supply either row or
	# row_name. Return value is of any type. (See typed get functions below.)
	var data: Array = _tables[table_prefix + "Data"]
	var fields: Dictionary = _tables[table_prefix + "Fields"]
	if row_name:
		row = _types[row_name]
	var row_data: Array = data[row]
	var column = fields[field_name]
	var value = row_data[column]
	match read_type:
		AS_IS:
			return value
		AS_ENUM:
			return _enums[value]
		AS_TYPE:
			return _types[value]
		AS_BODY:
			return _bodies_by_name[value]

func get_bool(table_prefix: String, field_name: String, row := -1, row_name := "") -> bool:
	# See get_value() comments. Table_Type "BOOL" and "X" are encoded as bool.
	var data: Array = _tables[table_prefix + "Data"]
	var fields: Dictionary = _tables[table_prefix + "Fields"]
	if row_name:
		row = _types[row_name]
	var row_data: Array = data[row]
	var column = fields[field_name]
	return row_data[column]




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
			AS_TYPE:
				object[property] = _types[value]
			AS_BODY:
				object[property] = _bodies_by_name[value]
