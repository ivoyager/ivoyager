# files.gd
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
class_name IVFiles
extends Object


# TODO34: Lot of migration work...


# Usage note: issue #37529 prevents localization of global class_name to const.
# For now, use:
# const files := preload("res://ivoyager/static/files.gd")


static func make_object_or_scene(script: GDScript) -> Object:
	if not &"SCENE" in script and not &"SCENE_OVERRIDE" in script:
		return script.new()
	# It's a scene if the script or an extended script has member "SCENE" or
	# "SCENE_OVERRIDE". We create the scene and return the root node.
	@warning_ignore("unsafe_property_access")
	var scene_path: String = script.SCENE_OVERRIDE if &"SCENE_OVERRIDE" in script else script.SCENE
	var pkd_scene: PackedScene = load(scene_path)
	assert(pkd_scene, "Expected scene path at: " + scene_path)
	var root_node: Node = pkd_scene.instantiate()
	if root_node.get_script() != script: # root_node.script may be parent class
		root_node.set_script(script)
	return root_node


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
		var dir := DirAccess.open(save_dir)
		if !dir:
			save_dir = ""
	if save_dir == "":
		save_dir = OS.get_user_data_dir() + "/saves"
		save_dir += "/modded_saves" if is_modded else "/unmodded_saves"
		make_dir_if_doesnt_exist(save_dir)
	return save_dir


static func get_base_file_name(file_name : String) -> String:
	# Strips file type and date extensions
	file_name = file_name.replace("." + IVGlobal.save_file_extension, "")
	var regex := RegEx.new()
	regex.compile("\\.\\d+-\\d\\d-\\d\\d") # "(\.\d+-\d\d-\d\d)"
	var search_result := regex.search(file_name)
	if search_result:
		var date_extension := search_result.get_string()
		file_name = file_name.replace(date_extension, "")
	return file_name


static func get_save_path(save_dir: String, base_name: String, date_string := "",
		append_file_extension := false) -> String:
	var path := save_dir.path_join(base_name)
	if date_string:
		path += "." + date_string
	if append_file_extension:
		path += "." + IVGlobal.save_file_extension
	return path


static func exists(file_path: String) -> bool:
	# TEST34: If works, remove this func and use directly.
	return ResourceLoader.exists(file_path)
#	var file := File.new()
#	if file_path.ends_with(".gd"):
#		# Godot exported has ".gd" changed to ".gdc"
#		return file.file_exists(file_path) or file.file_exists(file_path + "c")
#	return file.file_exists(file_path)


static func is_valid_dir(dir_path: String) -> bool:
	# TEST34: If works, remove this func and use directly.
	return DirAccess.dir_exists_absolute(dir_path)
#	if dir_path == "":
#		return false
#	var dir := DirAccess.new()
#	return dir.open(dir_path) == OK


static func make_dir_if_doesnt_exist(dir_path: String) -> void:
	# TEST34: Do we need exists test? If not, remove this func and use directly.
	if DirAccess.dir_exists_absolute(dir_path):
		return
	DirAccess.make_dir_recursive_absolute(dir_path)
#	var dir := DirAccess.new()
#	if !dir.dir_exists(dir_path):
#		if recursive:
#			dir.make_dir_recursive(dir_path)
#		else:
#			dir.make_dir(dir_path)


static func make_or_clear_dir(dir_path: String) -> void:
	# TEST34
	if !DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
		return
	var dir := DirAccess.open(dir_path)
	dir.include_hidden = false
	dir.include_navigational = false
	dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
	var file_name := dir.get_next()
	while file_name:
		if !dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
#	var dir := DirAccess.new()
#	if dir.dir_exists(dir_path):
#		assert(dir.open(dir_path) == OK)
#		dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
#		var file_name := dir.get_next()
#		while file_name:
#			if !dir.current_is_dir():
#				dir.remove(file_name)
#			file_name = dir.get_next()
#	else:
#		dir.make_dir(dir_path)


# loading assets & data files

# TODO34: Update debug func below for 4.x
#static func get_dir_files(dir_path: String, extension := "") -> Array:
#	# No period in extension, if provided.
#	# Useful for debugging. Export removes files & changes file names!
#	var dir := DirAccess.new()
#	if dir.open(dir_path) != OK:
#		print("Could not open dir: ", dir_path)
#		return []
#	var result := []
#	dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
#	var file_name := dir.get_next()
#	while file_name:
#		if !dir.current_is_dir():
#			if !extension or file_name.get_extension() == extension:
#				result.append(file_name)
#		file_name = dir.get_next()
#	return result


static func find_resource_file(dir_paths: Array[String], prefix: String,
		search_prefix_subdirectories := true) -> String:
	# Searches for file in the given directory path that begins with file_prefix
	# followed by dot. Returns resource path if it exists. We expect to
	# find file with .import extension (this is the ONLY file in an exported
	# project!), but ".import" must be removed from end to load it.
	# Search is case-insensitive.
	
	# TEST34: Do *.import files still exist in the file system?
	
	var prefix_dot := prefix + "."
	var match_size := prefix_dot.length()
	var dir: DirAccess
	for dir_path in dir_paths:
		dir = DirAccess.open(dir_path)
		if !dir:
			continue
		dir.include_hidden = false
		dir.include_navigational = false
		dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
		var file_name := dir.get_next()
		while file_name:
			if !dir.current_is_dir():
				if file_name.get_extension() == "import":
					if file_name.substr(0, match_size).matchn(prefix_dot):
						return dir_path.path_join(file_name).get_basename()
			elif search_prefix_subdirectories:
				if file_name.matchn(prefix):
					var subdir_path: String = dir_path + "/" + file_name
					var subdir_result := find_resource_file([subdir_path], prefix, false)
					if subdir_result:
						return subdir_result
			file_name = dir.get_next()
	return ""


#	var prefix_dot := prefix + "."
#	var match_size := prefix_dot.length()
#	var dir := DirAccess.new()
#	for dir_path in dir_paths:
#		if dir.open(dir_path) != OK:
#			continue
#		dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
#		var file_name := dir.get_next()
#		while file_name:
#			if !dir.current_is_dir():
#				if file_name.get_extension() == "import":
#					if file_name.substr(0, match_size).matchn(prefix_dot):
#						return dir_path.plus_file(file_name).get_basename()
#			elif search_prefix_subdirectories:
#				if file_name.matchn(prefix):
#					var subdir_path: String = dir_path + "/" + file_name
#					var subdir_result := find_resource_file([subdir_path], prefix, false)
#					if subdir_result:
#						return subdir_result
#			file_name = dir.get_next()
#	return ""


static func find_and_load_resource(dir_paths: Array[String], prefix: String,
		search_prefix_subdirectories := true) -> Resource:
	var path := find_resource_file(dir_paths, prefix, search_prefix_subdirectories)
	if path:
		return load(path)
	return null


static func apply_escape_characters(string: String) -> String:
	string = string.replace("\\n", "\n")
	string = string.replace("\\t", "\t")
	return string

