# table_data.gd
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
extends Node

# This can be added as an autoload at project level for easy access.
#
# In all but very specific cases, users should interface only with this node.

const TableImporter = preload("res://ivoyager/tables_temp/table_importer.gd")
const TableProcessor = preload("res://ivoyager/tables_temp/table_processor.gd")

const units := preload("res://ivoyager/static/units.gd")
const utils := preload("res://ivoyager/static/utils.gd")
const math := preload("res://ivoyager/static/math.gd")


# API here provides constructor methods and table access with protections for
# missing table fields and values. Alternatively, you can access data directly
# from dictionaries. Each table is structured as a dictionary of
# column arrays containing typed (and unit-converted for FLOAT) values. Data can
# be accessed directly by indexing:
#
#    tables[table_name][column_field][row_int] -> typed_value
#    tables["n_" + table_name] -> number of rows in table
#    tables["prefix_" + table_name] -> 'name' column Prefix, if exists
#    tables[<PREFIX_>] -> table_name; eg, tables["PLANET_"] = "planets"
#    precisions[][][] indexed as tables w/ FLOAT fields only -> sig digits
#    wiki_titles[row_name] -> title string for wiki target resolution
#    enumerations[row_name] -> row_int (globally unique!)
#       -this dictionary also enumerates enums listed in 'data_table_enums'


var tables: Dictionary = IVGlobal.tables # indexed [table][field][row]
var enumerations: Dictionary = IVGlobal.enumerations # indexed by ALL entity names
var precisions: Dictionary = IVGlobal.precisions # as tables for FLOAT fields


# *****************************************************************************
# init

func _project_init() -> void:
	pass


# *****************************************************************************
# public functions
# For get functions, table is "planets", "moons", etc. Many get functions will
# accept either row_int or row_name (not both!).


func get_n_rows(table: StringName) -> int:
	return tables["n_" + table]


func get_names_prefix(table: StringName) -> int:
	# E.g., 'PLANET_' in planets.tsv.
	# Prefix must be specified for the table's 'name' column.
	return tables["prefix_" + table]


func get_row_name(table: StringName, row: int) -> StringName:
	return tables[table]["name"][row]


func get_row(row_name: StringName) -> int:
	# Returns -1 if missing. All row_name's are globally unique.
	return enumerations.get(row_name, -1)


func get_names_enumeration(table: StringName) -> Dictionary:
	# Returns an enum-like dict of row numbers keyed by row names.
	var dict := {}
	for row_name in tables[table]["name"]:
		dict[row_name] = enumerations[row_name]
	return dict


func get_column_array(table: StringName, field: StringName) -> Array:
	# Returns internal array reference - DON'T MODIFY!
	return tables[table][field]


func get_n_matching(table: StringName, field: StringName, match_value) -> int:
	# field must exist in specified table
	# match_value type must mach column type
	var column_array: Array = tables[table][field]
	return column_array.count(match_value)


func get_matching_rows(table: StringName, field: StringName, match_value) -> Array:
	# field must exist in specified table
	# match_value type must mach column type
	var column_array: Array = tables[table][field]
	var size := column_array.size()
	var result := []
	var row := 0
	while row < size:
		if column_array[row] == match_value:
			result.append(row)
		row += 1
	return result


func get_true_rows(table: StringName, field: StringName) -> Array:
	# field must exist in specified table
	var column_array: Array = tables[table][field]
	var size := column_array.size()
	var result := []
	var row := 0
	while row < size:
		if column_array[row]:
			result.append(row)
		row += 1
	return result


func has_row_name(table: StringName, row_name: StringName) -> bool:
	if !enumerations.has(row_name):
		return false
	var table_dict: Dictionary = tables[table]
	if !table_dict.has("name"):
		return false
	var name_column: Array[StringName] = table_dict.name
	return name_column.has(row_name)


func has_value(table: StringName, field: StringName, row := -1, row_name := "") -> bool:
	# Evaluates true if table has field and does not contain type-specific
	# 'null' value: i.e., "", NAN or -1 for STRING, FLOAT or INT, respectively.
	# Always true for Type BOOL.
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var table_dict: Dictionary = tables[table]
	if !table_dict.has(field):
		return false
	if row_name:
		row = enumerations[row_name]
	var value = table_dict[field][row]
	var type := typeof(value)
	if type == TYPE_FLOAT:
		return !is_nan(value)
	if type == TYPE_INT:
		return value != -1
	if type == TYPE_STRING:
		return value != ""
	return true # BOOL


func has_float_value(table: StringName, field: StringName, row := -1, row_name := "") -> bool:
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var table_dict: Dictionary = tables[table]
	if !table_dict.has(field):
		return false
	if row_name:
		row = enumerations[row_name]
	return !is_nan(table_dict[field][row])


func get_string(table: StringName, field: StringName, row := -1, row_name := "") -> String:
	# Use for table Type 'STRING'; returns "" if missing
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var table_dict: Dictionary = tables[table]
	if !table_dict.has(field):
		return ""
	if row_name:
		row = enumerations[row_name]
	return table_dict[field][row]


func get_string_name(table: StringName, field: StringName, row := -1, row_name := "") -> StringName:
	# Use for table Type 'STRING_NAME'; returns &"" if missing
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var table_dict: Dictionary = tables[table]
	if !table_dict.has(field):
		return &""
	if row_name:
		row = enumerations[row_name]
	return table_dict[field][row]


func get_bool(table: StringName, field: StringName, row := -1, row_name := "") -> bool:
	# Use for table Type 'BOOL'; returns false if missing
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var table_dict: Dictionary = tables[table]
	if !table_dict.has(field):
		return false
	if row_name:
		row = enumerations[row_name]
	return table_dict[field][row]


func get_int(table: StringName, field: StringName, row := -1, row_name := "") -> int:
	# Use for table Type 'INT'; returns -1 if missing
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var table_dict: Dictionary = tables[table]
	if !table_dict.has(field):
		return -1
	if row_name:
		row = enumerations[row_name]
	return table_dict[field][row]


func get_float(table: StringName, field: StringName, row := -1, row_name := "") -> float:
	# Use for table Type 'FLOAT'; returns NAN if missing
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var table_dict: Dictionary = tables[table]
	if !table_dict.has(field):
		return NAN
	if row_name:
		row = enumerations[row_name]
	return table_dict[field][row]


func get_array(table: StringName, field: StringName, row := -1, row_name := ""): # returns typed array
	# Use for table Type 'ARRAY:xxxx'; returns [] if missing
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var table_dict: Dictionary = tables[table]
	if !table_dict.has(field):
		return []
	if row_name:
		row = enumerations[row_name]
	return table_dict[field][row]


func get_float_precision(table: StringName, field: StringName, row := -1, row_name := "") -> int:
	# field must be type FLOAT
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	var table_prec_dict: Dictionary = tables[table]
	if !table_prec_dict.has(field):
		return -1
	if row_name:
		row = enumerations[row_name]
	return table_prec_dict[field][row]


func get_least_float_precision(table: StringName, fields: Array[StringName], row := -1,
		row_name := "") -> int:
	# All fields must be type FLOAT
	assert((row == -1) != (row_name == ""), "Requires either row or row_name (not both)")
	if row_name:
		row = enumerations[row_name]
	var min_precision := 9999
	for field in fields:
		var precission: int = precisions[table][field][row]
		if min_precision > precission:
			min_precision = precission
	return min_precision


func get_float_precisions(fields: Array[StringName], table: StringName, row: int) -> Array:
	# Missing or non-FLOAT values will have precision -1.
	var this_table_precisions: Dictionary = precisions[table]
	var n_fields := fields.size()
	var result := utils.init_array(n_fields, -1)
	var i := 0
	while i < n_fields:
		var field: StringName = fields[i]
		if this_table_precisions.has(field):
			result[i] = this_table_precisions[field][row]
		i += 1
	return result


func get_row_data_array(fields: Array[StringName], table: StringName, row: int) -> Array:
	# Returns an array with value for each field; all fields must exist.
	var n_fields := fields.size()
	var data := []
	data.resize(n_fields)
	var i := 0
	while i < n_fields:
		var field: StringName = fields[i]
		data[i] = tables[table][field][row]
		i += 1
	return data


func build_dictionary(dict: Dictionary, fields: Array[StringName], table: StringName, row: int
		) -> void:
	# Sets dict value for each field that exactly matches a field in table.
	# Missing value in table without default will not be set.
	var n_fields := fields.size()
	var i := 0
	while i < n_fields:
		var field: StringName = fields[i]
		if has_value(table, field, row):
			dict[field] = tables[table][field][row]
		i += 1


func build_dictionary_from_keys(dict: Dictionary, table: StringName, row: int) -> void:
	# Sets dict value for each existing dict key that exactly matches a column
	# field in table. Missing value in table without default will not be set.
	for field in dict:
		if has_value(table, field, row):
			dict[field] = tables[table][field][row]


func build_object(object: Object, fields: Array[StringName], table: StringName, row: int) -> void:
	# Sets object property for each field that exactly matches a field in table.
	# Missing value in table without default will not be set.
	var n_fields := fields.size()
	var i := 0
	while i < n_fields:
		var field: StringName = fields[i]
		if has_value(table, field, row):
			object.set(field, tables[table][field][row])
		i += 1


func build_object_all_fields(object: Object, table: StringName, row: int) -> void:
	# Sets object property for each field that exactly matches a field in table.
	# Missing value in table without default will not be set.
	for field in tables[table]:
		if has_value(table, field, row):
			object.set(field, tables[table][field][row])


func get_flags(flag_fields: Dictionary, table: StringName, row: int, flags := 0) -> int:
	# Sets flag if table value exists and would evaluate true in get_bool(),
	# i.e., is true or x. Does not unset.
	for flag in flag_fields:
		var field: StringName = flag_fields[flag]
		if get_bool(table, field, row):
			flags |= flag
	return flags


