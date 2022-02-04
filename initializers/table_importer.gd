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

# Reads external data tables (.tsv files) and adds results to:
#    - IVGlobal.table_rows
#    - IVGlobal.wiki_titles (if IVGlobal.wiki_enabled)
#    - table containers in IVTableReader
#
# Use IVTableReader to interact with imported table data! This object removes
# itself from IVGlobal.program after table import. No other object should
# reference it.
#
# ivoyager/data/solar_system/*.tsv table construction:
#  Data_Type (required!): X, BOOL, INT, FLOAT, STRING, ENUM, TABLE_ROW, BODY
#    See tables for examples; see IVTableReader for conversions.
#  Default (optional; all types except X): If cell is blank, it will be
#    replaced with this value.
#  Units (optional; REAL only!). Reals will be converted from provided units
#    symbol. The symbol must be present in IVUnits.MULTIPLIERS or FUNCTIONS or
#    replacement dicts specified in IVGlobal.unit_multipliers, .unit_functions.
#
# False is represented internally as "", so bool(internal_value) will give
# meaningful result for both BOOL and X type.

const units := preload("res://ivoyager/static/units.gd")
const math := preload("res://ivoyager/static/math.gd")

const DPRINT := false
const DATA_TYPES := ["REAL", "BOOL", "X", "INT", "STRING", "BODY", "TABLE_ROW"] # & enum names

# source files
var _table_import: Dictionary = IVGlobal.table_import
var _wiki_titles_import: Array = IVGlobal.wiki_titles_import
# imported data
var _table_data := {}
var _table_fields := {}
var _table_data_types := {}
var _table_units := {}
var _table_row_dicts := {}
var _table_rows: Dictionary = IVGlobal.table_rows # IVGlobal shared
var _wiki_titles: Dictionary = IVGlobal.wiki_titles # IVGlobal shared
var _unique_register := {}

# localization
var _enable_wiki: bool = IVGlobal.enable_wiki
var _enums: Script = IVGlobal.enums
var _wiki: String = IVGlobal.wiki # wiki column header

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
var _data_type: String
var _cell: String
var _count_rows := 0
var _count_cells := 0
var _count_non_null := 0


func _init():
	_on_init()


func _on_init() -> void:
	var start_time := OS.get_system_time_msecs()
	_import()
	var time := OS.get_system_time_msecs() - start_time
	print("Imported tables in %s msec; %s rows; %s cells (%s non-null; %s unique)" \
			% [time, _count_rows, _count_cells, _count_non_null, _unique_register.size()])


func _project_init() -> void:
	var table_reader: IVTableReader = IVGlobal.program.TableReader
	table_reader.init_tables(_table_data, _table_fields, _table_data_types, _table_units, _table_row_dicts)
	IVGlobal.program.erase("TableImporter") # frees self


func _import() -> void:
	for table_name in _table_import:
		_path = _table_import[table_name]
		_data = []
		_fields = {} # column index by field name
		_data_types = []
		_rows = {} # row index by name
		_read_table()
		# wiki_titles was populated on the fly (if IVGlobal.enable_wiki); but we
		# save everything else to IVGlobal dicts below
		_table_data[table_name] = _data
		_table_fields[table_name] = _fields
		for i in range(_data_types.size()):
			if _data_types[i] == "X":
				_data_types[i] = "BOOL"
		_table_data_types[table_name] = _data_types
		_table_units[table_name] = _units
		_table_row_dicts[table_name] = _rows
		for row_name in _rows:
			assert(!_table_rows.has(row_name))
			_table_rows[row_name] = _rows[row_name]
	if !_enable_wiki:
		return
	_data = []
	_fields = {}
	_data_types = []
	_rows = {}
	for path in _wiki_titles_import:
		_path = path
		_read_table() # writes wiki_titles; we don't keep anything else
		_data.clear()
		_fields.clear()
		_data_types.clear()
		_rows.clear()


func _read_table() -> void:
	assert(DPRINT and prints("Reading", _path) or true)
	var file := File.new()
	if file.open(_path, file.READ) != OK:
		assert(false, "Could not open file: " +  _path)
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
		_line_array = line.split("\t")
		if !reading_data:
			if !have_fields: # always 1st line!
				assert(_line_array[0] == "name", "1st field must be 'name'")
				for field in _line_array:
					if field == "Comments":
						break
					_fields[field] = n_columns
					n_columns += 1
				have_fields = true
				assert(n_columns == _fields.size(), "Duplicate field (%s columns, %s unique fields) in %s" \
						% [n_columns, _fields.size(), _path])
			elif _line_array[0] == "Type":
				_data_types = _line_array.duplicate()
				_data_types[0] = "STRING" # always name field
				_data_types.resize(n_columns) # truncate Comment column
				assert(_data_types_test())
			elif _line_array[0] == "Units":
				_units = _line_array.duplicate()
				_units[0] = ""
				_units.resize(n_columns) # truncate Comment column
				assert(_units_test())
			elif _line_array[0] == "Default":
				_defaults = _line_array.duplicate()
				_defaults[0] = ""
				_defaults.resize(n_columns) # truncate Comment column
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
	var row := _data.size()
	var row_data := []
	row_data.resize(_fields.size()) # unfilled row_data are nulls
	_row_name = _line_array[0]
	assert(_row_name, "name cell is blank!")
	assert(!_rows.has(_row_name), "name is already used in this or another table!")
	_rows[_row_name] = row
	for field in _fields:
		_count_cells += 1
		_field = field
		var column: int = _fields[_field]
		_cell = _line_array[column]
		_data_type = _data_types[column]
		if !_cell: # set to default
			_cell = _defaults[column]
		_process_cell_value()
		if !_cell:
			row_data[column] = ""
			continue
		assert(_cell_test())
		row_data[column] = _cell
		_unique_register[_cell] = null
		if _enable_wiki and _field == _wiki:
			_wiki_titles[_row_name] = _cell
		_count_non_null += 1
	_data.append(row_data)
	_count_rows += 1


func _process_cell_value() -> void:
	if _cell.begins_with("\"") and _cell.ends_with("\""):
		_cell = _cell.lstrip("\"").rstrip("\"")
	_cell = _cell.lstrip("'")
	_cell = _cell.lstrip("_")
	if _data_type == "BOOL":
		_cell = _cell.to_lower()
	elif _data_type == "X":
		if _cell == "x":
			_cell = "true"
	elif _data_type == "REAL":
		_cell = _cell.replace("E", "e")
	elif _data_type == "STRING":
		_cell = _cell.c_unescape() # does not work for "\uXXXX"; Godot issue #38716
		_cell = IVUtils.c_unescape_patch(_cell) # handles "\uXXXX"


func _data_types_test() -> bool:
	for data_type in _data_types:
		assert(DATA_TYPES.has(data_type) or data_type in _enums, "Unknown Type: " + data_type)
	return true


func _units_test() -> bool:
	for unit in _units:
		if unit:
			assert(units.is_valid_unit(unit, true, IVGlobal.unit_multipliers, IVGlobal.unit_functions),
					"Unkown unit '" + unit + "' in " + _path)
	return true


func _table_test(n_columns: int) -> bool:
	for column in range(n_columns):
		var data_type: String = _data_types[column]
		match data_type:
			"BOOL":
				assert(!_units[column], "Expected no Units for BOOL in" + _path)
			"X":
				assert(!_defaults[column], "Expected no Default for X type in" + _path)
				assert(!_units[column], "Expected no Units for X type in" + _path)
			"INT":
				assert(!_units[column], "Expected no Units for INT in" + _path)
			"REAL":
				pass
			"STRING", "TABLE_ROW", "BODY":
				assert(!_units[column], "Expected no Units for " + data_type + " in " + _path)
			_: # must be valid enum name
				assert(!_units or !_units[column], "Expected no Units for " + data_type + " in " + _path)
				assert(data_type in _enums, "Non-existent enum dict '" + data_type + "' in " + _path)
	return true


func _cell_test() -> bool:
	# "" is always ok and not checked here; _process_cell_value() has already
	# processed table values to our internal format (e.g., REAL "E" -> "e").
	match _data_type:
		"BOOL":
			assert(_cell == "true" or _cell == "false" or _line_error("Expected BOOL"))
		"X":
			assert(_cell == "true" or _line_error("X type must be x or blank cell"))
		"INT":
			assert(_cell.is_valid_integer() or _line_error("Expected INT"))
		"REAL":
			var real := _cell.lstrip("~")
			assert(real == "?" or real.is_valid_float() or _line_error("Expected REAL"))
		"STRING", "TABLE_ROW", "BODY":
			pass
		_: # must be valid enum name
			assert(_enums[_data_type].has(_cell) or _line_error("Non-existent enum value " + _cell))
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
