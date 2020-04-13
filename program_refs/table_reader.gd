# table_reader.gd
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
# Reads external data tables (csv files) and adds data to Global.tables and
# table_types. Global.table_types holds row number for all individual table
# keys and an enum-like dict for each table (e.g., PlanetTypes, MoonTypes,
# etc.).
#
# Table construction:
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

enum { # str_type
	AS_ENUM,
	AS_TYPE,
	AS_BODY
}
const EMPTY_ARRAY := []
const EMPTY_DICT := {}

var import := {
	# data_name = [type_name, path]
	# if type_name != "" then row keys and type dicts added to Global.table_types
	StarData = ["StarTypes", "StarFields", "res://ivoyager/data/solar_system/star_data.csv"],
	PlanetData = ["PlanetTypes", "PlanetFields", "res://ivoyager/data/solar_system/planet_data.csv"],
	MoonData = ["MoonTypes", "MoonFields", "res://ivoyager/data/solar_system/moon_data.csv"],
	AsteroidGroupData = ["AsteroidGroupTypes", "AsteroidGroupFields",
		"res://ivoyager/data/solar_system/asteroid_group_data.csv"],
	BodyData = ["BodyTypes", "BodyFields", "res://ivoyager/data/solar_system/body_data.csv"],
	StarlightData = ["StarlightTypes", "StarlightFields",
		"res://ivoyager/data/solar_system/starlight_data.csv"],
	WikiExtras = ["", "", "res://ivoyager/data/solar_system/wiki_extras.csv"],
	}

var import2 := {
#	star_data = ["StarTypes", "res://ivoyager/data/solar_system/star_data.csv"],
#	planet_data = ["PlanetTypes", "res://ivoyager/data/solar_system/planet_data.csv"],
#	moon_data = ["MoonTypes", "res://ivoyager/data/solar_system/moon_data.csv"],
#	asteroid_group_data = ["AsteroidGroupTypes", "res://ivoyager/data/solar_system/asteroid_group_data.csv"],
#	body_data = ["BodyTypes", "res://ivoyager/data/solar_system/body_data.csv"],
#	starlight_data = ["StarlightTypes", "res://ivoyager/data/solar_system/starlight_data.csv"],
#	wiki_extra_titles = ["", "res://ivoyager/data/solar_system/wiki_extra_titles.csv"],
}

# global dicts
var _tables: Dictionary = Global.tables
var _table_types: Dictionary = Global.table_types
var _wiki_titles: Dictionary = Global.wiki_titles

# current processing
var _path: String
var _data: Array
var _types: Dictionary
var _fields: Dictionary
var _data_types: Array
var _units: Array
var _defaults: Array
var _line_array: Array
var _row_key: String
var _field: String
var _cell: String

func project_init():
	pass

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

func import_table_data():
	print("Reading external data tables...")
	for data_name in import:
		var import_array: Array = import[data_name]
		var types_name: String = import_array[0]
		var fields_name: String = import_array[1]
		_path = import_array[2]
		_data = []
		_types = {} # row index by item key
		_fields = {} # column index by field name
		_read_table()
		# Global dict _wiki_titles was populated on the fly; otherwise, all
		# global dicts are populated bellow...
		_tables[data_name] = _data
		if types_name:
			assert(!_table_types.has(types_name))
			_table_types[types_name] = _types
			for key in _types:
				assert(!_table_types.has(key))
				_table_types[key] = _types[key]
		if fields_name:
			assert(!_tables.has(fields_name))
			_tables[fields_name] = _fields
			
				
	# REMOVING...
	for data_name in import2:
		var info: Array = import2[data_name]
		var type_name: String = info[0]
		var path: String = info[1]
		var data := []
		var type_dict := {}
		_read_data_file(data, type_dict, path)
		_tables[data_name] = data
		if type_name:
			assert(!_table_types.has(type_name))
			_table_types[type_name] = type_dict
			for key in type_dict:
				assert(!_table_types.has(key))
				_table_types[key] = type_dict[key]


func _read_table() -> void:
	assert(DPRINT and prints("Reading", _path) or true)
	var file := File.new()
	if file.open(_path, file.READ) != OK:
		print("ERROR: Could not open file: ", _path)
		assert(false)
	var delimiter := "," if _path.ends_with(".csv") else "\t" # legacy project support; use *.csv
	var is_fields_line := true
	_data_types = []
	_units = []
	_defaults = []
	var line := file.get_line()
	while !file.eof_reached():
		var commenter := line.find("#")
		if commenter != -1 and commenter < 4: # skip comment line
			line = file.get_line()
			continue
		_line_array = Array(line.split(delimiter, true))
		if is_fields_line: # always the 1st non-comment line
			_read_fields_line()
			is_fields_line = false
		elif _line_array[0] == "Data_Type":
			_data_types = _line_array
		elif _line_array[0] == "Units":
			_units = _line_array
		elif _line_array[0] == "Defaults":
			_defaults = _line_array
		else:
			assert(_data_types) # required; Units & Defaults lines are optional
			_read_data_line()
		line = file.get_line()

func _read_fields_line() -> void:
	assert(_line_array[0] == "key") # fields[0] is always key!
	var column := 0
	for field in _line_array:
		if field == "Comments":
			break
		_fields[field] = column
		column += 1

func _read_data_line() -> void:
	var row := _data.size()
	var row_data := []
	row_data.resize(_fields.size())
	_row_key = _line_array[0]
	assert(!_types.has(_row_key))
	_types[_row_key] = row
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
			"STRING":
				assert(!_units or !_units[column] or _line_error("Expected no Units for STRING"))
				if _cell.begins_with("\"") and _cell.ends_with("\""): # strip quotes
					_cell = _cell.substr(1, _cell.length() - 2)
				row_data[column] = _cell
				if _field == "wiki_en": # TODO: non-English Wikipedias
					assert(!_wiki_titles.has(_row_key))
					_wiki_titles[_row_key] = _cell
	_data.append(row_data)
#	print(row_data)

func _line_error(msg := "") -> bool:
	print("ERROR in _read_data_line...")
	if msg:
		print(msg)
	print("cell value: ", _cell)
	print("row key   : ", _row_key)
	print("field     : ", _field)
	print(_path)
	return false


# REMOVING...
func _read_data_file(data_array: Array, type_dict: Dictionary, path: String) -> void:
	assert(DPRINT and prints("Reading", path) or true)
	var file := File.new()
	if file.open(path, file.READ) != OK:
		print("ERROR: Could not open file: ", path)
		assert(false)
	var delimiter := "," if path.ends_with(".csv") else "\t" # legacy project support; use *.csv
	var is_header_line := true
	var headers : Array
	var data_types : Array
	var units : Array
	var defaults := {}
	var row_count := 0
	var line := file.get_line()
	while !file.eof_reached():
		var commenter := line.find("#")
		if commenter != -1 and commenter < 4:
			line = file.get_line()
			continue
		var line_array := Array(line.split(delimiter, true))
		
		# Store the header line
		if is_header_line:
			headers = line_array
			is_header_line = false

		# Store the data types
		elif line_array[0] == "Data_Type":
			data_types = line_array
#
		# Store units, if any
		elif line_array[0] == "Units":
			units = line_array

		# Handle defaults line or regular data line
		else:
			var line_dict := {}
			var is_defaults_line := false
			for i in range(headers.size()):
				var header : String = headers[i]
				if header != "Comments":
					var value : String = line_array[i]
					if i == 0:
						if header != "key":
							print("ERROR: ", path, " doesn't have \"key\" as 1st header")
							# Debug note: If you think you shouldn't be here, there is a good chance
							# there is a weird destructive character in your comments section.
							# E.g., Excel turns "..." into a sort of improvised explosive glyph.
							assert(false)
						if value == "Defaults":
							is_defaults_line = true
						else: # value is the row key
							line_dict.key = value
							type_dict[value] = row_count
								
					else: # regular data cell or default value
						var data_type = data_types[i]
						if value == "":
							if is_defaults_line or !defaults.has(header):
								pass
#								value = null # won't be entered into dictionary
							else:
								line_dict[header] = defaults[header]
						else:
							match data_type:
								"X":
									line_dict[header] = true
									if is_defaults_line:
										print("ERROR: default value for \"X\" data type must be empty cell")
										print(path)
										assert(false)
								"BOOL":
#									# Excel quotes (or something) messes up bool(value)
									if value.matchn("true"):
										line_dict[header] = true
									elif value.matchn("false"):
										line_dict[header] = false
									else:
										assert(false)
								"INT":
									line_dict[header] = int(value)
								"REAL":
									var real := float(value)
									if units and units[i]:
										var unit_symbol: String = units[i]
										line_dict[header] = unit_defs.conv(real, unit_symbol, false, true)
									else:
										line_dict[header] = real
								"STRING":
									line_dict[header] = strip_quotes(value)
								_:
									print("ERROR: Unknown data type: ", data_type)
									print(path)
									assert(false)
			
			if is_defaults_line:
				defaults = line_dict
			else:
				line_dict.type = row_count # type is row integer
				if line_dict.has("wiki_en"): # TODO: non-English Wikipedias
					_wiki_titles[line_dict.key] = line_dict.wiki_en
				# Append the completed dictionary for this item
				data_array.append(line_dict)
				row_count += 1
		line = file.get_line()

# ********************* VIRTUAL & PRIVATE FUNCTIONS ***************************

static func strip_quotes(string: String) -> String:
	if string.begins_with("\"") and string.ends_with("\""):
		return string.substr(1, string.length() - 2)
	return string


	# WIP: override base wiki text with updated text from user:// if exists.
	# Currently broken by: https://github.com/godotengine/godot/issues/16798
	# Work-around for now is to manually move wiki_text from
	# user://wiki/ivoyager_wiki_pack/ivoyager/wiki
	# to res://ivoyager/wiki
	
#	if File.new().file_exists(WIKI_OVERRIDE_PACK):
#		ProjectSettings.load_resource_pack(WIKI_OVERRIDE_PACK)
		

