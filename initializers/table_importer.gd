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
# accessed directly or using IVTableReader API. IVGlobal dictionaries are
# structured as follows:
#
#    tables[table_name][column_field][row_int] -> typed_value
#    tables["n_" + table_name] -> number of rows in table
#    tables["prefix_" + table_name] -> 'name' column Prefix, if exists
#    tables[<PREFIX_>] -> table_name; eg, tables["PLANET_"] = "planets"
#    precisions[][][] indexed as tables w/ REAL fields only -> sig digits
#    wiki_titles[row_name] -> title string for wiki target resolution
#    enumerations[row_name] -> row_int (globally unique!)
#       -this dictionary also enumerates enums listed in 'data_table_enums'
#
# See data/solar_system/README.txt for table construction. In short:
#
#  Type (required unless enumeration only): BOOL, STRING, REAL or INT.
#    For BOOL, 'true' (case-insensitive) or 'x' = True; 'false' (case-
#    insensitive) or blank is False.
#    For INT, blank = -1. Data table row names or listed enums
#    (in 'data_table_enums') will be converted to int.
#  Prefix (optional; STRING or INT): Add prefix to non-blank cells.
#    Use 'Prefix/PLANET_' to prefix name column (eg, in 'planets' table).
#  Default (optional): Use this value if blank cell.
#  Units (optional; REAL only): Reals will be converted from provided units
#    symbol. The symbol must be present in IVUnits.MULTIPLIERS or FUNCTIONS or
#    replacement dicts specified in IVGlobal.unit_multipliers, .unit_functions.
#
# A table with 'name' column only (not counting #comment columns) is an
# "enumeration". These do not require a 'Type' header.


const ivunits := preload("res://ivoyager/static/units.gd")
const utils := preload("res://ivoyager/static/utils.gd")

const DPRINT := false
const TYPE_TEST := ["REAL", "BOOL", "INT", "STRING"]


var data_table_enums := [
	IVEnums.Confidence,
]

# source files
var _table_import: Dictionary = IVGlobal.table_import
var _table_import_mods: Dictionary = IVGlobal.table_import_mods
var _wiki_titles_import: Array = IVGlobal.wiki_titles_import

# global dicts
var _tables: Dictionary = IVGlobal.tables
var _table_precisions: Dictionary = IVGlobal.precisions # as _tables for REAL fields
var _wiki_titles: Dictionary = IVGlobal.wiki_titles # IVGlobal shared
var _enumerations: Dictionary = IVGlobal.enumerations # IVGlobal shared

# localization
var _enable_wiki: bool = IVGlobal.enable_wiki
var _wiki: String = IVGlobal.wiki # wiki column header
var _unit_multipliers: Dictionary = IVGlobal.unit_multipliers
var _unit_functions: Dictionary = IVGlobal.unit_functions

# processing
var _table_fields := {}
var _table_types := {}
var _table_units := {}
var _table_defaults := {}
var _table_prefixes := {}
var _int_fields_for_postprocess := {}

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
	IVGlobal.verbose_signal("data_tables_imported")


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
		_import_table(table_name, path)
	_postprocess_ints()
	if !_enable_wiki:
		return
	for path in _wiki_titles_import:
		_import_wiki_titles(path)


func _import_table(table_name: String, path: String, is_new := true) -> void:
	assert(table_name and path)
	assert(DPRINT and prints("Reading", path) or true)
	var file := File.new()
	if file.open(path, file.READ) != OK:
		assert(false, "Could not open file: " +  path)
	var row := 0
	if is_new:
		_tables[table_name] = {}
		_table_fields[table_name] = {}
		_table_types[table_name] = []
		_table_units[table_name] = []
		_table_defaults[table_name] = []
		_table_prefixes[table_name] = []
		_table_precisions[table_name] = {}
	var fields: Dictionary = _table_fields[table_name]
	var types: Array = _table_types[table_name]
	var units: Array = _table_units[table_name]
	var defaults: Array = _table_defaults[table_name]
	var prefixes: Array = _table_prefixes[table_name]
	var precisions: Dictionary = _table_precisions[table_name]
	var reading_header := true
	var reading_fields := true
	var n_columns := fields.size()
	var line := file.get_line()
	var has_types := false
	var has_row_names: bool
	while !file.eof_reached():
		if line.begins_with("#"):
			line = file.get_line()
			continue
		var line_array := line.split("\t") as Array
		if reading_header:
			var cell_0: String = line_array[0]
			if reading_fields: # always 1st line!
				assert(cell_0 == "name" or cell_0 == "nil", "1st field must be 'name' or 'nil'")
				has_row_names = cell_0 == "name"
				assert(has_row_names or is_new)
				for field in line_array:
					if field != "nil" and !field.begins_with("#"):
						assert(!fields.has(field), "Duplicated field '" + field + "'")
						fields[field] = n_columns
						if is_new or !_tables[table_name].has(field):
							_tables[table_name][field] = []
					n_columns += 1
				types.resize(n_columns)
				units.resize(n_columns)
				defaults.resize(n_columns)
				prefixes.resize(n_columns)
				units.fill("")
				defaults.fill("")
				prefixes.fill("")
				var data_columns := fields.size() # includes 'name' but not #comments
				assert(data_columns > 0)
				if data_columns == 1:
					# enumeration-only; table may or may not have Type header
					types[0] = "STRING"
					has_types = true
				reading_fields = false
			
			# Type, Units, Default, Prefix; Type required (before others) unless enumeration only
			elif cell_0 == "Type":
				for i in n_columns:
					types[i] = line_array[i]
				types[0] = "STRING" # always name field (or nil)
				for field in fields:
					var column: int = fields[field]
					var type: String = types[column]
					assert(TYPE_TEST.has(type), "Missing or unknown type '" + type + "'")
					if type == "REAL":
						# REAL values have parallel dict w/ precisions
						precisions[field] = []
					elif type == "INT":
						# remember for enumeration conversion in _postprocess_ints()
						if !_int_fields_for_postprocess.has(table_name):
							_int_fields_for_postprocess[table_name] = [field]
						elif is_new or !_int_fields_for_postprocess[table_name].has(field):
							_int_fields_for_postprocess[table_name].append(field)
				has_types = true
			elif cell_0 == "Unit":
				assert(has_types)
				for i in n_columns:
					units[i] = line_array[i]
				units[0] = ""
			elif cell_0 == "Default":
				assert(has_types)
				for i in n_columns:
					defaults[i] = line_array[i]
				defaults[0] = ""
			elif cell_0.begins_with("Prefix"):
				# Prefix for the name column may be appended after "/":
				# e.g., "Prefix/PLANET_"
				assert(has_types)
				for i in n_columns:
					prefixes[i] = line_array[i]
				if cell_0.begins_with("Prefix/"):
					prefixes[0] = cell_0.trim_prefix("Prefix/")
				else:
					assert(cell_0 == "Prefix")
					prefixes[0] = ""
			else: # finish header processing
				assert(has_types) # required
				reading_header = false
		
		# data line
		if !reading_header:
			_count_rows += 1
			_read_line(table_name, row, line_array, has_row_names, is_new)
			row += 1
		line = file.get_line()
	
	# We add constructed indexes to IVGlobal.tables with useful table info
	assert(!_tables.has("n_" + table_name))
	_tables["n_" + table_name] = row # eg, tables.n_planets is # rows in planets.tsv
	if prefixes[0]: # e.g., 'PLANET_' in table 'planets'
		assert(!_tables.has("prefix_" + table_name))
		_tables["prefix_" + table_name] = prefixes[0] # eg, tables.prefix_planets = "PLAENT_"
		assert(!_tables.has(prefixes[0]))
		_tables[prefixes[0]] = table_name # eg, tables.PLANET_ = "planets"


func _read_line(table_name: String, row: int, line_array: Array, has_row_names: bool,
		is_new: bool) -> void:
	var fields: Dictionary = _table_fields[table_name]
	var types: Array = _table_types[table_name]
	var units: Array = _table_units[table_name]
	var defaults: Array = _table_defaults[table_name]
	var prefixes: Array = _table_prefixes[table_name]
	var precisions: Dictionary = _table_precisions[table_name]
	var row_name := ""
	if has_row_names:
		if prefixes[0]:
			row_name = prefixes[0] + line_array[0]
		else:
			row_name = line_array[0]
		assert(row_name, "name cell is blank!")
		if is_new:
			assert(!_enumerations.has(row_name))
			_enumerations[row_name] = row
		elif _enumerations.has(row_name): # modifying existing item
			row = _enumerations[row_name]
		else: # adding row to existing table
			row = _tables[table_name]["name"].size()
			_enumerations[row_name] = row
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
		
		# pre-process and set table value
		if raw_value.begins_with("\"") and raw_value.ends_with("\""):
			raw_value = raw_value.lstrip("\"").rstrip("\"")
		raw_value = raw_value.lstrip("'")
		raw_value = raw_value.lstrip("_")
		var value # untyped
		match type:
			"BOOL":
				if raw_value == "x" or raw_value.matchn("true"):
					value = true
				else:
					assert(raw_value == "" or raw_value.matchn("false"))
					value = false
			"STRING":
				value = raw_value.c_unescape() # does not work for "\uXXXX"; Godot issue #38716
				value = utils.c_unescape_patch(value) # handles "\uXXXX"
				if value and prefix:
					value = prefix + value
			"REAL":
				# we determine and save precision here
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
					value = float(raw_value)
					if unit:
						value = ivunits.convert_quantity(value, unit, true, true,
								_unit_multipliers, _unit_functions)
				precisions[field].append(precision)
			"INT":
				# keep as string for now, convert in _postprocess_ints()
				if raw_value and !raw_value.is_valid_integer(): # must be enumeration
					if prefix:
						value = prefix + raw_value
					else:
						value = raw_value
				else:
					value = raw_value
			_:
				assert(false)
		
		# set value
		var table_column: Array = _tables[table_name][field]
		if table_column.size() == row:
			table_column.resize(row + 1)
		table_column[row] = value
		if _enable_wiki and field == _wiki:
			_wiki_titles[row_name] = value


func _postprocess_ints() -> void:
	# convert INT strings to enumerations after all tables imported
	for table_name in _int_fields_for_postprocess:
		var table: Dictionary = _tables[table_name]
		for field in _int_fields_for_postprocess[table_name]:
			var preprocess_column: Array = table[field]
			var size := preprocess_column.size()
			var postprocess_column := [] # TODO 4.0: type this array
			postprocess_column.resize(size)
			for i in size:
				var raw_value: String = preprocess_column[i]
				var value: int
				if !raw_value:
					value = -1
				elif raw_value.is_valid_integer():
					value = int(raw_value)
				else:
					assert(_enumerations.has(raw_value), "Unknown enumeration '%s'" % raw_value)
					value = _enumerations[raw_value]
				postprocess_column[i] = value
			table[field] = postprocess_column


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
		if line.begins_with("#"):
			line = file.get_line()
			continue
		var line_array := line.split("\t") as Array
		if reading_header:
			if reading_fields: # always 1st line!
				assert(line_array[0] == "name", "1st field must be 'name'")
				for field in line_array:
					if !field.begins_with("#"):
						assert(!fields.has(field), "Duplicated field '" + field + "'")
						fields[field] = n_columns
					n_columns += 1
				reading_fields = false
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

