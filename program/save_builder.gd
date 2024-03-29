# saver_builder.gd
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
class_name IVSaveBuilder
extends RefCounted

# IVSaveBuilder can persist specified data (which may include nested objects)
# and rebuild procedurally generated node trees and references on load. It can
# persist built-in types and four kinds of objects:
#    1. Non-procedural Nodes
#    2. Procedural Nodes (including base nodes of scenes)
#    3. Procedural References
#    4. WeakRef to any of above
#
# A "persist" node or reference is identified by the presence of:
#    const PERSIST_MODE := IVEnums.PERSIST_PROPERTIES_ONLY
#    or...
#    const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL
#    or member 'persist_mode_override' with either of the above two values.
#
# Enum values NO_PERSIST, PERSIST_PROPERTIES_ONLY and PERSIST_PROCEDURAL are
# duplicated here and in IVEnums (ivoyager/static/enums.gd) so we can use this
# file elsewhere and/or remove it from core 'ivoyager' (it may become a
# submodle). 
#
# Lists of properties to persists must be named in constant arrays:
#    const PERSIST_PROPERTIES := [] # properties to persist
#    const PERSIST_PROPERTIES2 := []
#    etc...
#    (These list names can be modified in project settings below. The extra
#    numbered lists are needed for subclasses where a list name is taken by a
#    parent class.)
#
# To reconstruct a scene, the base node's gdscript must have one of:
#    const SCENE := "<path to .tscn file>"
#    const SCENE_OVERRIDE := "" # as above; override may be useful in subclass
#
# Additional rules for persist objects:
#    1. Nodes must be in the tree.
#    2. All ancester nodes up to 'save_root' must also be persist nodes.
#       'save_root' may or may not be a scene root.
#    3. Nodes that are PERSIST_PROPERTIES_ONLY cannot have any ancestors that
#       are PERSIST_PROCEDURAL.
#    4. Non-procedural nodes must have stable names (path cannot change).
#    5. Inner classes can't be persist objects.
#    6. References are always PERSIST_MODE = PERSIST_PROCEDURAL.
#    7. Virtual method _init() cannot have any required args.
#
# Warnings:
#    1. A single array or dict persisted in two places will become two on load.
#    2. Be careful not to have both pesist and non-persist references to the
#       same object. The old (pre-load) object will still be there in the non-
#       persist reference after load.
#
# Godot 4.x changes:
#    1. Any dict keys that are type String will be converted on save (and then
#       loaded) as StringName. This was necessary (and *should* be ok) because
#       the two are interchangable for dictionary indexing and the '=='
#       operation.
#    2. Array-typing is supported.
#
# TODO 4.0: Godot proposal #874 will add Array.id() and Dictionary.id().
# This will allow us to handle multiple references to the same arrays and 
# dicts as we do now for objects. (This will remove warning #1 above.)

const files := preload("res://ivoyager/static/files.gd")

enum {
	NO_PERSIST,
	PERSIST_PROPERTIES_ONLY,
	PERSIST_PROCEDURAL,
}

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
	&"PERSIST_PROPERTIES",
	&"PERSIST_PROPERTIES2",
]

# gamesave contents
# (As of Godot 4.1.1, FileAccess.store_var() & get_var() don't save array types!)
var _gs_n_objects := 1
var _gs_serialized_nodes := []
var _gs_serialized_references := []
var _gs_script_paths := []
var _gs_dict_keys := []

# save processing
var _save_root: Node
var _path_ids := {} # indexed by script paths
var _object_ids := {} # indexed by objects
var _key_ids := {} # indexed by dict keys

# load processing
var _scripts: Array[Script] = [] # indexed by script_id
var _objects: Array[Object] = [null] # indexed by object_id (0 has a special meaning)

# logging
var _log_count := 0
var _log_count_by_class := {}
var _log := ""


static func get_persist_mode(object: Object) -> int:
	if &"persist_mode_override" in object:
		@warning_ignore("unsafe_property_access")
		return object.persist_mode_override
	if not &"PERSIST_MODE" in object:
		return NO_PERSIST
	@warning_ignore("unsafe_property_access")
	return object.PERSIST_MODE


static func is_persist_object(object: Object) -> bool:
	if &"persist_mode_override" in object:
		@warning_ignore("unsafe_property_access")
		return object.persist_mode_override != NO_PERSIST
	if not &"PERSIST_MODE" in object:
		return false
	@warning_ignore("unsafe_property_access")
	return object.PERSIST_MODE != NO_PERSIST


static func is_procedural_persist(object: Object) -> bool:
	if &"persist_mode_override" in object:
		@warning_ignore("unsafe_property_access")
		return object.persist_mode_override == PERSIST_PROCEDURAL
	if not &"PERSIST_MODE" in object:
		return false
	@warning_ignore("unsafe_property_access")
	return object.PERSIST_MODE == PERSIST_PROCEDURAL


func generate_gamesave(save_root: Node) -> Array:
	# "save_root" may or may not be the main scene tree root. It must be a
	# persist node itelf with const PERSIST_MODE = PERSIST_PROPERTIES_ONLY.
	# Data in the result array includes the save_root and the continuous tree
	# of persist nodes below that.
	assert(is_persist_object(save_root))
	assert(!is_procedural_persist(save_root))
	_save_root = save_root
	assert(!DPRINT or IVDebug.dprint("* Registering tree for gamesave *"))
	_register_tree(save_root)
	assert(!DPRINT or IVDebug.dprint("* Serializing tree for gamesave *"))
	_serialize_tree(save_root)
	var gamesave := [
		_gs_n_objects,
		_gs_serialized_nodes,
		_gs_serialized_references,
		_gs_script_paths,
		_gs_dict_keys,
		]
	print("Persist objects saved: ", _gs_n_objects, "; nodes in tree: ",
			save_root.get_tree().get_node_count())
	_reset()
	return gamesave


func build_tree(save_root: Node, gamesave: Array) -> void:
	# "save_root" must be the same non-procedural persist node specified in
	# generate_gamesave(save_root).
	#
	# To call this function on another thread, save_root can't be part of the
	# current scene.
	#
	# If building for a loaded game, be sure to free the old procedural tree
	# using IVUtils.free_procedural_nodes(). It is recommended to delay a few
	# frames after that so old freeing objects are no longer recieving signals.
	_save_root = save_root
	_gs_n_objects = gamesave[0]
	_gs_serialized_nodes = gamesave[1]
	_gs_serialized_references = gamesave[2]
	_gs_script_paths = gamesave[3]
	_gs_dict_keys = gamesave[4]
	_load_scripts()
	_locate_or_instantiate_objects(save_root)
	_deserialize_all_object_data()
	_build_procedural_tree()
	print("Persist objects loaded: ", _gs_n_objects)
	_reset()


# *****************************************************************************
# Debug logging

func debug_log(save_root: Node) -> String:
	# Call before and after all external save/load stuff completed. Wrap in
	# in assert to compile only in debug builds, e.g.:
	# assert(print(save_manager.debug_log(get_tree())) or true)
	_log += "Number tree nodes: %s\n" % save_root.get_tree().get_node_count()
	# This doesn't work: OS.dump_memory_to_file(mem_dump_path)
	if debug_print_stray_nodes:
		print("Stray Nodes:")
		save_root.print_orphan_nodes()
		print("***********************")
	if debug_print_tree:
		print("Tree:")
		save_root.print_tree_pretty()
		print("***********************")
	if debug_log_all_nodes or debug_log_persist_nodes:
		_log_count = 0
		var last_log_count_by_class: Dictionary
		if _log_count_by_class:
			last_log_count_by_class = _log_count_by_class.duplicate()
		_log_count_by_class.clear()
		_log_nodes(save_root)
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
		@warning_ignore("unsafe_method_access")
		var source_code: String = node.get_script().get_source_code()
		if source_code:
			var split := source_code.split("\n", false, 1)
			script_identifier = split[0]
	_log += "%s %s %s %s\n" % [_log_count, node, node.name, script_identifier]
	for child in node.get_children():
		if debug_log_all_nodes or is_procedural_persist(child):
			_log_nodes(child)


# *****************************************************************************

func _reset():
	_gs_n_objects = 1
	_gs_serialized_nodes = []
	_gs_serialized_references = []
	_gs_script_paths = []
	_gs_dict_keys = []
	_save_root = null
	_path_ids.clear()
	_object_ids.clear()
	_key_ids.clear()
	_objects.resize(1) # 1st element is always null
	_scripts.clear()


# Procedural save

func _register_tree(node: Node) -> void:
	# Make an object_id for all persist nodes by indexing in _object_ids.
	# Initial call is the save_root which must be a persist node itself.
	_object_ids[node] = _gs_n_objects
	_gs_n_objects += 1
	for child in node.get_children():
		if is_persist_object(child):
			_register_tree(child)


func _serialize_tree(node: Node) -> void:
	_serialize_node(node)
	for child in node.get_children():
		if is_persist_object(child):
			_serialize_tree(child)


# Procedural load

func _load_scripts() -> void:
	for script_path in _gs_script_paths:
		_scripts.append(load(script_path)) # indexed by script_id


func _locate_or_instantiate_objects(save_root: Node) -> void:
	# Instantiates procecural objects (nodes & references) without data.
	# Indexes root and all persist objects (procedural and non-procedural).
	assert(!DPRINT or IVDebug.dprint("* Registering(/Instancing) Objects for Load *"))
	_objects.resize(_gs_n_objects)
	_objects[1] = save_root
	for serialized_node in _gs_serialized_nodes:
		var object_id: int = serialized_node[0]
		var script_id: int = serialized_node[1]
		var node: Node
		if script_id == -1: # non-procedural node; find it
			var node_path: NodePath = serialized_node[2] # relative
			node = save_root.get_node(node_path)
			assert(!DPRINT or IVDebug.dprint(object_id, node, node.name))
		else: # this is a procedural node
			var script: Script = _scripts[script_id]
			node = files.make_object_or_scene(script)
			assert(!DPRINT or IVDebug.dprint(object_id, node, script_id, _gs_script_paths[script_id]))
		assert(node)
		_objects[object_id] = node
	for serialized_reference in _gs_serialized_references:
		var object_id: int = serialized_reference[0]
		var script_id: int = serialized_reference[1]
		var script: Script = _scripts[script_id]
		@warning_ignore("unsafe_method_access")
		var ref: RefCounted = script.new()
		assert(ref)
		_objects[object_id] = ref
		assert(!DPRINT or IVDebug.dprint(object_id, ref, script_id, _gs_script_paths[script_id]))


func _deserialize_all_object_data() -> void:
	assert(!DPRINT or IVDebug.dprint("* Deserializing Objects for Load *"))
	for serialized_node in _gs_serialized_nodes:
		_deserialize_object_data(serialized_node, true)
	for serialized_reference in _gs_serialized_references:
		_deserialize_object_data(serialized_reference, false)


func _build_procedural_tree() -> void:
	for serialized_node in _gs_serialized_nodes:
		var object_id: int = serialized_node[0]
		var node: Node = _objects[object_id]
		if is_procedural_persist(node):
			var parent_save_id: int = serialized_node[2]
			var parent: Node = _objects[parent_save_id]
			parent.add_child(node)


# Serialize/deserialize functions

func _serialize_node(node: Node):
	var serialized_node := []
	var object_id: int = _object_ids[node]
	serialized_node.append(object_id) # index 0
	var script_id := -1
	var is_procedural := is_procedural_persist(node)
	if is_procedural:
		script_id = _get_script_id(node.get_script())
		assert(!DPRINT or IVDebug.dprint(object_id, node, script_id, _gs_script_paths[script_id]))
	else:
		assert(!DPRINT or IVDebug.dprint(object_id, node, node.name))
	serialized_node.append(script_id) # index 1
	# index 2 will be parent_save_id *or* non-procedural node path
	if is_procedural:
		var parent := node.get_parent()
		var parent_save_id: int = _object_ids[parent]
		serialized_node.append(parent_save_id) # index 2
	else:
		var node_path := _save_root.get_path_to(node)
		serialized_node.append(node_path) # index 2
	_serialize_object_data(node, serialized_node)
	_gs_serialized_nodes.append(serialized_node)


func _register_and_serialize_reference(ref: RefCounted) -> int:
	assert(is_procedural_persist(ref)) # must be true for References
	var object_id := _gs_n_objects
	_gs_n_objects += 1
	_object_ids[ref] = object_id
	var serialized_reference := []
	serialized_reference.append(object_id) # index 0
	var script_id := _get_script_id(ref.get_script())
	assert(!DPRINT or IVDebug.dprint(object_id, ref, script_id, _gs_script_paths[script_id]))
	serialized_reference.append(script_id) # index 1
	_serialize_object_data(ref, serialized_reference)
	_gs_serialized_references.append(serialized_reference)
	return object_id


func _get_script_id(script: Script) -> int:
	var script_path := script.resource_path
	assert(script_path)
	var script_id: int = _path_ids.get(script_path, -1)
	if script_id == -1:
		script_id = _gs_script_paths.size()
		_gs_script_paths.append(script_path)
		_path_ids[script_path] = script_id
	return script_id


func _serialize_object_data(object: Object, serialized_object: Array) -> void:
	assert(object is Node or object is RefCounted)
	# serialized_object already has 3 elements (if Node) or 2 (if Reference).
	# We now append the size of each persist array followed by data.
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
			var array := []
			for property in properties:
				array.append(object.get(property))
			var encoded_array := _get_encoded_array(array)
			serialized_object.append(encoded_array)


func _deserialize_object_data(serialized_object: Array, is_node: bool) -> void:
	# The order of persist properties must be exactly the same from game save
	# to game load. However, if a newer version (loading an older save) has
	# added more persist properties at the end of a persist array const, these
	# will not be touched and will not cause "data out of frame" mistakes.
	# There is some opportunity here for backward compatibility if the newer
	# version knows to init-on-load its added persist properties when loading
	# an older version save file.
	var index: int = 3 if is_node else 2
	var object_id: int = serialized_object[0]
	var object: Object = _objects[object_id]
	for properties_array in properties_arrays:
		var n_properties: int = serialized_object[index]
		index += 1
		if n_properties > 0:
			var array: Array = serialized_object[index]
			index += 1
			var decoded_array = _get_decoded_array(array) # may or may not have content-type
			var properties: Array = object.get(properties_array)
			var property_index := 0
			while property_index < n_properties:
				var property: String = properties[property_index]
				object.set(property, decoded_array[property_index])
				property_index += 1


func _get_encoded_array(array: Array) -> Array:
	var n_items := array.size()
	var encoded_array := []
	encoded_array.resize(n_items)
	var index := 0
	while index < n_items:
		var item = array[index] # untyped
		var type := typeof(item)
		if type == TYPE_OBJECT:
			encoded_array[index] = _get_encoded_object(item)
		elif type == TYPE_ARRAY:
			encoded_array[index] = _get_encoded_array(item)
		elif type == TYPE_DICTIONARY:
			encoded_array[index] = _get_encoded_dict(item)
		else: # built-in type
			encoded_array[index] = item
		index += 1
	
	# append array type to the encoded array
	if array.is_typed():
		var script: Script = array.get_typed_script()
		var script_id := _get_script_id(script) if script else -1
		encoded_array.append(script_id)
		encoded_array.append(array.get_typed_class_name())
		encoded_array.append(array.get_typed_builtin()) # last element
	else:
		encoded_array.append(-1) # last element

	return encoded_array


func _get_encoded_dict(dict: Dictionary) -> Dictionary:
	# Very many dicts will have shared keys, so we index these rather than
	# packing the gamesave with many redundant key strings.
	# All keys of type String are converted to StringName!
	var encoded_dict := {}
	for key in dict:
		if typeof(key) == TYPE_STRING:
			key = StringName(key)
		var key_id: int = _key_ids.get(key, -1)
		if key_id == -1:
			key_id = _key_ids.size()
			_key_ids[key] = key_id
			_gs_dict_keys.append(key)
		var item = dict[key] # untyped
		var type := typeof(item)
		if type == TYPE_OBJECT:
			encoded_dict[key_id] = _get_encoded_object(item)
		elif type == TYPE_ARRAY:
			encoded_dict[key_id] = _get_encoded_array(item)
		elif type == TYPE_DICTIONARY:
			encoded_dict[key_id] = _get_encoded_dict(item)
		else: # built-in type
			encoded_dict[key_id] = item
	return encoded_dict


func _get_decoded_array(encoded_array: Array): # return array may or may not be content-typed
	var array = []
	
	# pop array type from the encoded array
	var typed_builtin: int = encoded_array.pop_back()
	if typed_builtin != -1:
		var typed_class_name: StringName = encoded_array.pop_back()
		var script_id: int = encoded_array.pop_back()
		var script: Script
		if script_id != -1:
			script = _scripts[script_id]
		array = Array(array, typed_builtin, typed_class_name, script)
	
	var n_items := encoded_array.size()
	array.resize(n_items)
	var index := 0
	while index < n_items:
		var item = encoded_array[index] # untyped
		var type := typeof(item)
		if type == TYPE_ARRAY:
			array[index] = _get_decoded_array(item)
		elif type == TYPE_DICTIONARY:
			@warning_ignore("unsafe_cast")
			var item_dict := item as Dictionary
			if item_dict.has("r"):
				var object := _get_decoded_object(item_dict)
				array[index] = object
			else: # it's a dictionary w/ int keys only
				array[index] = _get_decoded_dict(item_dict)
		else: # other built-in type
			array[index] = item
		index += 1
	return array


func _get_decoded_dict(encoded_dict: Dictionary) -> Dictionary:
	# encoded_dict keys are all integers
	var dict := {}
	for key_id in encoded_dict:
		var key = _gs_dict_keys[key_id] # untyped (any String was converted to StringName)
		var item = encoded_dict[key_id] # untyped
		var type := typeof(item)
		if type == TYPE_ARRAY:
			dict[key] = _get_decoded_array(item)
		elif type == TYPE_DICTIONARY:
			@warning_ignore("unsafe_cast")
			var item_dict := item as Dictionary
			if item_dict.has("r"):
				var object := _get_decoded_object(item_dict)
				dict[key] = object
			else: # it's a dictionary w/ int keys only
				dict[key] = _get_decoded_dict(item_dict)
		else: # other built-in type
			dict[key] = item
	return dict


func _get_encoded_object(object: Object) -> Dictionary:
	# Encoded object is a dictionary with key "_" = sign-coded object_id.
	var is_weak_ref := false
	if object is WeakRef:
		@warning_ignore("unsafe_method_access")
		object = object.get_ref()
		if object == null:
			return {r = 0} # object_id = 0 represents a weak ref to dead object
		is_weak_ref = true
	assert(is_persist_object(object), "Can't persist a non-persist obj")
	var object_id: int = _object_ids.get(object, -1)
	if object_id == -1:
		assert(object is RefCounted, "Nodes are already registered")
		object_id = _register_and_serialize_reference(object)
	if is_weak_ref:
		return {r = -object_id} # negative object_id for WeakRef
	return {r = object_id} # positive object_id for non-WeakRef


func _get_decoded_object(encoded_object: Dictionary) -> Object:
	var object_id: int = encoded_object.r
	if object_id == 0:
		return WeakRef.new() # weak ref to dead object
	if object_id < 0: # weak ref
		var object: Object = _objects[-object_id]
		return weakref(object)
	var object: Object = _objects[object_id]
	return object
