# saver_loader.gd
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
# SaverLoader can persist specified data (which may include nested objects) and
# rebuild procedurally generated node trees and references on load. It can
# persist four kinds of objects (in addition to built-in types):
#    1. Non-procedural Nodes
#    2. Procedural Nodes (including base nodes of scenes)
#    3. Procedural References
#    4. WeakRef to any of above
# A "persist" node or reference is identified by presence of the constant:
#    const PERSIST_AS_PROCEDURAL_OBJECT: bool
# Lists of properties to persists must be named in constant arrays:
#    const PERSIST_PROPERTIES := [] # names of properties to persist (no nested objects!)
#    const PERSIST_OBJ_PROPERTIES := [] # as above but allows nested persist objects
#    const PERSIST_PROPERTIES_2 := []
#    const PERSIST_OBJ_PROPERTIES_2 := []
#    etc...
#    (These list names can be modified in project settings below. The extra
#    numbered lists are needed for subclasses where a list name is taken by a
#    parent class.)
# To reconstruct a scene, the base node's gdscript must have one of:
#    const SCENE: String = "<path to *.tscn>"
#    const SCENE_OVERRIDE: String # as above; may be useful in a subclass
# Additional rules for persist objects:
#    1. Nodes must be in the tree.
#    2. All ancester nodes up to root must also be persist nodes.
#    3. A non-procedural node cannot be child of a procedural node.
#    4. Non-procedural nodes must have stable names (path cannot change).
#    5. Inner classes can't be persist objects
#    6. For references, PERSIST_AS_PROCEDURAL_OBJECT = true
#    7. Virtual method _init() cannot have any args.
# Warnings:
#    1. A single table or dict persisted in two places will become two on load
#    2. Persisted strings cannot begin with object_tag.

extends Reference
class_name SaverLoader

const DPRINT := false # true for debug print

# ****************************** SIGNALS **************************************

signal finished() # yield to this after calling save_game() or load_game()

# **************************** PUBLIC VARS ************************************

var progress := 0 # read-only! (for an external progress bar)

# project settings
var use_thread := true # true allows prog bar to work; false helps debugging
var progress_multiplier := 95 # so prog bar doesn't sit for a while at 100%
var properties_arrays := [
	"PERSIST_PROPERTIES",
	"PERSIST_PROPERTIES_2",
	"PERSIST_PROPERTIES_3",
	]
var obj_properties_arrays := [
	"PERSIST_OBJ_PROPERTIES",
	"PERSIST_OBJ_PROPERTIES_2",
	"PERSIST_OBJ_PROPERTIES_3",
	]
var object_tag := "@!~`#" # persisted strings must not start with this

# debug printing/logging
var debug_log_persist_nodes := true
var debug_log_all_nodes := false
var debug_print_stray_nodes := false
var debug_print_tree := false

# **************************** PRIVATE VARS ***********************************

var _tree: SceneTree
var _root: Viewport
var _thread: Thread

# save file
var _sfile_n_objects := 0
var _sfile_serialized_nodes := []
var _sfile_serialized_references := []
var _sfile_script_paths := []
var _sfile_current_scene_id := -1 # set if procedural

# save/load processing
var _ids := {} # save; keyed by objects & script paths
var _objects := [] # load
var _current_scene: Node
var _tag_size: int

# progress & logging
var _prog_serialized := 0
var _prog_deserialized := 0
var _log_count := 0
var _log_count_by_class := {}

# *************************** PUBLIC FUNCTIONS ********************************

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

func project_init():
	# Ignore; required for I, Voyager compatibility
	pass

func save_game(save_file: File, tree: SceneTree) -> void: # Assumes save_file already open
	_tree = tree
	_root = _tree.get_root()
	_current_scene = _tree.get_current_scene()
	progress = 0
	_prog_serialized = 0
	if use_thread:
		_thread = Thread.new()
		_thread.start(self, "_threaded_save", save_file)
	else:
		_threaded_save(save_file)

func load_game(save_file: File, tree: SceneTree) -> void:
	_tree = tree
	_root = _tree.get_root()
	_tag_size = object_tag.length()
	progress = 0
	_prog_deserialized = 0
	yield(_tree, "idle_frame")
	free_procedural_nodes(_root)
	# The reason for the delay below is to make sure that objects from previous
	# game have completely freed themselves (after queue_free call) before we
	# start generating signals in the loaded game. If old objects are still
	# responding to signals before deleting themselves, that can be really bad!
	# I don't know how many yields are really needed. (I tried to test this
	# using print_stray_nodes(), but it fails to report nodes that are still
	# alive and responding to signals.) The goal here was to avoid need for 
	# "destructor" methods with extensive disconnect() statements in our
	# procedural nodes; however, after much pain I still recommend explicit
	# disconnection of signals in procedural objects about to be deleted.
	yield(_tree, "idle_frame")
	yield(_tree, "idle_frame")
	yield(_tree, "idle_frame")
	yield(_tree, "idle_frame")
	yield(_tree, "idle_frame")
	yield(_tree, "idle_frame")
	if use_thread:
		_thread = Thread.new()
		_thread.start(self, "_threaded_load", save_file)
	else:
		_threaded_load(save_file)

func free_procedural_nodes(node: Node, is_root := true) -> void:
	# call with node = root
	if !is_root:
		if node.PERSIST_AS_PROCEDURAL_OBJECT:
			node.queue_free() # children will also be freed!
			return
	else:
		assert(node is Viewport)
	for child in node.get_children():
		if "PERSIST_AS_PROCEDURAL_OBJECT" in child:
			free_procedural_nodes(child, false)

func debug_log(str_message: String, tree: SceneTree) -> bool:
	# Call before and after ALL external save/load stuff completed. Wrap in
	# in assert to compile only in debug builds, e.g.:
	#    assert(saver_loader.debug_log("This is before save", get_tree()))
	_tree = tree
	_root = tree.get_root()
	Debug.logd(str_message)
	Debug.logd("Number tree nodes: ", _tree.get_node_count())
	Debug.logd("Memory usage: ", OS.get_dynamic_memory_usage())
	# This doesn't work: OS.dump_memory_to_file(mem_dump_path)
	if debug_print_stray_nodes:
		print("Stray Nodes:")
		_root.print_stray_nodes()
		print("***********************")
	if debug_print_tree:
		print("Tree:")
		_root.print_tree_pretty()
		print("***********************")
	if debug_log_all_nodes or debug_log_persist_nodes:
		_log_count = 0
		var last_log_count_by_class: Dictionary
		if _log_count_by_class:
			last_log_count_by_class = _log_count_by_class.duplicate()
		_log_count_by_class.clear()
		_log_nodes(_root)
		if last_log_count_by_class:
			Debug.logd("Class counts difference from last count:")
			for class_ in _log_count_by_class:
				if last_log_count_by_class.has(class_):
					Debug.logd(class_, _log_count_by_class[class_] - last_log_count_by_class[class_])
				else:
					Debug.logd(class_, _log_count_by_class[class_])
			for class_ in last_log_count_by_class:
				if !_log_count_by_class.has(class_):
					Debug.logd(class_, -last_log_count_by_class[class_])
		else:
			Debug.logd("Class counts:")
			for class_ in _log_count_by_class:
				Debug.logd(class_, _log_count_by_class[class_])
	return true

# ********************* VIRTUAL & PRIVATE FUNCTIONS ***************************

func _log_nodes(node: Node) -> void:
	_log_count += 1
	var class_ := node.get_class()
	if _log_count_by_class.has(class_):
		_log_count_by_class[class_] += 1
	else:
		_log_count_by_class[class_] = 1
	Debug.logd(_log_count, node, node.name)
	for child in node.get_children():
		if debug_log_all_nodes or "PERSIST_AS_PROCEDURAL_OBJECT" in child:
			_log_nodes(child)

func _clear():
	_sfile_n_objects = 0
	_sfile_serialized_nodes.clear()
	_sfile_serialized_references.clear()
	_sfile_script_paths.clear()
	_sfile_current_scene_id = -1
	_ids.clear()
	_objects.clear()
	_current_scene = null

func _threaded_save(save_file: File) -> void:
	_register_tree_for_save(_root)
	assert(DPRINT and print("* Serializing Tree for Save *") or true)
	_serialize_tree(_root)
	var save_data := [
		_sfile_n_objects,
		_sfile_serialized_nodes,
		_sfile_serialized_references,
		_sfile_script_paths,
		_sfile_current_scene_id
		]
	save_file.store_var(save_data)
	save_file.close()
	call_deferred("_finish_save")

func _finish_save() -> void:
	if use_thread:
		_thread.wait_to_finish()
	yield(_tree, "idle_frame")
	print("Objects saved: ", _sfile_n_objects)
	_clear()
	yield(_tree, "idle_frame")
	emit_signal("finished")

func _threaded_load(save_file: File) -> void:
	var save_data: Array = save_file.get_var()
	save_file.close()
	_sfile_n_objects = save_data[0]
	_sfile_serialized_nodes = save_data[1]
	_sfile_serialized_references = save_data[2]
	_sfile_script_paths = save_data[3]
	_sfile_current_scene_id = save_data[4]
	_objects.resize(_sfile_n_objects)
	_register_and_instance_load_objects()
	_deserialize_load_objects()
	call_deferred("_finish_load")
	
func _finish_load() -> void:
	if use_thread:
		_thread.wait_to_finish()
	yield(_tree, "idle_frame")
	_build_tree()
	_set_current_scene()
	print("Objects loaded: ", _sfile_n_objects)
	_clear()
	yield(_tree, "idle_frame")
	emit_signal("finished")

# Procedural save

func _register_tree_for_save(node: Node) -> void:
	# Make a save_id for all persist nodes by indexing in _ids. We register
	# root (so it can be a procedural node's parent) but don't serialize it. 
	if node == _current_scene and node.PERSIST_AS_PROCEDURAL_OBJECT:
		_sfile_current_scene_id = _sfile_n_objects
	_ids[node] = _sfile_n_objects
	_sfile_n_objects += 1
	for child in node.get_children():
		if "PERSIST_AS_PROCEDURAL_OBJECT" in child:
			_register_tree_for_save(child)

func _serialize_tree(node: Node, is_root := true) -> void:
	if !is_root:
		_serialize_node(node)
	for child in node.get_children():
		if "PERSIST_AS_PROCEDURAL_OBJECT" in child:
			_serialize_tree(child, false)

# Procedural load

func _register_and_instance_load_objects() -> void:
	# Instances procecural objects (nodes & references) without data.
	# Indexes all persist objects (procedural and non-procedural) in _objects.
	assert(DPRINT and print("* Registering(/Instancing) Objects for Load *") or true)
	_objects[0] = _root
	var scripts := []
	for script_path in _sfile_script_paths:
		scripts.append(load(script_path))
	for serialized_node in _sfile_serialized_nodes:
		var save_id: int = serialized_node[0]
		var script_id: int = serialized_node[1]
		var node: Node
		if script_id == -1: # non-procedural node; find it
			var node_path: String = serialized_node[2]
			node = _root.get_node(node_path)
			assert(DPRINT and prints(save_id, node, node.name) or true)
		else: # this is a procedural node
			var script: Script = scripts[script_id]
			node = make_object_or_scene(script)
			assert(DPRINT and prints(save_id, node, script_id, _sfile_script_paths[script_id]) or true)
		assert(node)
		_objects[save_id] = node
	for serialized_reference in _sfile_serialized_references:
		var save_id: int = serialized_reference[0]
		var script_id: int = serialized_reference[1]
		var script: Script = scripts[script_id]
		var reference: Reference = script.new()
		assert(reference)
		_objects[save_id] = reference
		assert(DPRINT and prints(save_id, reference, script_id, _sfile_script_paths[script_id]) or true)

func _deserialize_load_objects() -> void:
	assert(DPRINT and print("* Deserializing Objects for Load *") or true)
	for serialized_node in _sfile_serialized_nodes:
		_deserialize_object_data(serialized_node, 3)
		_prog_deserialized += 1
		# warning-ignore:integer_division
		progress = progress_multiplier * _prog_deserialized / _sfile_n_objects
	for serialized_reference in _sfile_serialized_references:
		_deserialize_object_data(serialized_reference, 2)
		_prog_deserialized += 1
		# warning-ignore:integer_division
		progress = progress_multiplier * _prog_deserialized / _sfile_n_objects

func _build_tree() -> void:
	for serialized_node in _sfile_serialized_nodes:
		var save_id: int = serialized_node[0]
		var node: Node = _objects[save_id]
		if node.PERSIST_AS_PROCEDURAL_OBJECT:
			var parent_save_id: int = serialized_node[2]
			var parent: Node = _objects[parent_save_id]
			parent.add_child(node)

func _set_current_scene() -> void:
	if _sfile_current_scene_id != -1:
		var new_current_scene = _objects[_sfile_current_scene_id]
		_tree.set_current_scene(new_current_scene)

# Serialize/deserialize functions

func _serialize_node(node: Node):
	var serialized_node := []
	var save_id: int = _ids[node]
	serialized_node.append(save_id) # index 0
	var script_id := -1
	if node.PERSIST_AS_PROCEDURAL_OBJECT:
		script_id = _get_or_create_script_id(node)
		assert(DPRINT and prints(save_id, node, script_id, _sfile_script_paths[script_id]) or true)
	else:
		assert(DPRINT and prints(save_id, node, node.name) or true)
	serialized_node.append(script_id) # index 1
	# index 2 will be parent_save_id *or* non-procedural node path
	if node.PERSIST_AS_PROCEDURAL_OBJECT:
		var parent := node.get_parent()
		var parent_save_id: int = _ids[parent]
		serialized_node.append(parent_save_id) # index 2
	else:
		serialized_node.append(node.get_path()) # index 2
	_serialize_object_data(node, serialized_node)
	_sfile_serialized_nodes.append(serialized_node)
	_prog_serialized += 1
	# warning-ignore:integer_division
	progress = progress_multiplier * _prog_serialized / _sfile_n_objects

func _register_and_serialize_reference(reference: Reference) -> int:
	assert(reference.PERSIST_AS_PROCEDURAL_OBJECT) # must be true for References
	var save_id := _sfile_n_objects
	_sfile_n_objects += 1
	_ids[reference] = save_id
	var serialized_reference := []
	serialized_reference.append(save_id) # index 0
	var script_id := _get_or_create_script_id(reference)
	assert(DPRINT and prints(save_id, reference, script_id, _sfile_script_paths[script_id]) or true)
	serialized_reference.append(script_id) # index 1
	_serialize_object_data(reference, serialized_reference)
	_sfile_serialized_references.append(serialized_reference)
	_prog_serialized += 1
	# warning-ignore:integer_division
	progress = progress_multiplier * _prog_serialized / _sfile_n_objects
	return save_id

func _get_or_create_script_id(object: Object) -> int:
	var script_path: String = object.get_script().resource_path
	assert(script_path)
	var script_id: int
	if _ids.has(script_path):
		script_id = _ids[script_path]
	else:
		script_id = _sfile_script_paths.size()
		_sfile_script_paths.append(script_path)
		_ids[script_path] = script_id
	return script_id

func _serialize_object_data(object: Object, serialized_object: Array) -> void:
	assert(object is Node or object is Reference)
	# serialized_object already has some header info. We now append the size of
	# each persist array followed by data.
	var n_properties: int
	var properties: Array
	for properties_array in properties_arrays:
		if properties_array in object:
			properties = object.get(properties_array)
			n_properties = properties.size()
		else:
			n_properties = 0
		serialized_object.append(n_properties)
		if n_properties > 0:
			for property in properties:
				serialized_object.append(object.get(property))
	for obj_properties_array in obj_properties_arrays:
		if obj_properties_array in object:
			properties = object.get(obj_properties_array)
			n_properties = properties.size()
		else:
			n_properties = 0
		serialized_object.append(n_properties)
		if n_properties > 0:
			var objects_array := []
			for property in properties:
				objects_array.append(object.get(property))
			var serialized_objects_array := _get_serialized_objects_array(objects_array)
			serialized_object.append(serialized_objects_array)
		
# warning-ignore:unused_argument
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
	var property_index: int
	var n_properties: int
	var properties: Array
	var property: String
	for properties_array in properties_arrays:
		n_properties = serialized_object[data_index]
		data_index += 1
		if n_properties > 0:
			properties = object.get(properties_array)
			property_index = 0
			while property_index < n_properties:
				property = properties[property_index]
				object.set(property, serialized_object[data_index])
				data_index += 1
				property_index += 1
	for obj_properties_array in obj_properties_arrays:
		n_properties = serialized_object[data_index]
		data_index += 1
		if n_properties > 0:
			var objects_array: Array = serialized_object[data_index]
			data_index += 1
			_deserialize_objects_array(objects_array)
			properties = object.get(obj_properties_array)
			property_index = 0
			while property_index < n_properties:
				property = properties[property_index]
				object.set(property, objects_array[property_index])
				property_index += 1

func _get_serialized_objects_array(objects_array: Array) -> Array:
	var serialized_objects_array := []
	for item in objects_array:
		match typeof(item):
			TYPE_OBJECT:
				serialized_objects_array.append(_encode_object(item))
			TYPE_ARRAY:
				serialized_objects_array.append(_get_serialized_objects_array(item))
			TYPE_DICTIONARY:
				serialized_objects_array.append(_get_serialized_objects_dict(item))
			_: # built-in type
				serialized_objects_array.append(item)
	return serialized_objects_array

func _get_serialized_objects_dict(objects_dict: Dictionary) -> Dictionary:
	var serialized_objects_dict := {}
	for key in objects_dict:
		var item = objects_dict[key] # dynamic type!
		match typeof(item):
			TYPE_OBJECT:
				serialized_objects_dict[key] = _encode_object(item)
			TYPE_ARRAY:
				serialized_objects_dict[key] = _get_serialized_objects_array(item)
			TYPE_DICTIONARY:
				serialized_objects_dict[key] = _get_serialized_objects_dict(item)
			_: # built-in type
				serialized_objects_dict[key] = item
	return serialized_objects_dict

func _deserialize_objects_array(objects_array: Array) -> void:
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
				_deserialize_objects_array(item)
			TYPE_DICTIONARY:
				_deserialize_objects_dict(item)
			_: # other built-in type
				objects_array[index] = item
		index += 1

func _deserialize_objects_dict(objects_dict: Dictionary) -> void:
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
				_deserialize_objects_array(item)
			TYPE_DICTIONARY:
				_deserialize_objects_dict(item)
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
