# table_reader.gd
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
# Reads external data tables (.csv files) and adds results to:
#    Global.table_data
#    Global.table_fields
#    Global.table_rows
#    Global.wiki_titles (if Global.wiki_enabled)
#
# ivoyager/data/solar_system/*.csv table construction:
#  Data_Type (required!): X, BOOL, INT, FLOAT, STRING. X-type will be
#    converted to true (x) or false (blank). For all others, a blank cell
#    without Defaults value will be converted to null (we use this to test
#    for missing values!). BOOL is case insensitive. FLOAT converts "E" to
#    "e" before attempting type cast.
#  Default (optional; all types except X): If cell is blank, it will be
#    replaced with this value.
#  Units (optional; REAL only!). Reals will be converted from provided units
#    symbol. The symbol must be present in UnitDefs.MULTIPLIERS or FUNCTIONS.

extends Reference
class_name TableReader

const unit_defs := preload("res://ivoyager/static/unit_defs.gd")

const DPRINT := false
const DATA_TYPES := ["REAL", "BOOL", "X", "INT", "STRING", "BODY", "TABLE"] # & enum names


# project vars
var import := {
	stars = "res://ivoyager/data/solar_system/stars.csv",
	planets = "res://ivoyager/data/solar_system/planets.csv",
	moons = "res://ivoyager/data/solar_system/moons.csv",
	lights = "res://ivoyager/data/solar_system/lights.csv",
	asteroid_groups = "res://ivoyager/data/solar_system/asteroid_groups.csv",
	classes = "res://ivoyager/data/solar_system/classes.csv",
	models = "res://ivoyager/data/solar_system/models.csv",
}
var wiki_extras := ["res://ivoyager/data/solar_system/wiki_extras.csv"]

# global dicts & project values
var _table_data: Dictionary = Global.table_data
var _table_fields: Dictionary = Global.table_fields
var _table_data_types: Dictionary = Global.table_data_types
var _table_rows: Dictionary = Global.table_rows
var _wiki_titles: Dictionary = Global.wiki_titles
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
var _row_key: String
var _field: String
var _cell: String


func project_init():
	pass

func import_table_data():
	print("Reading external data tables...")
	if _enable_wiki:
		for path in wiki_extras:
			_path = path
			_data = []
			_fields = {}
			_data_types = []
			_rows = {}
			_read_table() # writes wiki_titles; we don't keep data, fields, rows
	for key in import:
		_path = import[key]
		_data = []
		_fields = {} # column index by field name
		_data_types = []
		_rows = {} # row index by item key
		_read_table()
		# wiki_titles was populated on the fly (if Global.enable_wiki); but we
		# save everything else to Global dicts below
		_table_data[key] = _data
		_table_fields[key] = _fields
		_table_data_types[key] = _data_types
		_table_rows[key] = _rows
		for item_key in _rows:
			assert(!_table_rows.has(item_key))
			_table_rows[item_key] = _rows[item_key]

func _read_table() -> void:
	assert(DPRINT and prints("Reading", _path) or true)
	var file := File.new()
	if file.open(_path, file.READ) != OK:
		print("ERROR: Could not open file: ", _path)
		assert(false)
	var delimiter := "," if _path.ends_with(".csv") else "\t" # legacy project support; use *.csv
	_units = []
	_defaults = []
	var is_1st_line := true
	var line := file.get_line()
	while !file.eof_reached():
		var commenter := line.find("#")
		if commenter != -1 and commenter < 4: # skip comment line
			line = file.get_line()
			continue
		_line_array = Array(line.split(delimiter, true))
		if is_1st_line:
			_read_fields_line() # always the 1st non-comment line
			is_1st_line = false
		elif _line_array[0] == "DataType":
			_read_data_types_line()
		elif _line_array[0] == "Units":
			_units = _line_array
		elif _line_array[0] == "Default":
			_defaults = _line_array
		else:
			assert(_data_types) # required; Units & Defaults lines are optional
			_read_data_line()
		line = file.get_line()

func _read_fields_line() -> void:
	assert(_line_array[0] == "key", "1st field must be 'key'")
	var column := 0
	for field in _line_array:
		if field == "Comments":
			break
		_fields[field] = column
		column += 1

func _read_data_types_line() -> void:
	_data_types = _line_array
	_data_types[0] = "STRING" # always key field
	_data_types.resize(_fields.size()) # there could be an extra comment column
	for data_type in _data_types:
		assert(DATA_TYPES.has(data_type) or data_type in _enums, "Unknown DataType: " + data_type)

func _read_data_line() -> void:
	var row := _data.size()
	var row_data := []
	row_data.resize(_fields.size()) # unfilled row_data are nulls
	_row_key = _line_array[0]
	assert(!_rows.has(_row_key))
	_rows[_row_key] = row
	row_data[0] = _row_key
	for field in _fields:
		_field = field
		if _field == "key":
			continue
		var column: int = _fields[_field]
		_cell = _line_array[column]
		if !_cell and _defaults and _defaults[column]: # impute default
			_cell = _defaults[column]
		var data_type: String = _data_types[column]
		if !_cell: # for all types excpet "X", blank cell w/out default is null!
			if data_type == "X":
				row_data[column] = false
			continue
		match data_type:
			"X":
				assert(!_defaults or !_defaults[column] or _line_error("Expected no Default for X type"))
				assert(!_units or !_units[column] or _line_error("Expected no Units for X type"))
				assert(_cell == "x" or _line_error("X type must be x or blank cell"))
				row_data[column] = true
			"BOOL":
				assert(!_units or !_units[column] or _line_error("Expected no Units for BOOL"))
				if _cell.matchn("true"): # case insensitive
					row_data[column] = true
				else:
					assert(_cell.matchn("false") or _line_error("Expected BOOL (true/false)"))
					row_data[column] = false
			"INT":
				assert(!_units or !_units[column] or _line_error("Expected no Units for INT"))
				assert(_cell.is_valid_integer() or _line_error("Expected INT"))
				row_data[column] = int(_cell)
			"REAL":
				_cell = _cell.replace("E", "e")
				assert(_cell.is_valid_float() or _line_error("Expected REAL"))
				var real := float(_cell)
				if _units and _units[column]:
					var unit: String = _units[column]
					real = unit_defs.conv(real, unit, false, true)
				row_data[column] = real
			_: # store as string
				assert(!_units or !_units[column] or _line_error(
						"Expected no Units for " + data_type))
				if _cell.begins_with("\"") and _cell.ends_with("\""): # strip quotes
					_cell = _cell.substr(1, _cell.length() - 2)
				row_data[column] = _cell
				if _enable_wiki and _field == "wiki_en": # TODO: non-English Wikipedias
					assert(!_wiki_titles.has(_row_key))
					_wiki_titles[_row_key] = _cell
	_data.append(row_data)

func _line_error(msg := "") -> bool:
	print("ERROR in _read_data_line...")
	if msg:
		print(msg)
	print("cell value: ", _cell)
	print("row key   : ", _row_key)
	print("field     : ", _field)
	print(_path)
	return false

