# table_reader.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2019 Charlie Whitfield
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
#
# Reads external data tables (csv files) and adds data to Global.table_data and
# imported "enums" to Global.enums.

extends Reference
class_name TableReader

const DPRINT := false

enum DataTableTypes {
	DATA_TABLE_STAR,
	DATA_TABLE_PLANET,
	DATA_TABLE_MOON,
	}

# ************************** PUBLIC PROJECT VARS ******************************

var import := {
	# <Global.table_data key> = [<Global.enums key>, make_wiki_keys, path]
	# <Global.enums key> can be "" to not save the import enum.
	star_data = ["StarTypes", true, "res://ivoyager/data/solar_system/star_data.csv"],
	planet_data = ["PlanetTypes", true, "res://ivoyager/data/solar_system/planet_data.csv"],
	moon_data = ["MoonTypes", true, "res://ivoyager/data/solar_system/moon_data.csv"],
	asteroid_group_data = ["AsteroidGroupTypes", true, "res://ivoyager/data/solar_system/asteroid_group_data.csv"],
	body_data = ["BodyTypes", true, "res://ivoyager/data/solar_system/body_data.csv"],
	starlight_data = ["StarlightTypes", false, "res://ivoyager/data/solar_system/starlight_data.csv"],
	environment_data = ["", false, "res://ivoyager/data/solar_system/environment_data.csv"],
	wiki_extra_titles = ["", true, "res://ivoyager/data/solar_system/wiki_extra_titles.csv"],
	}

var wikibot_title_sources := [
	"res://ivoyager/data/solar_system/barycenter_data.csv",
	"res://ivoyager/data/solar_system/star_data.csv",
	"res://ivoyager/data/solar_system/planet_data.csv",
	"res://ivoyager/data/solar_system/moon_data.csv",
#	"res://ivoyager/data/solar_system/asteroid_data.txt",
	"res://ivoyager/data/text/wiki_extra_titles.csv",
	]

# ************************* PUBLIC READ-ONLY VARS *****************************

const WIKI_OVERRIDE_PACK := "user://wiki/ivoyager_wiki_pack.zip" # WIP
const WRITE_WIKI_BASE_TEXT := "user://wiki/ivoyager_wiki_pack/ivoyager/data/text/wiki_text.csv" # WIP
const WRITE_WIKI_EXTENDED_TEXT := "user://wiki/ivoyager_wiki_pack/ivoyager/data/text/wiki_extended_text.csv" # WIP

var _table_data: Dictionary = Global.table_data
var _enums: Dictionary = Global.enums
var _math: Math
var _wiki_keys := {} # wiki keys indexed by object keys

# **************************** PUBLIC FUNCTIONS *******************************

func import_table_data():
	print("Reading external data tables...")
	for data_name in import:
		var info: Array = import[data_name]
		var enum_name: String = info[0]
		var make_wiki_keys: bool = info[1]
		var path: String = info[2]
		var data := []
		var import_enum := {}
		_read_data_file(data, import_enum, make_wiki_keys, path)
		_table_data[data_name] = data
		if enum_name:
			assert(!_enums.has(enum_name))
			_enums[enum_name] = import_enum
			for key in import_enum:
				assert(!_enums.has(key))
				_enums[key] = import_enum[key]
	_table_data.wiki_keys = _wiki_keys

func get_wikibot_base_titles():
	var titles := {}
	for path in wikibot_title_sources:
		var data_table := []
		_read_data_file(data_table, {}, false, path)
		for data in data_table:
			if data.has("wiki_en"):
				titles[data.key] = data.wiki_en
	return titles

# DEPRECIATE - WikiBot needs a workover
func get_wikibot_extended_titles():
	var titles := {}
#	for path in extended_wiki_data_paths:
#		var data_table := _read_data_file(path)
#		for data in data_table:
#			if data.has("wiki_en"):
#				titles[data.key] = data.wiki_en
	return titles


func project_init():
	_math = Global.objects.Math

func _read_data_file(data_array: Array, import_enum: Dictionary, make_wiki_keys: bool, path: String) -> void:
	assert(DPRINT and prints("Reading", path) or true)
	var file := File.new()
	if file.open(path, file.READ) != OK:
		print("ERROR: Could not open file: ", path)
		assert(false)
	var delimiter := "," if path.ends_with(".csv") else "\t" # legacy project support; use *.csv
	var is_header_line := true
	var headers : Array
	var data_types : Array
	var unit_conversions : Array
	var default_values := {}
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
		# Store data conv, if any
		elif line_array[0] == "Unit_Conversion":
			unit_conversions = line_array

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
						if value == "Default_Value":
							is_defaults_line = true
						else:
							line_dict.key = value
							import_enum[value] = row_count
								
					else: # regular data cell or default value
						var data_type = data_types[i]
						if value == "":
							if is_defaults_line or !default_values.has(header):
								pass
#								value = null # won't be entered into dictionary
							else:
								line_dict[header] = default_values[header]
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
									line_dict[header] = float(value)
									if unit_conversions and unit_conversions[i]:
										if unit_conversions[i] == "deg2rad":
											line_dict[header] = deg2rad(float(value))
										elif unit_conversions[i] == "au2km":
											line_dict[header] = _math.au2km(float(value))
										else:
											line_dict[header] = float(value) * float(unit_conversions[i])
								"STRING":
									line_dict[header] = strip_quotes(value)
								_:
									print("ERROR: Unknown data type: ", data_type)
									print(path)
									assert(false)

			if is_defaults_line:
				default_values = line_dict
			else:
				# Add "type" field matching enum integer
				line_dict.type = row_count
				
				# Link Wiki entry if there is one
				if make_wiki_keys:
					var wiki_key = "WIKI_" + line_dict.key
					if wiki_key != tr(wiki_key): # a wiki entry exists!
						_wiki_keys[line_dict.key] = wiki_key
				
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
		

