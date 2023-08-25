# table_importer.gd
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
class_name IVTableImporter
extends RefCounted

# Reads external data tables (.tsv files) and adds typed and processed (e.g.,
# unit-converted for FLOAT) results to IVGlobal dictionaries. Data can be
# accessed directly or using IVTableReader API. IVGlobal dictionaries are
# structured as follows:
#
#    tables[table_name][column_field][row_int] -> typed_value
#    tables["n_" + table_name] -> number of rows in table
#    tables["prefix_" + table_name] -> 'name' column Prefix, if exists
#    tables[<PREFIX_>] -> table_name; eg, tables["PLANET_"] = "planets"
#    precisions[][][] indexed as tables w/ FLOAT fields only -> sig digits
#    wiki_titles[row_name] -> title string for wiki target resolution
#    enumerations[row_name] -> row_int (globally unique!)
#       -this dictionary also enumerates enums listed in 'data_table_enums'
#
# See data/solar_system/README.txt for table construction. In short:
#
#  Type (required unless enumeration only): BOOL, STRING, FLOAT or INT.
#    For BOOL, 'true' (case-insensitive) or 'x' = True; 'false' (case-
#    insensitive) or blank is False.
#    For INT, blank = -1. Data table row names or listed enums
#    (in 'data_table_enums') will be converted to int.
#  Prefix (optional; STRING or INT): Add prefix to non-blank cells.
#    Use 'Prefix/PLANET_' to prefix name column (eg, in 'planets' table).
#  Default (optional): Use this value if blank cell.
#  Units (optional; FLOAT only): Reals will be converted from provided units
#    symbol. The symbol must be present in IVUnits.MULTIPLIERS or FUNCTIONS or
#    replacement dicts specified in IVGlobal.unit_multipliers, .unit_functions.
#
# A table with 'name' column only (not counting #comment columns) is an
# "enumeration". These do not require a 'Type' header.
#
# Tables imported via IVGlobal.table_import_mods are 'mod tables'. These modify
# existing tables and can add columns or rows or overwrite existing values.


const ivunits := preload("res://ivoyager/static/units.gd")
const utils := preload("res://ivoyager/static/utils.gd")

const DPRINT := false


var data_table_enums: Array[Dictionary] = [
	# Can be read as int. Keys must be globally unique!
	IVEnums.SBGClass,
	IVEnums.Confidence,
	IVEnums.BodyFlags,
]

# source files
var _table_import: Dictionary = IVGlobal.table_import
var _table_import_mods: Dictionary = IVGlobal.table_import_mods
var _wiki_titles_import: Array[String] = IVGlobal.wiki_titles_import

# global dicts
var _tables: Dictionary = IVGlobal.tables # IVGlobal shared
var _table_precisions: Dictionary = IVGlobal.precisions # as _tables for FLOAT fields
var _wiki_titles: Dictionary = IVGlobal.wiki_titles # IVGlobal shared
var _enumerations: Dictionary = IVGlobal.enumerations # IVGlobal shared

# localization
var _enable_wiki: bool = IVGlobal.enable_wiki
var _wiki: String = IVGlobal.wiki # wiki column header
var _unit_multipliers: Dictionary = IVGlobal.unit_multipliers
var _unit_functions: Dictionary = IVGlobal.unit_functions

# processing
var _field_infos := {} # [table_name][field] = [processed_type, prefix, unit, default] 
var _field_map := [] as Array[StringName] # cleared for each table import; [column] = field
var _column_map := {} # cleared for each table import; [field] = column
var _add_mod_fields := [] as Array[StringName] # cleared for each table import

# data counting
var _count_rows := 0
var _count_cells := 0
var _count_non_null := 0


func _init():
	_on_init()


func _on_init() -> void:
	var start_time := Time.get_ticks_msec()
	_add_data_table_enums()
	_import()
	var time := Time.get_ticks_msec() - start_time
	print("Imported data tables in %s msec; %s rows, %s cells, %s non-null cells" \
			% [time, _count_rows, _count_cells, _count_non_null])
	IVGlobal.data_tables_imported.emit()


func _project_init() -> void:
	IVGlobal.program.erase("TableImporter") # frees self


func _add_data_table_enums() -> void:
	for enum_ in data_table_enums:
		for key in enum_:
			assert(!_enumerations.has(key))
			_enumerations[key] = enum_[key]


func _import() -> void:
	for table_name in _table_import:
		var path: String = _table_import[table_name]
		_import_table(table_name, path, false)
	for table_name in _table_import_mods:
		var path: String = _table_import_mods[table_name]
		_import_table(table_name, path, true)
	_postprocess_ints()
	if !_enable_wiki:
		return
	for path in _wiki_titles_import:
		_import_wiki_titles(path)


func _import_table(table_name: StringName, path: String, is_mod := false) -> void:
	# is_mod == true means we are importing a 'mod table'; these modify an
	# existing table and can add columns or rows or overwrite existing values.
	assert(table_name and path)
	assert(!DPRINT or IVDebug.dprint("Reading " + path))
	var file := FileAccess.open(path, FileAccess.READ)
	if !file:
		assert(false, "Could not open file: " + path)
		return
	if !is_mod:
		assert(!_tables.has(table_name))
		_tables[table_name] = {}
		_table_precisions[table_name] = {}
		_field_infos[table_name] = {}
	var table: Dictionary = _tables[table_name]
	var precisions: Dictionary = _table_precisions[table_name]
	var field_info: Dictionary = _field_infos[table_name]
	_field_map.clear()
	_column_map.clear()
	_add_mod_fields.clear()
	var row := 0
	var n_columns := 0
	var reading_header := true
	var reading_fields := true
	var line := file.get_line()
	var has_types := false
	var has_row_names: bool
	while !file.eof_reached():
		if line.begins_with("#"):
			line = file.get_line()
			continue
		
		var line_split := line.split("\t")
		var line_array: Array[String] = Array(Array(line_split), TYPE_STRING, &"", null)
		
		if reading_header:
			# we're processing header until we don't recognize cell_0 as header item
			var cell_0 := line_array[0]
			
			if reading_fields: # always 1st line!
				assert(cell_0 == "name" or cell_0 == "nil", "1st field must be 'name' or 'nil'")
				has_row_names = cell_0 == "name"
				assert(has_row_names or !is_mod)
				for field_str in line_array:
					if field_str.begins_with("#") or field_str == "nil":
						_field_map.append(&"") # skip this column at line read
					else:
						var field := StringName(field_str)
						assert(is_mod or !_column_map.has(field), "Duplicated field '%s'" % field)
						_column_map[field] = n_columns
						_field_map.append(field)
						if !is_mod:
							field_info[field] = [-1, "", "", ""] # processed_type, prefix, unit, default
#							table[field] = []
						elif !table.has(field): # mod table has added a new field
							field_info[field] = [-1, "", "", ""]
							_add_mod_fields.append(field)
						else:
							assert(field_info.has(field))
					n_columns += 1
				
				var n_data_columns := _column_map.size() # does not include 'nil' or #comments
				assert(n_data_columns > 0)
				if n_data_columns == 1:
					# enumeration-only table is allowed to skip Type header
					field_info[&"name"][0] = TYPE_STRING_NAME
					table[&"name"] = Array([], TYPE_STRING_NAME, &"", null) # typed array
					has_types = true
				
				reading_fields = false
			
			# Type header required unless enumeration only
			elif cell_0 == "Type":
				for column in n_columns:
					var field: StringName = _field_map[column]
					if !field:
						continue
					var processed_type: int
					if column == 0:
						processed_type = TYPE_STRING_NAME # always 'name' field (if 'nil' we skipped)
					else:
						var type_str := line_array[column]
						processed_type = _get_processed_type(type_str)
					if !is_mod:
						field_info[field][0] = processed_type
						var import_type := _get_import_type(processed_type)
						table[field] = Array([], import_type, &"", null) # typed array
						if processed_type == TYPE_FLOAT:
							precisions[field] = [] as Array[int]
					elif !table.has(field): # mod table has added a new field
						field_info[field][0] = processed_type
						# data filled and imputed below
					else:
						assert(field_info[field][0] == processed_type, "Mod table has Type mismatch")
				has_types = true
			
			elif cell_0.begins_with("Prefix"):
				# Column 0 prefix may be appended after 'Prefix/', e.g., 'Prefix/PLANET_'
				for column in n_columns:
					var field: StringName = _field_map[column]
					if !field:
						continue
					var prefix := ""
					if column == 0:
						if cell_0.begins_with("Prefix/"):
							prefix = cell_0.trim_prefix("Prefix/")
						else:
							assert(cell_0 == "Prefix")
					else:
						prefix = line_array[column]
					field_info[field][1] = prefix
			
			elif cell_0 == "Unit":
				for column in range(1, n_columns): # column 0 never has Unit
					var field: StringName = _field_map[column]
					if !field:
						continue
					field_info[field][2] = line_array[column]
			
			elif cell_0 == "Default":
				for column in range(1, n_columns): # column 0 never has Default
					var field: StringName = _field_map[column]
					if !field:
						continue
					field_info[field][3] = line_array[column] # process after header
			
			else: # finish header processing
				assert(has_types) # required
				reading_header = false
				
				# process defaults (new table only)
				if !is_mod:
					for column in range(1, n_columns): # column 0 never has Default
						var field: StringName = _field_map[column]
						if !field:
							continue
						var processed_type: int = field_info[field][0]
						var prefix: String = field_info[field][1]
						var unit: String = field_info[field][2]
						var default = _get_import_value(field_info[field][3], processed_type,
								prefix, unit)
						field_info[field][3] = default # replace w/ processed default
				
				# process defaults & impute data for new fields (mod table only)
				if _add_mod_fields:
					var n_rows: int = _tables["n_" + table_name] # base table
					while _add_mod_fields:
						var field: StringName = _add_mod_fields.pop_back()
						var processed_type: int = field_info[field][0]
						var import_type := _get_import_type(processed_type)
						var prefix: String = field_info[field][1]
						var unit: String = field_info[field][2]
						var default = _get_import_value(field_info[field][3], processed_type,
								prefix, unit)
						field_info[field][3] = default # replace w/ processed default
						var table_column = Array([], import_type, &"", null) # typed array
						table_column.resize(n_rows)
						table_column.fill(default) # mod table will overwrite
						table[field] = table_column
						if processed_type != TYPE_FLOAT:
							continue
						var precisions_column := [] as Array[int]
						precisions_column.resize(n_rows)
						precisions_column.fill(1) # ad hoc default
						precisions[field] = precisions_column
		
		# data line
		if !reading_header:
			_count_rows += 1
			_read_line(table_name, row, line_array, has_row_names, is_mod)
			row += 1
		line = file.get_line()
	
	# We add constructed indexes to IVGlobal.tables with useful table info
	if !is_mod:
		assert(!_tables.has("n_" + table_name))
		_tables["n_" + table_name] = row # eg, tables.n_planets is number of rows in planets.tsv
		if has_row_names and field_info.name[1]: # e.g., 'PLANET_' in table 'planets'
			var name_prefix: String = field_info.name[1]
			assert(!_tables.has("prefix_" + table_name))
			_tables["prefix_" + table_name] = name_prefix # eg, tables.prefix_planets = "PLAENT_"
			assert(!_tables.has(name_prefix))
			_tables[name_prefix] = table_name # eg, tables.PLANET_ = "planets"


func _read_line(table_name: StringName, row: int, line_array: Array[String], has_row_names: bool,
		is_mod: bool) -> void:
	var table: Dictionary = _tables[table_name]
	var precisions: Dictionary = _table_precisions[table_name]
	var field_info: Dictionary = _field_infos[table_name]
	var row_name := ""
	if has_row_names: # always if is_mod
		var name_prefix: String = field_info.name[1]
		if name_prefix:
			row_name = name_prefix + line_array[0]
		else:
			row_name = line_array[0]
		assert(row_name, "Name cell is blank!")
		if !is_mod:
			assert(!_enumerations.has(row_name))
			_enumerations[row_name] = row
		elif _enumerations.has(row_name): # modifying existing table item
			row = _enumerations[row_name]
		else: # adding row to existing table!
			var name_column: Array[String] = table.name
			row = name_column.size()
			_enumerations[row_name] = row
			_tables["n_" + table_name] += 1
			# assign row_name and impute defaults (table values will overwrite)
			name_column.append(row_name)
			for field in field_info: # all fields! (not just mod table)
				if field == "name":
					continue
				var default = field_info[field][3] # untyped
				var column_array: Array = table[field]
				column_array.append(default)
				var processed_type: int = field_info[field][0]
				if processed_type == TYPE_FLOAT:
					var prec_column: Array[int] = precisions[field]
					prec_column.append(1) # ad hoc default
	
	for field in _column_map:
		_count_cells += 1
		var column: int = _column_map[field]
		var raw_value: String = line_array[column]
		var processed_type: int = field_info[field][0]
		var value # untyped
		var precision := 1
		if raw_value:
			_count_non_null += 1
			var prefix: String = field_info[field][1]
			var unit: String = field_info[field][2]
			value = _get_import_value(raw_value, processed_type, prefix, unit, true) # untyped
			if processed_type == TYPE_FLOAT: # function return is array [value, precision]
				precision = value[1]
				value = value[0]
		else: # blank cell
			value = field_info[field][3] # default (already processed)
		
		# set table value, precision & wiki
		var table_column: Array = table[field]
		if is_mod:
			table_column[row] = value
		else:
			table_column.append(value)
		if processed_type == TYPE_FLOAT:
			var prec_column: Array[int] = precisions[field]
			if is_mod:
				prec_column[row] = precision
			else:
				prec_column.append(precision)
		if _enable_wiki and field == _wiki:
			assert(row_name)
			_wiki_titles[row_name] = value


func _get_processed_type(type_str: String) -> int:
	# Array types are encoded using int values >= TYPE_MAX
	if type_str == "FLOAT":
		return TYPE_FLOAT
	if type_str == "BOOL":
		return TYPE_BOOL
	if type_str == "INT":
		return TYPE_INT
	if type_str == "STRING":
		return TYPE_STRING
	if type_str == "STRING_NAME":
		return TYPE_STRING_NAME
	if type_str.begins_with("ARRAY[") and type_str.ends_with("]"):
		var array_type := _get_processed_type(type_str.trim_prefix("ARRAY[").trim_suffix("]"))
		return TYPE_MAX + array_type
	assert(false, 'Missing or unknown table Type "%s"' % type_str)
	return -1


func _get_import_type(processed_type: int) -> int:
	if processed_type == TYPE_INT:
		return TYPE_STRING_NAME
	if processed_type >= TYPE_MAX:
		return TYPE_ARRAY
	return processed_type


func _get_import_value(raw_value: String, processed_type: int, prefix: String, unit: String,
		include_precision := false):
	# return is appropriate type, excpet INT converted in _postprocess_ints()
	# if include_precision and type == TYPE_REAL, returns [float_value, precision]
	if raw_value.begins_with("\"") and raw_value.ends_with("\""):
		raw_value = raw_value.lstrip("\"").rstrip("\"")
	raw_value = raw_value.lstrip("'")
	raw_value = raw_value.lstrip("_")
	
	if processed_type >= TYPE_MAX: # raw_value encodes an array
		var content_type := processed_type - TYPE_MAX
		assert(content_type < TYPE_MAX)
		if !raw_value:
			return []
		var raw_array := raw_value.split(",")
		var result_array := []
		for raw_element in raw_array:
			result_array.append(_get_import_value(raw_element, content_type, prefix, unit))
		return result_array
	
	match processed_type:
		TYPE_BOOL:
			if raw_value == "x" or raw_value.matchn("true"):
				return true
			else:
				assert(raw_value == "" or raw_value.matchn("false"))
				return false
		TYPE_STRING:
			if !raw_value:
				return ""
			raw_value = raw_value.c_unescape() # does not work for "\uXXXX"; Godot issue #38716
			raw_value = utils.c_unescape_patch(raw_value) # handles "\uXXXX"
			if prefix:
				return prefix + raw_value
			return raw_value
		TYPE_STRING_NAME:
			if !raw_value:
				return &""
			if prefix:
				return (prefix + raw_value) as StringName
			return raw_value as StringName
		TYPE_FLOAT:
			var value: float
			var precision := -1
			if !raw_value:
				value = NAN
			elif raw_value == "?":
				value = INF
			elif raw_value == "INF":
				value = INF
			elif raw_value == "-INF":
				value = -INF
			else:
				raw_value = raw_value.replace("E", "e")
				if raw_value.begins_with("~"):
					precision = 1
					raw_value = raw_value.lstrip("~")
				elif include_precision:
					precision = utils.get_float_str_precision(raw_value)
				value = float(raw_value)
				if unit:
					value = ivunits.convert_quantity(value, unit, true, true,
							_unit_multipliers, _unit_functions)
			if include_precision:
				return [value, precision]
			return value
		TYPE_INT:
			# keep as StringName for now; we'll convert to INT in _postprocess_ints()
			if raw_value and prefix: # mainly for enumeration
				return prefix + raw_value # e.g., 'PLANET_' + 'EARTH'
			else:
				return raw_value
	
	assert(false, 'Missing or unknown type "%s"' % processed_type)


func _postprocess_ints() -> void:
	# Converts INT strings to enumerations after all tables imported.
	# Replaces typed arrays.
	for table_name in _field_infos:
		var field_info: Dictionary = _field_infos[table_name]
		var table: Dictionary = _tables[table_name]
		for field in field_info:
			var processed_type: int = field_info[field][0]
			if processed_type == TYPE_INT:
				var preprocess_column: Array[StringName] = table[field]
				var n_rows := preprocess_column.size()
				var postprocess_column := [] as Array[int]
				postprocess_column.resize(n_rows)
				for row in n_rows:
					var int_name: StringName = preprocess_column[row]
					postprocess_column[row] = _get_int_from_string_name(int_name)
				table[field] = postprocess_column
			elif processed_type == TYPE_MAX + TYPE_INT: # table column Type is 'ARRAY[INT]'
				var preprocess_column: Array[Array] = table[field]
				var n_rows := preprocess_column.size()
				var postprocess_column := [] as Array[Array]
				postprocess_column.resize(n_rows)
				for row in n_rows:
					var preprocess_array: Array[StringName] = preprocess_column[row]
					var n_elements := preprocess_array.size()
					var postprocess_array := [] as Array[int]
					postprocess_array.resize(n_elements)
					for i in n_elements:
						postprocess_array[i] = _get_int_from_string_name(preprocess_array[i])
					postprocess_column[row] = postprocess_array
				table[field] = postprocess_column


func _get_int_from_string_name(int_name: StringName) -> int:
	if !int_name:
		return -1
	if int_name.is_valid_int():
		return int_name.to_int()
	assert(_enumerations.has(int_name), "Unknown enumeration '%s'" % int_name)
	return _enumerations[int_name]


func _import_wiki_titles(path: String) -> void:
	assert(!DPRINT or IVDebug.dprint("Reading " + path))
	var file := FileAccess.open(path, FileAccess.READ)
	if !file:
		assert(false, "Could not open file: " + path)
		return
	_column_map.clear()
	var reading_header := true
	var reading_fields := true
	var n_columns := 0
	var line := file.get_line()
	while !file.eof_reached():
		if line.begins_with("#"):
			line = file.get_line()
			continue
		var line_split := line.split("\t")
		var line_array: Array[String] = Array(Array(line_split), TYPE_STRING, &"", null)
		if reading_header:
			if reading_fields: # always 1st line!
				assert(line_array[0] == "name", "1st field must be 'name'")
				for field_str in line_array:
					if !field_str.begins_with("#"):
						var field := StringName(field_str)
						assert(!_column_map.has(field), "Duplicated field '" + field_str + "'")
						_column_map[field] = n_columns
					n_columns += 1
				reading_fields = false
			else:
				reading_header = false
		if reading_header:
			line = file.get_line()
			continue
		var row_name := StringName(line_array[0])
		assert(row_name, "name cell is blank!")
		_count_rows += 1
		for field in _column_map:
			if _enable_wiki and field == _wiki:
				_count_non_null += 1
				_count_cells += 1
				var column: int = _column_map[field]
				var wiki_title := StringName(line_array[column])
				_wiki_titles[row_name] = wiki_title
		line = file.get_line()

