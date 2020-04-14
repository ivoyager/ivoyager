# table_utils.gd
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
# Requires Global singleton.

class_name TableUtils

enum { # read_type
	AS_ENUM,
	AS_TYPE,
	AS_BODY
}
const EMPTY_ARRAY := []
const EMPTY_DICT := {}

static func build_object(object: Object, row_data: Array, fields: Dictionary,
		data_parser: Dictionary, req_data := EMPTY_ARRAY, read_types := EMPTY_DICT) -> void:
	# helper function for builder classes
	var enums: Script = Global.enums
	var types: Dictionary = Global.table_types
	var bodies_by_name: Dictionary = Global.program.Registrar.bodies_by_name
	for property in data_parser:
		var field: String = data_parser[property]
		var value = row_data[fields[field]] if fields.has(field) else null
		if value == null:
			assert(!req_data.has(property), "Missing required data: " + row_data[0] + " " + field)
			continue
		var read_type: int = read_types.get(property, -1)
		assert(read_type == -1 or typeof(value) == TYPE_STRING)
		match read_type:
			-1:
				object[property] = value
			AS_ENUM:
				object[property] = enums[value]
			AS_TYPE:
				object[property] = types[value]
			AS_BODY:
				object[property] = bodies_by_name[value]
