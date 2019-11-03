# file_helper.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2019 Charlie Whitfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# *****************************************************************************
#

extends Reference
class_name FileHelper

static func make_object_or_scene(script: Script) -> Object:
	if not "SCENE" in script and not "SCENE_OVERRIDE" in script:
		return script.new()
	# It's a scene if the script or an extended script has member "SCENE" or
	# "SCENE_OVERRIDE". We create the scene and return the root node.
	var scene_path: String = script.SCENE_OVERRIDE if "SCENE_OVERRIDE" in script else script.SCENE
	var pkd_scene: PackedScene = load(scene_path)
	var root_node: Node = pkd_scene.instance()
	if root_node.script != script: # root_node.script may be parent class
		root_node.set_script(script)
	return root_node

static func make_or_get_child_node(parent: Node, script: Script) -> Node:
	for child in parent.get_children():
		if child is script:
			return child
	var new_child = make_object_or_scene(script)
	parent.add_child(new_child)
	return new_child

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

static func exists(file_path : String) -> bool:
	var file := File.new()
	return file.file_exists(file_path)

static func is_valid_dir(dir_path : String) -> bool:
	if dir_path == "":
		return false
	var dir := Directory.new()
	return dir.open(dir_path) == OK

static func make_dir_if_doesnt_exist(dir_path : String, recursive := true) -> void:
	var dir := Directory.new()
	if !dir.dir_exists(dir_path):
		if recursive:
			dir.make_dir_recursive(dir_path)
		else:
			dir.make_dir(dir_path)

static func make_or_clear_dir(dir_path : String) -> void:
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

static func find_resource(dir_path : String, file_prefix : String) -> Resource:
	# Searches for file in the given directory path that begins with file_prefix
	# followed by dot. Returns loaded file resource if it exists. We expect to
	# find file with .import extension (this is the *only* file in exported
	# project), but ".import" must be removed from end to load it.
	file_prefix = file_prefix + "."
	var dir := Directory.new()
	if dir.open(dir_path) != OK:
		print("ERROR: Could not access directory: ", dir_path)
		return null
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name:
		if !dir.current_is_dir():
			if file_name.begins_with(file_prefix):
				if file_name.get_extension() == "import":
					return load(dir_path.plus_file(file_name).get_basename())
		file_name = dir.get_next()
	return null

static func apply_escape_characters(string: String) -> String:
	string = string.replace("\\n", "\n")
	string = string.replace("\\t", "\t")
	return string


func project_init():
	pass
