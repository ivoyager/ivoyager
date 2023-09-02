# table_postprocessor.gd
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
extends RefCounted


enum TableDirectives {
	# table formats
	DB_ENTITIES,
	DB_ENTITIES_MOD,
	ENUMERATION,
	WIKI_LOOKUP,
	ENUM_X_ENUM,
	N_TABLE_FORMATS,
	# format-specific directives
	MODIFIES,
	TABLE_TYPE,
	TABLE_DEFAULT,
	TABLE_UNIT,
	TRANSPOSE,
}

const TableResource := preload("res://ivoyager/tables_temp/table_resource.gd")
const TableUnits := preload("res://ivoyager/tables_temp/table_units.gd")


var localized_wiki := &"en.wikipedia" # TODO: Make this changable; 'wikipedia' -> 'wiki'

var _tables: Dictionary # postprocessed data indexed [table_name][field_name][row_int]
var _enumerations: Dictionary # indexed by ALL entity names (which are globally unique)
var _enumeration_dicts: Dictionary # use table name or ANY entity name to get entity enumeration dict
var _wiki_lookup: Dictionary # populated if enable_wiki
var _precisions: Dictionary # populated if enable_precisions (indexed as tables for FLOAT fields)
var _enable_wiki: bool
var _enable_precisions: bool

# cleared when done
var _table_defaults := {} # only tables that might be modified


func postprocess(table_resources: Dictionary, table_names: Array[StringName],
		project_enums: Array[Dictionary], tables: Dictionary, enumerations: Dictionary,
		enumeration_dicts: Dictionary, wiki_lookup: Dictionary, precisions: Dictionary,
		enable_wiki: bool, enable_precisions: bool) -> void:
	
	_tables = tables
	_enumerations = enumerations
	_enumeration_dicts = enumeration_dicts
	_wiki_lookup = wiki_lookup
	_precisions = precisions
	_enable_wiki = enable_wiki
	_enable_precisions = enable_precisions
	
	# move mod tables to end, but keep order otherwise
	var i := 0
	var stop := table_names.size()
	while i < stop:
		var table_name := table_names[i]
		var table_resource: TableResource = table_resources[table_name]
		if table_resource.table_format == TableDirectives.DB_ENTITIES_MOD:
			table_names.remove_at(i)
			table_names.append(table_name)
			stop -= 1
		else:
			i += 1
	
	# add project enums
	for project_enum in project_enums:
		for entity_name in project_enum:
			assert(!enumerations.has(entity_name), "Table enumerations must be globally unique!")
			enumerations[entity_name] = project_enum[entity_name]
			enumeration_dicts[entity_name] = project_enum # needed for ENUM_X_ENUM
	
	# add/modify table enumerations
	for table_name in table_names:
		var table_res: TableResource = table_resources[table_name]
		
		match table_res.table_format:
			TableDirectives.DB_ENTITIES, TableDirectives.ENUMERATION:
				_add_table_enumeration(table_res)
			TableDirectives.DB_ENTITIES_MOD:
				_modify_table_enumeration(table_res)
	
	# postprocess by format
	for table_name in table_names:
		var table_res: TableResource = table_resources[table_name]
		
		match table_res.table_format:
			TableDirectives.DB_ENTITIES:
				_postprocess_db_entities(table_res)
			TableDirectives.DB_ENTITIES_MOD:
				_postprocess_db_entities_mod(table_res)
			TableDirectives.WIKI_LOOKUP:
				_add_wiki_lookup(table_res)
			TableDirectives.ENUM_X_ENUM:
				_postprocess_enum_x_enum(table_res)
	
	_table_defaults.clear()


func _add_table_enumeration(table_res: TableResource) -> void:
	var table_name := table_res.table_name
	var enumeration := {}
	assert(!_enumeration_dicts.has(table_name), "Duplicate table name")
	_enumeration_dicts[table_name] = enumeration
	var row_names := table_res.row_names
	for row in row_names.size():
		var entity_name := row_names[row]
		enumeration[entity_name] = row
		assert(!_enumerations.has(entity_name), "Table enumerations must be globally unique!")
		_enumerations[entity_name] = row
		assert(!_enumeration_dicts.has(entity_name), "??? entity_name == table_name ???")
		_enumeration_dicts[entity_name] = enumeration


func _modify_table_enumeration(table_res: TableResource) -> void:
	var modifies_name := table_res.modifies_table_name
	assert(_enumeration_dicts.has(modifies_name), "No enumeration for " + modifies_name)
	var enumeration: Dictionary = _enumeration_dicts[modifies_name]
	var row_names := table_res.row_names
	for row in row_names.size():
		var entity_name := row_names[row]
		if enumeration.has(entity_name):
			continue
		var modified_row := enumeration.size()
		enumeration[entity_name] = modified_row
		assert(!_enumerations.has(entity_name), "Mod entity exists in another table")
		_enumerations[entity_name] = modified_row
		assert(!_enumeration_dicts.has(entity_name), "??? entity_name == table_name ???")
		_enumeration_dicts[entity_name] = enumeration


func _postprocess_db_entities(table_res: TableResource) -> void:
	var table_dict := {}
	var table_name := table_res.table_name
	var column_names := table_res.column_names
	var row_names := table_res.row_names
	var dict_of_field_arrays := table_res.dict_of_field_arrays
	var postprocess_types := table_res.postprocess_types
	var import_defaults := table_res.default_values
	var unit_names := table_res.unit_names
	var n_rows := table_res.n_rows
	var has_entity_names := column_names.has(&"name")
	var defaults := {} # need for table mods
	
	for field in column_names:
		var import_field: Array = dict_of_field_arrays[field]
		assert(n_rows == import_field.size())
		var type: int = postprocess_types[field]
		var unit: StringName = unit_names.get(field, &"")
		var field_type := type if type < TYPE_MAX else TYPE_ARRAY
		var new_field := Array([], field_type, &"", null)
		new_field.resize(n_rows)
		for row in n_rows:
			new_field[row] = _get_postprocess_value(import_field[row], type, unit)
		table_dict[field] = new_field
		# keep table default (temporarily) in case this table is modified
		if has_entity_names:
			var import_default: Variant = import_defaults.get(field) # null ok
			var default: Variant = _get_postprocess_value(import_default, type, unit)
			defaults[field] = default
		# wiki
		if field == localized_wiki:
			assert(has_entity_names, "Wiki lookup column requires row names")
			if _enable_wiki:
				for row in n_rows:
					var wiki_title: StringName = new_field[row]
					if wiki_title:
						var row_name := row_names[row]
						_wiki_lookup[row_name] = wiki_title
	
	_tables[table_name] = table_dict
	_tables[StringName("n_" + table_name)] = n_rows
	
	if has_entity_names:
		_tables[StringName("prefix_" + table_name)] = table_res.entity_prefix
		_table_defaults[table_name] = defaults
	
	if _enable_precisions:
		_precisions[table_name] = table_res.precisions.duplicate()


func _postprocess_db_entities_mod(table_res: TableResource) -> void:
	# We don't modify the table resource. We do modify postprocessed table.
	# TODO: Should work if >1 mod table for existing table, but need to test.
	var modifies_table_name := table_res.modifies_table_name
	assert(_tables.has(modifies_table_name), "Can't modify missing table " + modifies_table_name)
	assert(_tables[StringName("prefix_" + modifies_table_name)] == table_res.entity_prefix,
			"Mod table Prefix/<entity_name> header must match modified table")
	var table_dict: Dictionary = _tables[modifies_table_name]
	assert(table_dict.has(&"name"), "Modified table must have 'name' field")
	var defaults: Dictionary = _table_defaults[modifies_table_name]
	var n_rows_key := StringName("n_" + modifies_table_name)
	var n_rows: int = _tables[n_rows_key]
	var entity_enumeration: Dictionary = _enumeration_dicts[modifies_table_name] # already expanded
	var n_rows_after_mods := entity_enumeration.size()
	var mod_column_names := table_res.column_names
	var mod_row_names := table_res.row_names
	var mod_dict_of_field_arrays := table_res.dict_of_field_arrays
	var mod_postprocess_types := table_res.postprocess_types
	var mod_default_values := table_res.default_values
	var mod_unit_names := table_res.unit_names
	var mod_n_rows := table_res.n_rows
	var mod_precisions: Dictionary
	var precisions_dict: Dictionary
	if _enable_precisions:
		mod_precisions = table_res.precisions
		precisions_dict = _precisions[modifies_table_name]
	
	# add new fields (if any) to existing table; default-impute existing rows
	for field in mod_column_names:
		if table_dict.has(field):
			continue
		var type: int = mod_postprocess_types[field]
		var unit: StringName = mod_unit_names.get(field, &"")
		var import_default: Variant = mod_default_values.get(field) # null ok
		var postprocess_default: Variant = _get_postprocess_value(import_default, type, unit)
		var field_type := type if type < TYPE_MAX else TYPE_ARRAY
		var new_field := Array([], field_type, &"", null)
		new_field.resize(n_rows)
		for row in n_rows:
			new_field[row] = postprocess_default
		table_dict[field] = new_field
		# keep default
		defaults[field] = postprocess_default
		# precisions
		if !_enable_precisions or field_type != TYPE_FLOAT:
			continue
		var new_precisions_array: Array[int] = Array([], TYPE_INT, &"", null)
		new_precisions_array.resize(n_rows)
		new_precisions_array.fill(-1)
		precisions_dict[field] = new_precisions_array
	
	# resize dictionary columns (if needed) imputing default values
	if n_rows_after_mods > n_rows:
		var new_rows := range(n_rows, n_rows_after_mods)
		for field in table_dict:
			var field_array: Array = table_dict[field]
			field_array.resize(n_rows_after_mods)
			var default: Variant = defaults[field]
			for row in new_rows:
				field_array[row] = default
		_tables[n_rows_key] = n_rows_after_mods
		# precisions
		if _enable_precisions:
			for field in precisions_dict:
				var precisions_array: Array[int] = precisions_dict[field]
				precisions_array.resize(n_rows_after_mods)
				for row in new_rows:
					precisions_array[row] = -1
	
	# add/overwrite table values
	for mod_row in mod_n_rows:
		var entity_name := mod_row_names[mod_row]
		var row: int = entity_enumeration[entity_name]
		for field in mod_column_names:
			var type: int = mod_postprocess_types[field]
			var unit: StringName = mod_unit_names.get(field, &"")
			var import_value: Variant = mod_dict_of_field_arrays[field][mod_row]
			table_dict[field][row] = _get_postprocess_value(import_value, type, unit)
	
	# add/overwrite wiki lookup
	if _enable_wiki:
		for field in mod_column_names:
			if field != localized_wiki:
				continue
			for mod_row in mod_n_rows:
				var wiki_title: StringName = mod_dict_of_field_arrays[field][mod_row]
				if wiki_title:
					var row_name := mod_row_names[mod_row]
					_wiki_lookup[row_name] = wiki_title
	
	# add/overwrite precisions
	if _enable_precisions:
		for field in mod_column_names:
			if mod_postprocess_types[field] != TYPE_FLOAT:
				continue
			var mod_precisions_array: Array[int] = mod_precisions[field]
			var precisions_array: Array[int] = precisions_dict[field]
			for mod_row in mod_n_rows:
				var entity_name := mod_row_names[mod_row]
				var row: int = entity_enumeration[entity_name]
				precisions_array[row] = mod_precisions_array[mod_row]


func _add_wiki_lookup(table_res: TableResource) -> void:
	if !_enable_wiki:
		return
	var row_names := table_res.row_names
	var wiki_field: Array[StringName] = table_res.dict_of_field_arrays[localized_wiki]
	for row in table_res.row_names.size():
		var row_name := row_names[row]
		var wiki_key := wiki_field[row]
		if wiki_key:
			_wiki_lookup[row_name] = wiki_key


func _postprocess_enum_x_enum(table_res: TableResource) -> void:
	var table_array_of_arrays: Array[Array] = []
	var table_name := table_res.table_name
	var row_names := table_res.row_names
	var column_names := table_res.column_names
	var n_import_rows := table_res.n_rows
	var n_import_columns:= table_res.n_columns
	var import_array_of_arrays := table_res.array_of_arrays
	var type := table_res.table_postprocess_type
	var unit := table_res.table_unit_name
	var import_default: Variant = table_res.table_default_value
	
	var row_type := type if type < TYPE_MAX else TYPE_ARRAY
	var postprocess_default: Variant = _get_postprocess_value(import_default, type, unit)
	
	assert(_enumeration_dicts.has(row_names[0]), "Unknown enumeration " + row_names[0])
	assert(_enumeration_dicts.has(column_names[0]), "Unknown enumeration " + column_names[0])
	var row_enumeration: Dictionary = _enumeration_dicts[row_names[0]]
	var column_enumeration: Dictionary = _enumeration_dicts[column_names[0]]
	
	var n_rows := row_enumeration.size() # >= import!
	var n_columns := column_enumeration.size() # >= import!
	
	# size & default-fill postprocess array
	table_array_of_arrays.resize(n_rows)
	for row in n_rows:
		var row_array := Array([], row_type, &"", null)
		row_array.resize(n_columns)
		row_array.fill(postprocess_default)
		table_array_of_arrays[row] = row_array
	
	# overwrite default for specified entities
	for import_row in n_import_rows:
		var row_name := row_names[import_row]
		var row: int = row_enumeration[row_name]
		for import_column in n_import_columns:
			var column_name := column_names[import_column]
			var column: int = column_enumeration[column_name]
			var import_value: Variant = import_array_of_arrays[import_row][import_column]
			var postprocess_value = _get_postprocess_value(import_value, type, unit)
			table_array_of_arrays[row][column] = postprocess_value
	
	_tables[table_name] = table_array_of_arrays


func _get_postprocess_value(import_value: Variant, type: int, unit: StringName) -> Variant:
	# appropriately handles import_value == null
	
	if type == TYPE_BOOL:
		if import_value == null:
			return false
		assert(typeof(import_value) == TYPE_BOOL, "Unexpected import data type")
		return import_value
	
	if type == TYPE_STRING:
		if import_value == null:
			return ""
		assert(typeof(import_value) == TYPE_STRING, "Unexpected import data type")
		return import_value
	
	if type == TYPE_STRING_NAME:
		if import_value == null:
			return &""
		assert(typeof(import_value) == TYPE_STRING_NAME, "Unexpected import data type")
		return import_value
	
	if type == TYPE_FLOAT: # imported as float that hasn't been unit-coverted
		if import_value == null:
			return NAN
		assert(typeof(import_value) == TYPE_FLOAT, "Unexpected import data type")
		var import_float := import_value as float
		if is_nan(import_float):
			return NAN
		if !unit:
			return import_float
		return TableUnits.convert_quantity(import_float, unit, true, true)
	
	if type == TYPE_INT: # imported as StringName for enumerations
		if import_value == null:
			return -1
		assert(typeof(import_value) == TYPE_STRING_NAME, "Unexpected import data type")
		var import_string_name := import_value as StringName
		if !import_string_name:
			return -1
		if import_string_name.is_valid_int():
			return import_string_name.to_int()
		assert(_enumerations.has(import_string_name), "Unknown enumeration " + import_string_name)
		return _enumerations[import_string_name]
	
	if type >= TYPE_MAX:
		var array_type := type - TYPE_MAX
		var array := Array([], array_type, &"", null)
		if import_value == null:
			return array # empty typed array
		assert(typeof(import_value) == TYPE_ARRAY, "Unexpected import data type")
		var import_array := import_value as Array
		var size := import_array.size()
		array.resize(size)
		for i in size:
			array[i] = _get_postprocess_value(import_array[i], array_type, unit)
		return array
	
	assert(false, "Unsupported type %s" % type)
	return null

