# table_importer.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield
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
# Reads external data tables (.csv files) and adds results to:
#    - Global.table_rows
#    - Global.wiki_titles (if Global.wiki_enabled)
#    - table containers in TableReader via init_tables()
#
# Use TableReader to interact with imported table data! This object removes
# itself from Global.program after table import. No other object should
# reference it.
#
# ivoyager/data/solar_system/*.csv table construction:
#  Data_Type (required!): X, BOOL, INT, FLOAT, STRING, ENUM, DATA, BODY
#    See tables for examples; see TableReader for conversions.
#  Default (optional; all types except X): If cell is blank, it will be
#    replaced with this value.
#  Units (optional; REAL only!). Reals will be converted from provided units
#    symbol. The symbol must be present in UnitDefs.MULTIPLIERS or FUNCTIONS or
#    replacement dicts specified in Global.unit_multipliers, .unit_functions.

class_name TableImporter

const unit_defs := preload("res://ivoyager/static/unit_defs.gd")
const math := preload("res://ivoyager/static/math.gd")

const DPRINT := false
const DATA_TYPES := ["REAL", "BOOL", "X", "INT", "STRING", "BODY", "DATA"] # & enum names

# source files
var _table_import: Dictionary = Global.table_import
var _wiki_only: Array = Global.table_import_wiki_only
# imported data
var _table_data := {}
var _table_fields := {}
var _table_data_types := {}
var _table_units := {}
var _table_row_dicts := {}
var _table_rows: Dictionary = Global.table_rows # Global shared
var _wiki_titles: Dictionary = Global.wiki_titles # Global shared
var _value_indexes := {"" : 0} # preloaded 0-index is null value
var _values := [""]
# localization
var _enable_wiki: bool = Global.enable_wiki
var _enums: Script = Global.enums
# current processing
var _path: String
var _data: Array
var _fields: Dictionary
var _rows: Dictionary
var _data_types: Array
var _units: Array
var _defaults: Array
var _line_array: Array
var _row_name: String
var _field: String
var _cell: String
var _count := 0

func _init():
	var start_time := OS.get_system_time_msecs()
	_import()
	var time := OS.get_system_time_msecs() - start_time
	print("Imported %s table values (%s unique) in %s msec" % [_count, _values.size(), time])

func _project_init() -> void:
	var table_reader: TableReader = Global.program.TableReader
	table_reader.init_tables(_table_data, _table_fields, _table_data_types, _table_units, 
			_table_row_dicts, _values)
	Global.program.erase("TableImporter") # this Reference will free itself

func _import() -> void: # this and below on I/O thread!
	if _enable_wiki:
		for path in _wiki_only:
			_path = path
			_data = []
			_fields = {}
			_data_types = []
			_rows = {}
			_read_table() # writes wiki_titles; we don't keep data, fields, rows
	for table_name in _table_import:
		_path = _table_import[table_name]
		_data = []
		_fields = {} # column index by field name
		_data_types = []
		_rows = {} # row index by name
		_read_table()
		# wiki_titles was populated on the fly (if Global.enable_wiki); but we
		# save everything else to Global dicts below
		_table_data[table_name] = _data
		_table_fields[table_name] = _fields
		_table_data_types[table_name] = _data_types
		_table_units[table_name] = _units
		_table_row_dicts[table_name] = _rows
		for row_name in _rows:
			assert(!_table_rows.has(row_name))
			_table_rows[row_name] = _rows[row_name]

func _read_table() -> void:
	assert(DPRINT and prints("Reading", _path) or true)
	var file := File.new()
	if file.open(_path, file.READ) != OK:
		print("ERROR: Could not open file: ", _path)
		assert(false)
	var delimiter := "," if _path.ends_with(".csv") else "\t" # legacy project support; use *.csv
	_units = []
	_defaults = []
	var have_fields := false
	var reading_data := false
	var n_columns := 0
	var line := file.get_line()
	while !file.eof_reached():
		var commenter := line.find("#")
		if commenter != -1 and commenter < 4: # skip comment line
			line = file.get_line()
			continue
		_line_array = Array(line.split(delimiter, true))
		if !reading_data:
			if !have_fields: # always 1st line!
				assert(_line_array[0] == "name", "1st field must be 'name'")
				for field in _line_array:
					if field == "Comments":
						break
					_fields[field] = n_columns
					n_columns += 1
				have_fields = true
				assert(n_columns == _fields.size(), "Columns: %s, unique fields: %s; duplicate? %s" \
						% [n_columns, _fields.size(), _path])
			elif _line_array[0] == "DataType":
				_data_types = _line_array
				_data_types[0] = "STRING" # always name field
				_data_types.resize(n_columns) # there could be an extra comment column
				assert(_data_type_test())
			elif _line_array[0] == "Units":
				_units = _line_array
				_units[0] = ""
				_units.resize(n_columns)
				assert(_unit_test())
			elif _line_array[0] == "Default":
				_defaults = _line_array
				_defaults[0] = ""
				_defaults.resize(n_columns)
				var i := 0
				while i < n_columns:
					if _defaults[i]:
						_defaults[i] = _get_processed_value(_defaults[i])
					i += 1
			else:
				assert(_data_types) # required
				if !_units:
					for _i in range(n_columns):
						_units.append("")
				if !_defaults:
					for _i in range(n_columns):
						_defaults.append("")
				assert(_table_test(n_columns))
				reading_data = true
		if reading_data:
			_read_data_line()
		line = file.get_line()

func _read_data_line() -> void:
	# We do minimal value modification here:
	#   - Strip enclosing quotes
	#   - Strip leanding underscore
	#   - c_unescape()
	# But we do some asserts for DataType.
	var row := _data.size()
	var row_data := []
	row_data.resize(_fields.size()) # unfilled row_data are nulls
	_row_name = _line_array[0]
	assert(!_rows.has(_row_name))
	_rows[_row_name] = row
	for field in _fields:
		_field = field
		var column: int = _fields[_field]
		_cell = _get_processed_value(_line_array[column])
		if !_cell: # set to default
			_cell = _defaults[column]
		if !_cell:
			row_data[column] = 0
			continue
		assert(_cell_test(column))
		# value is stored as index for each unique cell value
		if _value_indexes.has(_cell):
			row_data[column] = _value_indexes[_cell]
		else:
			var index := _values.size()
			_values.append(_cell)
			_value_indexes[_cell] = index
			row_data[column] = index
		if _enable_wiki and _field == "wiki_en": # TODO: non-English Wikipedias
			assert(!_wiki_titles.has(_row_name))
			_wiki_titles[_row_name] = _cell
		_count += 1
	_data.append(row_data)

func _get_processed_value(value: String) -> String:
	if value.begins_with("\"") and value.ends_with("\""): # whole cell quoted
		value = value.substr(1, value.length() - 2)
	value = value.lstrip("_")
	value = value.c_unescape() # does not work for "\u"; Godot issue #38716
	value = StrUtils.c_unescape_patch(value)
	return value

func _data_type_test() -> bool:
	for data_type in _data_types:
		assert(DATA_TYPES.has(data_type) or data_type in _enums, "Unknown DataType: " + data_type)
	return true

func _unit_test() -> bool:
	for unit in _units:
		if unit:
			assert(unit_defs.is_valid_unit(unit, true, Global.unit_multipliers, Global.unit_functions),
					"Unkown unit " + unit)
	return true

func _table_test(n_columns: int) -> bool:
	for column in range(n_columns):
		var data_type: String = _data_types[column]
		match data_type:
			"X":
				assert(!_defaults[column], "Expected no Default for X type")
				assert(!_units[column], "Expected no Units for X type")
			"BOOL":
				assert(!_units[column], "Expected no Units for BOOL")
			"INT":
				assert(!_units[column], "Expected no Units for INT")
			"REAL":
				pass
			"STRING", "DATA", "BODY":
				assert(!_units[column], "Expected no Units for " + data_type)
			_: # must be valid enum name
				assert(!_units or !_units[column], "Expected no Units for " + data_type)
				assert(data_type in _enums, "Non-existent enum dict " + data_type)
	return true

func _cell_test(column: int) -> bool:
	var data_type: String = _data_types[column]
	match data_type:
		"X":
			assert(_cell == "x" or _line_error("X type must be x or blank cell"))
		"BOOL":
			assert(_cell.matchn("true") or _cell.matchn("false") or _line_error("Expected BOOL"))
		"INT":
			assert(_cell.is_valid_integer() or _line_error("Expected INT"))
		"REAL":
			assert(_cell.replace("E", "e").is_valid_float() or _line_error("Expected REAL"))
		"STRING", "DATA", "BODY":
			pass
		_: # must be valid enum name
			assert(_enums[data_type].has(_cell) or _line_error("Non-existent enum value " + _cell))
	return true

func _line_error(msg := "") -> bool:
	print("ERROR in _read_data_line...")
	if msg:
		print(msg)
	print("cell value: ", _cell)
	print("row name   : ", _row_name)
	print("field     : ", _field)
	print(_path)
	return false

