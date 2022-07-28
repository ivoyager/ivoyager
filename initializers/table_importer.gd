# table_importer.gd
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
class_name IVTableImporter

# Reads external data tables (.tsv files) and adds typed and processed (e.g.,
# unit-converted for REAL) results to IVGlobal dictionaries. Data can be
# accessed direct or using IVTableReader API. IVGlobal dictionaries are
# structured as follows:
#
#    tables[table_name][column_field][row_int] -> typed_value
#    tables["n_" + table_name] -> number of rows in table
#    table_rows[row_name] -> row_int (every row_name is globally unique!)
#    table_types[table_name][column_field] -> Type string in table
#    table_precisions[][][] indexed as tables w/ REAL fields only -> sig digits
#    wiki_titles[row_name] -> title string for wiki target resolution
#
# See data/solar_system/README.txt for table construction. In short:
#
#  Type (required!): X, BOOL, INT, FLOAT, STRING, TABLE_ROW or enum name.
#    An enum must be present in static file referenced in IVGlobal.enums. 'X'
#    type is imported as BOOL where 'x' is true and blank cell is false.
#  Prefix (optional; STRING or TABLE_ROW): Add prefix to non-blank cells.
#    Use 'Prefix/PLANET_' to prefix name column (eg, in 'planets' table).
#  Default (optional; not expected for X): Use this value if blank cell.
#  Units (optional; REAL only): Reals will be converted from provided units
#    symbol. The symbol must be present in IVUnits.MULTIPLIERS or FUNCTIONS or
#    replacement dicts specified in IVGlobal.unit_multipliers, .unit_functions.


const units := preload("res://ivoyager/static/units.gd")
const utils := preload("res://ivoyager/static/utils.gd")
const math := preload("res://ivoyager/static/math.gd")

const DPRINT := false
const TYPE_TEST := ["REAL", "BOOL", "X", "INT", "STRING", "TABLE_ROW"] # & enum names

# source files
var _table_import: Dictionary = IVGlobal.table_import
var _wiki_titles_import: Array = IVGlobal.wiki_titles_import
# imported data
var _tables: Dictionary = IVGlobal.tables
var _table_rows: Dictionary = IVGlobal.table_rows # IVGlobal shared
var _table_types: Dictionary = IVGlobal.table_types # indexed [table_name][field]
var _table_precisions: Dictionary = IVGlobal.table_precisions # as _tables for REAL fields
var _wiki_titles: Dictionary = IVGlobal.wiki_titles # IVGlobal shared

# localization
var _enable_wiki: bool = IVGlobal.enable_wiki
var _enums: Script = IVGlobal.enums
var _wiki: String = IVGlobal.wiki # wiki column header
var _unit_multipliers: Dictionary = IVGlobal.unit_multipliers
var _unit_functions: Dictionary = IVGlobal.unit_functions

# data counting
var _count_rows := 0
var _count_cells := 0
var _count_non_null := 0


func _init():
	_on_init()


func _on_init() -> void:
	var start_time := OS.get_system_time_msecs()
	_import()
	var time := OS.get_system_time_msecs() - start_time
	print("Imported data tables in %s msec; %s rows, %s cells, %s non-null cells" \
			% [time, _count_rows, _count_cells, _count_non_null])


func _project_init() -> void:
	IVGlobal.program.erase("TableImporter2") # frees self


func _import() -> void:
	for table_name in _table_import:
		var path: String = _table_import[table_name]
		_import_table(table_name, path)
	
	_postprocess()
	if !_enable_wiki:
		return
	for path in _wiki_titles_import:
		_import_wiki_titles(path)


func _import_wiki_titles(path: String) -> void:
	assert(DPRINT and prints("Reading", path) or true)
	var file := File.new()
	if file.open(path, file.READ) != OK:
		assert(false, "Could not open file: " +  path)
	var fields := {}
	var reading_header := true
	var reading_fields := true
	var n_columns := 0
	var line := file.get_line()
	while !file.eof_reached():
		var comment_test := line.find("#")
		if comment_test != -1 and comment_test < 4: # skip comment line
			line = file.get_line()
			continue
		var line_array := line.split("\t") as Array
		if reading_header:
			if reading_fields: # always 1st line!
				assert(line_array[0] == "name", "1st field must be 'name'")
				for field in line_array:
					fields[field] = n_columns
					n_columns += 1
				reading_fields = false
				assert(n_columns == fields.size(),
						"Duplicate field (%s columns, %s unique fields) in %s" \
						% [n_columns, fields.size(), path])
			else:
				reading_header = false
		if reading_header:
			line = file.get_line()
			continue
		var row_name: String = line_array[0]
		assert(row_name, "name cell is blank!")
		_count_rows += 1
		for field in fields:
			if _enable_wiki and field == _wiki:
				_count_non_null += 1
				_count_cells += 1
				var column: int = fields[field]
				var value: String = line_array[column]
				_wiki_titles[row_name] = value
		line = file.get_line()


func _import_table(table_name: String, path: String) -> void:
	assert(table_name and path)
	assert(DPRINT and prints("Reading", path) or true)
	var file := File.new()
	if file.open(path, file.READ) != OK:
		assert(false, "Could not open file: " +  path)
	
	var row := 0
	_tables[table_name] = {}
	_table_types[table_name] = {}
	_table_precisions[table_name] = {}
	var fields := {}
	var types := []
	var units := []
	var defaults := []
	var prefixes := []
	var reading_header := true
	var reading_fields := true
	var n_columns := 0
	var line := file.get_line()
	var has_type := false
	var has_row_names: bool
	while !file.eof_reached():
		var comment_test := line.find("#")
		if comment_test != -1 and comment_test < 4: # skip comment line
			line = file.get_line()
			continue
		var line_array := line.split("\t") as Array
		if reading_header:
			var cell_0: String = line_array[0]
			if reading_fields: # always 1st line!
				assert(cell_0 == "name" or cell_0 == "nil", "1st field must be 'name' or 'nil'")
				has_row_names = cell_0 == "name"
				for field in line_array:
					assert(field != "n_rows", "Disallowed field name")
					if field == "Comments":
						break
					if field != "nil":
						_tables[table_name][field] = []
					fields[field] = n_columns
					n_columns += 1
				reading_fields = false
				assert(n_columns == fields.size(), "Duplicate field (%s columns, %s unique fields) in %s" \
						% [n_columns, fields.size(), path])
			# Type, Units & Default; only Type is required and must be before Default
			elif cell_0 == "Type":
				types = line_array.duplicate()
				types[0] = "STRING" # always name field (or nil)
				types.resize(n_columns) # truncate Comment column
				for field in fields:
					var column: int = fields[field]
					var type: String = types[column]
					assert(TYPE_TEST.has(type) or type in _enums)
					_table_types[table_name][field] = type
					if type == "REAL":
						# REAL values have parallel dict w/ precisions
						_table_precisions[table_name][field] = []
				has_type = true
			elif cell_0 == "Unit":
				units = line_array.duplicate()
				units[0] = ""
				units.resize(n_columns) # truncate Comment column
#				assert(_units_test())
			elif cell_0 == "Default":
				assert(has_type)
				defaults = line_array.duplicate()
				defaults[0] = ""
				defaults.resize(n_columns) # truncate Comment column
			elif cell_0.begins_with("Prefix"):
				# Prefix for the name column may be appended after "/":
				# e.g., "Prefix/PLANET_"
				assert(has_type)
				prefixes = line_array.duplicate()
				prefixes.resize(n_columns) # truncate Comment column
				if cell_0.begins_with("Prefix/"):
					prefixes[0] = cell_0.lstrip("Prefix").lstrip("/")
					# Godot 3.5 bug?
					# lstrip("Prefix/") strips leading char after /
				else:
					assert(cell_0 == "Prefix")
					prefixes[0] = ""
			else:
				# We are done reading header; must be at first data line.
				assert(types) # required
				if !units:
					for _i in range(n_columns):
						units.append("")
				if !defaults:
					for _i in range(n_columns):
						defaults.append("")
				if !prefixes:
					for _i in range(n_columns):
						prefixes.append("")
				reading_header = false
				
				print(table_name)
				print(prefixes)
				
		# data line
		if !reading_header:
			_count_rows += 1
			_read_line(table_name, row, line_array, fields, types, units, defaults, prefixes,
					has_row_names)
			row += 1
		line = file.get_line()
	
	_tables["n_" + table_name] = row


func _read_line(table_name: String, row: int, line_array: Array, fields: Dictionary,
		types: Array, units: Array, defaults: Array, prefixes: Array,
		has_row_names: bool) -> void:
	var row_name := ""
	if has_row_names:
		if prefixes[0]:
			row_name = prefixes[0] + line_array[0]
		else:
			row_name = line_array[0]
		assert(row_name, "name cell is blank!")
		assert(!_table_rows.has(row_name))
		_table_rows[row_name] = row
	for field in fields:
		if field == "nil":
			continue
		_count_cells += 1
		var column: int = fields[field]
		var raw_value: String = line_array[column]
		if !raw_value: # blank cell; set to default (which may be blank)
			raw_value = defaults[column]
		else:
			_count_non_null += 1
		var type: String = types[column]
		var unit: String = units[column]
		var prefix: String = prefixes[column]
		_append_preprocessed(table_name, field, row_name, raw_value, type, unit, prefix)


func _append_preprocessed(table_name: String, field: String, row_name: String,
			raw_value: String, type: String, unit: String, prefix: String):
	# Convert BOOL, X, REAL, INT and enums, and process STRING; we'll convert
	# TABLE_ROW to int in _postprocess()
	if raw_value.begins_with("\"") and raw_value.ends_with("\""):
		raw_value = raw_value.lstrip("\"").rstrip("\"")
	raw_value = raw_value.lstrip("'")
	raw_value = raw_value.lstrip("_")
	var value # untyped
	match type:
		"X":
			assert(raw_value == "" or raw_value == "x")
			value = raw_value == "x"
		"BOOL":
			assert(raw_value.matchn("false") or raw_value.matchn("true"))
			value = raw_value.matchn("true")
		"STRING":
			value = raw_value.c_unescape() # does not work for "\uXXXX"; Godot issue #38716
			value = utils.c_unescape_patch(value) # handles "\uXXXX"
			if value and prefix:
				value = prefix + value
		"REAL":
			# we determine precision here
			var precision := -1
			if !raw_value:
				value = NAN
			elif raw_value == "?":
				value = INF
			else:
				raw_value = raw_value.replace("E", "e")
				if raw_value.begins_with("~"):
					precision = 1
					raw_value = raw_value.lstrip("~")
				else:
					precision = utils.get_real_str_precision(raw_value)
				var real := float(raw_value)
				if unit:
					real = units.convert_quantity(real, unit, true, true,
							_unit_multipliers, _unit_functions)
				value = float(real)
			_table_precisions[table_name][field].append(precision)
		"INT":
			value = int(raw_value) if raw_value else -1
		"TABLE_ROW": # we'll convert to int in _postprocess()
			value = raw_value
			if value and prefix:
				value = prefix + value
		_: # must be a valid enum name
			if !raw_value:
				value = -1
			else:
				var enum_dict: Dictionary = _enums.get(type)
				value = enum_dict[raw_value]
	# set value
	_tables[table_name][field].append(value)
	if _enable_wiki and field == _wiki:
		_wiki_titles[row_name] = value


func _postprocess() -> void:
	# Converts Type "X" to "BOOL" (values are already internally bool).
	# Converts values of type TABLE_ROW to int (after all tables imported!).
	for table_name in _tables:
		if table_name.begins_with("n_"):
			continue
		for field in _tables[table_name]:
			var type: String = _table_types[table_name][field]
			if type == "X":
				_table_types[table_name][field] = "BOOL"
				continue
			if type != "TABLE_ROW":
				continue
			var column_array: Array = _tables[table_name][field]
			var row: int = column_array.size()
			while row > 0:
				row -= 1
				var row_name: String = column_array[row]
				column_array[row] = _table_rows[row_name] if row_name else -1

