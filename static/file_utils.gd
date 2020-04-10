# file_utils.gd
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
# Usage note: issue #37529 prevents localization of global class_name to const.
# For now, use:
# const file_utils := preload("res://ivoyager/static/file_utils.gd")

class_name FileUtils

static func get_save_dir_path(is_modded: bool, override_dir: String = "") -> String:
	var save_dir := override_dir
	if save_dir:
		if is_modded:
			if !save_dir.ends_with("/modded_saves"):
				save_dir = ""
		else:
			if !save_dir.ends_with("/unmodded_saves"):
				save_dir = ""
	if save_dir:
		var dir := Directory.new()
		if dir.open(save_dir) != OK:
			save_dir = ""
	if save_dir == "":
		save_dir = OS.get_user_data_dir() + "/saves"
		save_dir += "/modded_saves" if is_modded else "/unmodded_saves"
		make_dir_if_doesnt_exist(save_dir)
	return save_dir

static func get_base_file_name(file_name : String) -> String:
	# Strips file type and date extensions
	file_name = file_name.replace("." + Global.save_file_extension, "")
	var regex := RegEx.new()
	regex.compile("\\.\\d+-\\d\\d-\\d\\d") # "(\.\d+-\d\d-\d\d)"
	var search_result := regex.search(file_name)
	if search_result:
		var date_extension := search_result.get_string()
		file_name = file_name.replace(date_extension, "")
	return file_name

static func get_save_path(save_dir: String, base_name: String, date_string := "", append_file_extension := false) -> String:
	var path := save_dir.plus_file(base_name)
	if date_string:
		path += "." + date_string
	if append_file_extension:
		path += "." + Global.save_file_extension
	return path

static func exists(file_path: String) -> bool:
	var file := File.new()
	if file_path.ends_with(".gd"):
		# export changes ".gd" to ".gdc"
		return file.file_exists(file_path) or file.file_exists(file_path + "c")
	return file.file_exists(file_path)

static func is_valid_dir(dir_path: String) -> bool:
	if dir_path == "":
		return false
	var dir := Directory.new()
	return dir.open(dir_path) == OK

static func make_dir_if_doesnt_exist(dir_path: String, recursive := true) -> void:
	var dir := Directory.new()
	if !dir.dir_exists(dir_path):
		if recursive:
			dir.make_dir_recursive(dir_path)
		else:
			dir.make_dir(dir_path)

static func make_or_clear_dir(dir_path: String) -> void:
	var dir := Directory.new()
	if dir.dir_exists(dir_path):
		assert(dir.open(dir_path) == OK)
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name:
			if !dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
	else:
		dir.make_dir(dir_path)

# loading assets & data files

static func find_resource_file(dir_path: String, file_prefix: String) -> String:
	# Searches for file in the given directory path that begins with file_prefix
	# followed by dot. Returns resource file if it exists. We expect to
	# find file with .import extension (this is the ONLY file in an exported
	# project), but ".import" must be removed from end to load it.
	file_prefix = file_prefix + "."
	var dir := Directory.new()
	if dir.open(dir_path) != OK:
		print("ERROR: Could not access directory: ", dir_path)
		return ""
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name:
		if !dir.current_is_dir():
			if file_name.begins_with(file_prefix):
				if file_name.get_extension() == "import":
					return dir_path.plus_file(file_name).get_basename()
		file_name = dir.get_next()
	return ""

static func find_resource(dir_path: String, file_prefix: String) -> Resource:
	var path := find_resource_file(dir_path, file_prefix)
	if path:
		return load(path)
	return null

static func get_scale_from_file_path(path: String) -> float:
	# File name ending in _1_1000 is scaled 1 length unit / 1000 m.
	var split := path.get_basename().split("_")
	if split.size() < 2:
		return 1.0
	var numerator: String = split[-2]
	if !numerator.is_valid_integer():
		return 1.0
	var denominator: String = split[-1]
	if !denominator.is_valid_integer():
		return 1.0
	return float(numerator) / float(denominator)

static func apply_escape_characters(string: String) -> String:
	string = string.replace("\\n", "\n")
	string = string.replace("\\t", "\t")
	return string
