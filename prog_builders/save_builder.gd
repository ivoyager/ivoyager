# saver_loader.gd
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
# SaveBuilder can persist specified data (which may include nested objects) and
# rebuild procedurally generated node trees and references on load. It can
# persist built-in types and four kinds of objects:
#    1. Non-procedural Nodes
#    2. Procedural Nodes (including base nodes of scenes)
#    3. Procedural References
#    4. WeakRef to any of above
# A "persist" node or reference is identified by presence of the constant:
#    const PERSIST_AS_PROCEDURAL_OBJECT: bool
# Lists of properties to persists must be named in constant arrays:
#    const PERSIST_PROPERTIES := [] # properties to persist
#    const PERSIST_PROPERTIES_2 := []
#    etc...
#    (These list names can be modified in project settings below. The extra
#    numbered lists are needed for subclasses where a list name is taken by a
#    parent class.)
# To reconstruct a scene, the base node's gdscript must have one of:
#    const SCENE: String = "<path to *.tscn>"
#    const SCENE_OVERRIDE: String # as above; override may be useful in subclass
# Additional rules for persist objects:
#    1. Nodes must be in the tree.
#    2. All ancester nodes up to "root" must also be persist nodes. ("Root" is
#        specified in function calls; it may or may not be scene tree root.)
#    3. A non-procedural node cannot be child of a procedural node.
#    4. Non-procedural nodes must have stable names (path cannot change).
#    5. Inner classes can't be persist objects
#    6. For references, PERSIST_AS_PROCEDURAL_OBJECT = true
#    7. Virtual method _init() cannot have any required args.
# Warnings:
#    1. A single table or dict persisted in two places will become two on load
#    2. Persisted strings cannot begin with object_tag.
#    3. Be careful not to have both pesist and non-persist references to the
#       same object. The old (pre-load) object will still be there in the non-
#       persist reference after load.

class_name SaveBuilder

const DPRINT := false # true for debug print
const DDPRINT := false # prints even more debug info

# debug printing/logging - these allow verbose writing to user://logs/debug.log
var debug_log_persist_nodes := false
var debug_log_all_nodes := false
var debug_print_stray_nodes := false
var debug_print_tree := false

# project settings
var progress_multiplier := 95 # so prog bar doesn't sit for a while at 100%

var properties_arrays := [
	"PERSIST_PROPERTIES",
	"PERSIST_PROPERTIES_2",
	]
var object_tag := "@!~`#" # persisted strings must not start with this!

# gamesave contents
var _gs_n_objects := 0
var _gs_serialized_nodes := []
var _gs_serialized_references := []
var _gs_script_paths := []
var _gs_dict_keys := []

# save/load processing
var _root: Node # save & load
var _ids := {} # save; keyed by objects & script paths
var _key_ids := {} # save
var _objects := [] # load
var _tag_size: int # load
var _dont_attach: bool # load
var _build_result := [] # load

# logging
var _log_count := 0
var _log_count_by_class := {}
var _log := ""


static func make_object_or_scene(script: Script) -> Object:
	if not "SCENE" in script and not "SCENE_OVERRIDE" in script:
		return script.new()
	# It's a scene if the script or an extended script has member "SCENE" or
	# "SCENE_OVERRIDE". We create the scene and return the root node.
	var scene_path: String = script.SCENE_OVERRIDE if "SCENE_OVERRIDE" in script else script.SCENE
	var pkd_scene: PackedScene = load(scene_path)
	assert(pkd_scene, "Expected scene path at: " + scene_path)
	var root_node: Node = pkd_scene.instance()
	if root_node.script != script: # root_node.script may be parent class
		root_node.set_script(script)
	return root_node

static func free_procedural_nodes(root: Node) -> void:
	# See "root" comments below; it may or may not be the main scene tree root.
	if "PERSIST_AS_PROCEDURAL_OBJECT" in root:
		if root.PERSIST_AS_PROCEDURAL_OBJECT:
			root.queue_free() # children will also be freed!
			return
	for child in root.get_children():
		if "PERSIST_AS_PROCEDURAL_OBJECT" in child:
			free_procedural_nodes(child)

func generate_gamesave(root: Node) -> Array:
	# "root" may or may not be the main scene tree root. Data in the result
	# array includes the root (if it is a persist node) and the continuous tree
	# of persist nodes below that.
	_root = root
	assert(DPRINT and print("* Registering tree for gamesave *") or true)
	_register_tree_for_save(root)
	assert(DPRINT and print("* Serializing tree for gamesave *") or true)
	_serialize_tree()
	var gamesave := [
		_gs_n_objects,
		_gs_serialized_nodes,
		_gs_serialized_references,
		_gs_script_paths,
		]
	print("Persist objects saved: ", _gs_n_objects, "; nodes in tree: ",
			root.get_tree().get_node_count())
	_reset()
	return gamesave

func build_tree(root: Node, gamesave: Array, dont_attach := false) -> Array:
	# "root" must be the same node specified in generate_gamesave(root).
	# Return array has the children of root, or the not-yet-added children
	# if dont_attach = true.
	#
	# To call this function on another thread, either root can't be part of the
	# current scene tree OR set dont_attach = true. If the latter, you can
	# subsequently attach base procedural node(s) to root in the Main thread.
	#
	# If building for a loaded game, be sure to free the old procedural tree
	# using free_procedural_nodes(). It is recommended to delay a few frames
	# after that so old freeing objects are no longer recieving signals.
	_tag_size = object_tag.length()
	_root = root
	_dont_attach = dont_attach
	_gs_n_objects = gamesave[0]
	_gs_serialized_nodes = gamesave[1]
	_gs_serialized_references = gamesave[2]
	_gs_script_paths = gamesave[3]
	_objects.resize(_gs_n_objects)
	_register_and_instance_load_objects()
	_deserialize_load_objects()
	_build_tree()
	print("Persist objects loaded: ", _gs_n_objects)
	var result := _build_result
	_reset()
	return result

# *****************************************************************************
# Debug logging

func debug_log(root: Node) -> String:
	# Call before and after all external save/load stuff completed. Wrap in
	# in assert to compile only in debug builds, e.g.:
	# assert(print(save_manager.debug_log(get_tree())) or true)
	_log += "Number tree nodes: %s\n" % root.get_tree().get_node_count()
	_log += "Memory usage: %s\n" % OS.get_dynamic_memory_usage()
	# This doesn't work: OS.dump_memory_to_file(mem_dump_path)
	if debug_print_stray_nodes:
		print("Stray Nodes:")
		root.print_stray_nodes()
		print("***********************")
	if debug_print_tree:
		print("Tree:")
		root.print_tree_pretty()
		print("***********************")
	if debug_log_all_nodes or debug_log_persist_nodes:
		_log_count = 0
		var last_log_count_by_class: Dictionary
		if _log_count_by_class:
			last_log_count_by_class = _log_count_by_class.duplicate()
		_log_count_by_class.clear()
		_log_nodes(root)
		if last_log_count_by_class:
			_log += "Class counts difference from last count:\n"
			for class_ in _log_count_by_class:
				if last_log_count_by_class.has(class_):
					_log += "%s %s\n" % [class_, _log_count_by_class[class_] - last_log_count_by_class[class_]]
				else:
					_log += "%s %s\n" % [class_, _log_count_by_class[class_]]
			for class_ in last_log_count_by_class:
				if !_log_count_by_class.has(class_):
					_log += "%s %s\n" % [class_, -last_log_count_by_class[class_]]
		else:
			_log += "Class counts:\n"
			for class_ in _log_count_by_class:
				_log += "%s %s\n" % [class_, _log_count_by_class[class_]]
	var return_log := _log
	_log = ""
	return return_log

func _log_nodes(node: Node) -> void:
	_log_count += 1
	var class_ := node.get_class()
	if _log_count_by_class.has(class_):
		_log_count_by_class[class_] += 1
	else:
		_log_count_by_class[class_] = 1
	var script_identifier := ""
	if node.get_script():
		var source_code: String = node.get_script().get_source_code()
		if source_code:
			var split := source_code.split("\n", false, 1)
			script_identifier = split[0]
	_log += "%s %s %s %s\n" % [_log_count, node, node.name, script_identifier]
	for child in node.get_children():
		if debug_log_all_nodes or "PERSIST_AS_PROCEDURAL_OBJECT" in child:
			_log_nodes(child)

# *****************************************************************************

func _reset():
	_gs_n_objects = 0
	_gs_serialized_nodes = []
	_gs_serialized_references = []
	_gs_script_paths = []
	_root = null
	_ids.clear()
	_key_ids.clear()
	_objects.clear()
	_build_result = []

# Procedural save

func _register_tree_for_save(node: Node) -> void:
	# Make a save_id for all persist nodes by indexing in _ids. Initial call
	# is the tree root which may or may not be a persist node itself.
	_ids[node] = _gs_n_objects
	_gs_n_objects += 1
	for child in node.get_children():
		if "PERSIST_AS_PROCEDURAL_OBJECT" in child:
			_register_tree_for_save(child)

func _serialize_tree() -> void:
	if "PERSIST_AS_PROCEDURAL_OBJECT" in _root:
		_serialize_node(_root)
	for child in _root.get_children():
		if "PERSIST_AS_PROCEDURAL_OBJECT" in child:
			_serialize_tree_recursive(child)

func _serialize_tree_recursive(node: Node) -> void:
	_serialize_node(node)
	for child in node.get_children():
		if "PERSIST_AS_PROCEDURAL_OBJECT" in child:
			_serialize_tree_recursive(child)

# Procedural load

func _register_and_instance_load_objects() -> void:
	# Instantiates procecural objects (nodes & references) without data.
	# Indexes root and all persist objects (procedural and non-procedural).
	assert(DPRINT and print("* Registering(/Instancing) Objects for Load *") or true)
	_objects[0] = _root
	var scripts := []
	for script_path in _gs_script_paths:
		scripts.append(load(script_path))
	for serialized_node in _gs_serialized_nodes:
		var save_id: int = serialized_node[0]
		var script_id: int = serialized_node[1]
		var node: Node
		if script_id == -1: # non-procedural node; find it
			var node_path: NodePath = serialized_node[2] # relative
			node = _root.get_node(node_path)
			assert(DPRINT and prints(save_id, node, node.name) or true)
		else: # this is a procedural node
			var script: Script = scripts[script_id]
			node = make_object_or_scene(script)
			assert(DPRINT and prints(save_id, node, script_id, _gs_script_paths[script_id]) or true)
		assert(node)
		_objects[save_id] = node
	for serialized_reference in _gs_serialized_references:
		var save_id: int = serialized_reference[0]
		var script_id: int = serialized_reference[1]
		var script: Script = scripts[script_id]
		var reference: Reference = script.new()
		assert(reference)
		_objects[save_id] = reference
		assert(DPRINT and prints(save_id, reference, script_id, _gs_script_paths[script_id]) or true)

func _deserialize_load_objects() -> void:
	assert(DPRINT and print("* Deserializing Objects for Load *") or true)
	for serialized_node in _gs_serialized_nodes:
		_deserialize_object_data(serialized_node, 3)
	for serialized_reference in _gs_serialized_references:
		_deserialize_object_data(serialized_reference, 2)

func _build_tree() -> void:
	for serialized_node in _gs_serialized_nodes:
		var save_id: int = serialized_node[0]
		var node: Node = _objects[save_id]
		if "PERSIST_AS_PROCEDURAL_OBJECT" in node:
			if node.PERSIST_AS_PROCEDURAL_OBJECT:
				var parent_save_id: int = serialized_node[2]
				if parent_save_id == 0: # root!
					_build_result.append(node)
					if _dont_attach:
						continue
				var parent: Node = _objects[parent_save_id]
				parent.add_child(node)

# Serialize/deserialize functions

func _serialize_node(node: Node):
	var serialized_node := []
	var save_id: int = _ids[node]
	serialized_node.append(save_id) # index 0
	var script_id := -1
	if node.PERSIST_AS_PROCEDURAL_OBJECT:
		script_id = _get_or_create_script_id(node)
		assert(DPRINT and prints(save_id, node, script_id, _gs_script_paths[script_id]) or true)
	else:
		assert(DPRINT and prints(save_id, node, node.name) or true)
	serialized_node.append(script_id) # index 1
	# index 2 will be parent_save_id *or* non-procedural node path
	if node.PERSIST_AS_PROCEDURAL_OBJECT:
		var parent := node.get_parent()
		var parent_save_id: int = _ids[parent]
		serialized_node.append(parent_save_id) # index 2
	else:
		var node_path := _root.get_path_to(node)
		serialized_node.append(node_path) # index 2
	_serialize_object_data(node, serialized_node)
	_gs_serialized_nodes.append(serialized_node)

func _register_and_serialize_reference(reference: Reference) -> int:
	assert(reference.PERSIST_AS_PROCEDURAL_OBJECT) # must be true for References
	var save_id := _gs_n_objects
	_gs_n_objects += 1
	_ids[reference] = save_id
	var serialized_reference := []
	serialized_reference.append(save_id) # index 0
	var script_id := _get_or_create_script_id(reference)
	assert(DPRINT and prints(save_id, reference, script_id, _gs_script_paths[script_id]) or true)
	serialized_reference.append(script_id) # index 1
	_serialize_object_data(reference, serialized_reference)
	_gs_serialized_references.append(serialized_reference)
	return save_id

func _get_or_create_script_id(object: Object) -> int:
	var script_path: String = object.get_script().resource_path
	assert(script_path)
	var script_id: int
	if _ids.has(script_path):
		script_id = _ids[script_path]
	else:
		script_id = _gs_script_paths.size()
		_gs_script_paths.append(script_path)
		_ids[script_path] = script_id
	return script_id

func _serialize_object_data(object: Object, serialized_object: Array) -> void:
	assert(object is Node or object is Reference)
	# serialized_object already has some header info. We now append the size of
	# each persist array followed by data.
	for properties_array in properties_arrays:
		var properties: Array
		var n_properties: int
		if properties_array in object:
			properties = object.get(properties_array)
			n_properties = properties.size()
		else:
			n_properties = 0
		serialized_object.append(n_properties)
		if n_properties > 0:
			var objects_array := []
			for property in properties:
				objects_array.append(object.get(property))
			var serialized_objects_array := _get_serialized_array(objects_array)
			serialized_object.append(serialized_objects_array)

func _deserialize_object_data(serialized_object: Array, data_index: int) -> void:
	# The order of persist properties must be exactly the same from game save
	# to game load. However, if a newer version (loading an older save) has
	# added more persist properties at the end of a persist array const, these
	# will not be touched and will not cause "data out of frame" mistakes.
	# There is some opportunity here for backward compatibility if the newer
	# version knows to init-on-load its added persist properties when loading
	# an older version save file.
	var save_id: int = serialized_object[0]
	var object: Object = _objects[save_id]
	for properties_array in properties_arrays:
		var n_properties: int = serialized_object[data_index]
		data_index += 1
		if n_properties > 0:
			var objects_array: Array = serialized_object[data_index]
			data_index += 1
			_deserialize_array(objects_array)
			var properties: Array = object.get(properties_array)
			var property_index := 0
			while property_index < n_properties:
				var property: String = properties[property_index]
				object.set(property, objects_array[property_index])
				property_index += 1

func _get_serialized_array(objects_array: Array) -> Array:
	var serialized_objects_array := []
	for item in objects_array:
		match typeof(item):
			TYPE_OBJECT:
				serialized_objects_array.append(_encode_object(item))
			TYPE_ARRAY:
				serialized_objects_array.append(_get_serialized_array(item))
			TYPE_DICTIONARY:
				serialized_objects_array.append(_get_serialized_dict(item))
			_: # built-in type
				serialized_objects_array.append(item)
	return serialized_objects_array

func _get_serialized_dict(objects_dict: Dictionary) -> Dictionary:
	var serialized_objects_dict := {}
	for key in objects_dict:
		var item = objects_dict[key] # dynamic type!
		match typeof(item):
			TYPE_OBJECT:
				serialized_objects_dict[key] = _encode_object(item)
			TYPE_ARRAY:
				serialized_objects_dict[key] = _get_serialized_array(item)
			TYPE_DICTIONARY:
				serialized_objects_dict[key] = _get_serialized_dict(item)
			_: # built-in type
				serialized_objects_dict[key] = item
	return serialized_objects_dict

func _deserialize_array(objects_array: Array) -> void:
	var n_items := objects_array.size()
	var index := 0
	while index < n_items:
		var item = objects_array[index] # dynamic type!
		match typeof(item):
			TYPE_STRING:
				var object := _decode_object(item)
				if object:
					objects_array[index] = object
				else: # it's a string!
					objects_array[index] = item
			TYPE_ARRAY:
				_deserialize_array(item)
			TYPE_DICTIONARY:
				_deserialize_dict(item)
			_: # other built-in type
				objects_array[index] = item
		index += 1

func _deserialize_dict(objects_dict: Dictionary) -> void:
	for key in objects_dict:
		var item = objects_dict[key] # dynamic type!
		match typeof(item):
			TYPE_STRING:
				var object := _decode_object(item)
				if object:
					objects_dict[key] = object
				else: # it's a string!
					objects_dict[key] = item
			TYPE_ARRAY:
				_deserialize_array(item)
			TYPE_DICTIONARY:
				_deserialize_dict(item)
			_: # other built-in type
				objects_dict[key] = item

func _encode_object(object: Object) -> String:
	var is_weak_ref := false
	if object is WeakRef:
		object = object.get_ref()
		if object == null:
			return object_tag + "w-1" # weak ref to dead object
		is_weak_ref = true
	assert("PERSIST_AS_PROCEDURAL_OBJECT" in object) # can't persist a non-persist obj
	var save_id: int
	if _ids.has(object): # always true for Node
		save_id = _ids[object]
	else:
		assert(object is Reference)
		save_id = _register_and_serialize_reference(object)
	if is_weak_ref:
		return object_tag + "w" + str(save_id)
	return object_tag + str(save_id)

func _decode_object(test_string: String) -> Object:
	if test_string.substr(0, _tag_size) != object_tag:
		return null # it's just a string!
	if test_string.substr(_tag_size, 1) == "w": # weak ref
		var save_id := int(test_string.substr(_tag_size + 1, test_string.length() - _tag_size - 1))
		if save_id == -1: # weak ref to dead object
			return WeakRef.new() # get_ref() = null
		var object: Object = _objects[save_id]
		return weakref(object)
	var save_id := int(test_string.substr(_tag_size, test_string.length() - _tag_size))
	var object: Object = _objects[save_id]
	return object
