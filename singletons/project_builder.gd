# project_builder.gd
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
extends Node

# Instance global "IVProjectBuilder".
#
# This node builds the program (not the solar system!) and makes program
# nodes, references, and class scripts availible in IVGlobal dictionaries. All
# dictionaries here (except procedural_classes) define "small-s singletons";
# a single instance of each class is instantiated, and nodes are added to
# either the top Node3D node (specified by 'universe') or the top Control node
# (specified by 'top_gui'). All object instantiations can be accessed in
# IVGlobal dictionary 'program' and all class scripts can be accessed in
# IVGlobal dictionary 'script_classes'.
#
# Only extension init files should access this node.
# RUNTIME CLASS FILES SHOULD NOT ACCESS THIS NODE!
#
# See example extension files for our Planetarium and Project Template:
# https://github.com/ivoyager/planetarium/blob/master/planetarium/planetarium.gd
# https://github.com/ivoyager/project_template/blob/master/replace_me/replace_me.gd
#
# To modify and extend I, Voyager:
# 1. Create an extension init file with path "res://<name>/<name>.gd" where
#    <name> is the name of your project or addon. This file should have an
#    _extension_init() function. Instructions 2-3 refer to this file.
# 2. Use _extension_init() to:
#     a. modify "project init" values in the IVGlobal singleton.
#     b. modify this node's dictionaries to extend (i.e., subclass) or replace
#        existing classes, remove classes, or add new classes. You can remove a
#        class by either erasing the dictionary key or setting it to null.
#     (Above happens before anything else is instantiated!)
# 3. Hook up to IVGlobal 'project_objects_instantiated' signal to modify
#    init values of instantiated Nodes (before they are added to tree) or
#    RefCounteds (before they are used). Nodes and RefCounteds can be
#    accessed after instantiation in the IVGlobal.program dictionary.
# 4. Build your project GUI using the many widgets in ivoyager/gui_widgets.
#
# By itself, ivoyager will run but it lacks a GUI: the default IVTopGUI has no
# child GUIs. You can either build on the existing IVTopGUI or provide your own
# by setting 'top_gui' here (but see comments in tree_nodes/top_gui.gd).
#
# For a game that needs a splash screen at startup, add the splash screen to
# 'gui_nodes' here and set IVGlobal.skip_splash_screen = false (for example,
# see https://github.com/ivoyager/project_template).


signal init_step_finished() # for internal IVProjectBuilder use only

const files := preload("res://ivoyager/static/files.gd")


# *************** PROJECT VARS - MODIFY THESE TO EXTEND !!!! ******************

var allow_project_build := true # blockable by another autoload singleton

# init_sequence can be modified (even after started) by singleton or by an
# extension instantiated at the first step of this sequence.
var init_sequence: Array[Array] = [
	# [object, method, wait_for_signal]
	[self, "_init_extensions", false],
	[self, "_set_simulator_root", false],
	[self, "_set_simulator_top_gui", false],
	[self, "_instantiate_and_index_program_objects", false],
	[self, "_init_program_objects", true],
	[self, "_add_program_nodes", true],
	[self, "_finish", false]
]

# All nodes instatiated here are added to 'universe' or 'top_gui'. Extension
# can set either or both of these, or let ProjectBuilder assign default nodes
# from the core ivoyager submodule (or for universe, by tree search).
# Whatever is assigned to these properties will be accessible from
# IVGlobal.program.Universe and IVGlobal.program.TopGUI (irrespective of node
# names).

var universe: Node3D
var top_gui: Control
var add_top_gui_to_universe := true # happens in add_program_nodes()

# Replace classes in dictionaries below with a subclass of the original unless
# comment indicates otherwise. E.g., "Node3D ok": replace with a class that
# extends Node3D. In some cases, elements can be erased for unneeded systems.
# For example, our Planetarium erases the save/load system and associated GUI:
# https://github.com/ivoyager/planetarium/blob/master/planetarium/planetarium.gd
#
# Key formatting '_ClassName_' below is meant to be a reminder that the keyed
# item at runtime might be a project-specific subclass (or in some cases
# replacement) for the original class. For objects instanced by IVProjectBuilder,
# edge underscores are removed to form keys in the IVGlobal.program dictionary
# and the 'name' property in the case of nodes.

var initializers := {
#	# RefCounted classes. IVProjectBuilder instances these (first!) and adds to
#	# dictionary IVGlobal.program. They may erase themselves from
#	# IVGlobal.program when done (thereby freeing themselves).
	_LogInitializer_ = IVLogInitializer,
	_AssetInitializer_ = IVAssetInitializer,
	_SharedInitializer_ = SharedInitializer,
	_WikiInitializer_ = IVWikiInitializer,
	_TranslationImporter_ = IVTranslationImporter,
	_TableImporter_ = IVTableImporter,
}

var program_refcounteds := {
	# RefCounted classes. IVProjectBuilder instances one of each and adds to
	# dictionary IVGlobal.program. No save/load persistence.
	
	# need first!
	_SettingsManager_ = IVSettingsManager, # 1st so IVGlobal.settings are valid
	
	# builders (generators, often from table or binary data)
	_EnvironmentBuilder_ = IVEnvironmentBuilder,
	_SystemBuilder_ = IVSystemBuilder,
	_BodyBuilder_ = IVBodyBuilder,
	_SBGBuilder_ = IVSBGBuilder,
	_OrbitBuilder_ = IVOrbitBuilder,
	_SelectionBuilder_ = IVSelectionBuilder,
	_CompositionBuilder_ = IVCompositionBuilder, # remove or subclass
#	_SaveBuilder_ = IVSaveBuilder, # ok to remove if you don't need game save
	
	# finishers (modify something on entering tree)
	_BodyFinisher_ = IVBodyFinisher,
	_SBGFinisher_ = IVSBGFinisher,
	
	# managers
	_IOManager_ = IVIOManager,
	_InputMapManager_ = IVInputMapManager,
	_FontManager_ = IVFontManager, # ok to replace
	_ThemeManager_ = IVThemeManager, # after IVFontManager; ok to replace
	_MainMenuManager_ = IVMainMenuManager,
	_SleepManager_ = IVSleepManager,
	_WikiManager_ = IVWikiManager,
	_ModelManager_ = IVModelManager,
	
	# tools and resources
	_TableReader_ = IVTableReader,
	_QuantityFormatter_ = IVQuantityFormatter,
	_ViewDefaults_ = IVViewDefaults,
}

var program_nodes := {
	# IVProjectBuilder instances one of each and adds as child to Universe
	# (before/"below" TopGUI) and to dictionary IVGlobal.program.
	# Use PERSIST_MODE = PERSIST_PROPERTIES_ONLY if there is data to persist.
	_Scheduler_ = IVScheduler,
	_ViewManager_ = IVViewManager,
#	_FragmentIdentifier_ = IVFragmentIdentifier, # safe to remove
	
	# Nodes below are ordered for input handling (last is first). We mainly
	# need to intercept cntr-something actions (quit, full-screen, etc.) before
	# CameraHandler. Universe children can be reordered after
	# 'project_nodes_added' signal using API below.
	_CameraHandler_ = IVCameraHandler, # remove or replace if not using IVCamera
	_Timekeeper_ = IVTimekeeper,
	_WindowManager_ = IVWindowManager,
	_SBGHUDsState_ = IVSBGHUDsState, # (likely to have input in future)
	_BodyHUDsState_ = IVBodyHUDsState,
	_InputHandler_ = IVInputHandler,
#	_SaveManager_ = IVSaveManager, # remove if you don't need game saves
	_StateManager_ = IVStateManager,
}

var gui_nodes := {
	# IVProjectBuilder instances one of each and adds as child to TopGUI (or
	# substitute Control set in 'top_gui') and to dictionary IVGlobal.program.
	# Order determines visual 'on top' and input event handling: last added
	# is on top and 1st handled. TopGUI children can be reordered after
	# 'project_nodes_added' signal using API below.
	# Use PERSIST_MODE = PERSIST_PROPERTIES_ONLY for save/load persistence.
	_WorldController_ = IVWorldController, # Control ok
	_MouseTargetLabel_ = IVMouseTargetLabel, # safe to replace or remove
	_GameGUI_ = null, # assign here if convenient (above MouseTargetLabel, below SplashScreen)
	_SplashScreen_ = null, # assign here if convenient (below popups)
	_MainMenuPopup_ = IVMainMenuPopup, # safe to replace or remove
#	_LoadDialog_ = IVLoadDialog, # safe to replace or remove
#	_SaveDialog_ = IVSaveDialog, # safe to replace or remove
	_OptionsPopup_ = IVOptionsPopup, # safe to replace or remove
#	_CreditsPopup_ = IVCreditsPopup, # safe to replace or remove
	_HotkeysPopup_ = IVHotkeysPopup, # safe to replace or remove
	_HotkeyDialog_ = IVHotkeyDialog, # safe to replace or remove
	_Confirmation_ = IVConfirmation, # safe to replace or remove
	_MainProgBar_ = IVMainProgBar, # safe to replace or remove
}

var procedural_classes := {
	# Nodes and references NOT instantiated by IVProjectBuilder. These class
	# scripts plus all above can be accessed from IVGlobal.script_classes (keys
	# have underscores). 
	# tree_nodes
	_Body_ = IVBody, # many dependencies, best to subclass
	_Camera_ = IVCamera, # replaceable, but look for dependencies
	_BodyLabel_ = IVBodyLabel, # replace w/ Node3D
	_BodyOrbit_ = IVBodyOrbit, # replace w/ Node3D
	_SBGOrbits_ = IVSBGOrbits, # replace w/ Node3D
	_SBGPoints_ = IVSBGPoints, # replace w/ Node3D
	_LagrangePoint_ = IVLagrangePoint, # replace w/ subclass
	_ModelSpace_ = IVModelSpace, # replace w/ Node3D
	_RotatingSpace_ = IVRotatingSpace, # replace w/ subclass
	_Rings_ = IVRings, # replace w/ Node3D
	_SpheroidModel_ = IVSpheroidModel, # replace w/ Node3D
	_SelectionManager_ = IVSelectionManager, # replace w/ Node3D
	# tree_refs
	_SmallBodiesGroup_ = IVSmallBodiesGroup,
	_Orbit_ = IVOrbit,
	_Selection_ = IVSelection,
	_View_ = IVView,
	_Composition_ = IVComposition, # replaceable, but look for dependencies
}


# ***************************** PRIVATE VARS **********************************

var _project_extensions: Array[Object] = [] # we keep reference so they don't self-free
var _program: Dictionary = IVGlobal.program
var _script_classes: Dictionary = IVGlobal.script_classes


# ****************************** PROJECT BUILD ********************************

func _ready() -> void:
	call_deferred("build_project") # after all other singletons _ready()


# **************************** PUBLIC FUNCTIONS *******************************
# These should be called only by extension init file!

func reindex_universe_child(node_name: String, new_index: int) -> void:
	# Call at 'project_nodes_added' signal.
	var node: Node = _program[node_name]
	universe.move_child(node, new_index)


func reindex_top_gui_child(node_name: String, new_index: int) -> void:
	# Call at 'project_nodes_added' signal.
	var node: Node = _program[node_name]
	top_gui.move_child(node, new_index)


func move_universe_child_to_sibling(node_name: String, sibling_name: String,
		is_before: bool) -> void:
	# Call at 'project_nodes_added' signal.
	var node: Node = _program[node_name]
	var sibling: Node = _program[sibling_name]
	var sibling_index := sibling.get_index()
	universe.move_child(node, sibling_index if is_before else sibling_index + 1)


func move_top_gui_child_to_sibling(node_name: String, sibling_name: String,
		is_before: bool) -> void:
	# Call at 'project_nodes_added' signal.
	var node: Node = _program[node_name]
	var sibling: Node = _program[sibling_name]
	var sibling_index := sibling.get_index()
	top_gui.move_child(node, sibling_index if is_before else sibling_index + 1)


func build_project(override := false) -> void:
	# Call directly only if extension set allow_project_build = false.
	if !override and !allow_project_build:
		return
	# Build loop is designed so that array 'init_sequence' can be modified even
	# during loop execution -- in particular, by an extention instantiated in
	# the first step. Otherwise, it could be modified by an autoload singleton.
	var init_index := 0
	while init_index < init_sequence.size():
		var init_array: Array = init_sequence[init_index]
		var object: Object = init_array[0]
		var method: String = init_array[1]
		var wait_for_signal: bool = init_array[2]
		object.call(method)
		if wait_for_signal:
			await self.init_step_finished
		init_index += 1


# ************************ 'init_sequence' FUNCTIONS **************************

func _init_extensions() -> void:
	# Instantiates objects or scenes from files matching "res://<name>/<name>.gd"
	# (where <name> != "ivoyager" and does not start with ".") and then calls
	# their _extension_init() function.
	var dir := DirAccess.open("res://")
	dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
	while true:
		var dir_name := dir.get_next()
		if !dir_name:
			break
		if !dir.current_is_dir() or dir_name == "ivoyager" or dir_name.begins_with("."):
			continue
		var path := "res://" + dir_name + "/" + dir_name + ".gd"
		if !files.exists(path):
			continue
		var extension_script: GDScript = load(path)
		if (
				not "EXTENSION_NAME" in extension_script
				or not "EXTENSION_VERSION" in extension_script
				or not "EXTENSION_BUILD" in extension_script
				or not "EXTENSION_STATE" in extension_script
				or not "EXTENSION_YMD" in extension_script
		):
			print("WARNING! Missing required const members in extension file " + path)
			continue
		var extension: Object = extension_script.new()
		_project_extensions.append(extension)
		IVGlobal.extensions.append([
			extension.get("EXTENSION_NAME"),
			extension.get("EXTENSION_VERSION"),
			extension.get("EXTENSION_BUILD"),
			extension.get("EXTENSION_STATE"),
			extension.get("EXTENSION_YMD"),
		])
	for extension in _project_extensions:
		if extension.has_method("_extension_init"):
			@warning_ignore("unsafe_method_access")
			extension._extension_init()
	IVGlobal.extentions_inited.emit()


func _set_simulator_root() -> void:
	# Sim root node 'universe' is assigned in one of three ways:
	# 1. An extension assigns property 'universe' in this object.
	# 2. This method finds a tree node named 'Universe'. (In the project
	#    template, Universe is already present as the main scene.)
	# 3. IVUniverse (tree_nodes/universe.gd) is instantiated. In this case,
	#    some other code will need to add it to the tree.
	#
	# Note: ivoyager code always gets this node via IVGlobal.program.Universe,
	# never by node name. The actual node name doesn't matter.
	if universe:
		return
	var scenetree_root := get_tree().get_root()
	universe = scenetree_root.find_child("Universe", true, false)
	if universe:
		return
	universe = files.make_object_or_scene(IVUniverse)
	universe.name = "Universe"


func _set_simulator_top_gui() -> void:
	# 'top_gui' is either assigned by an extension or assigned here with an
	# instatiation of the default IVTopGUI. It is added to Universe in
	# add_program_nodes() if add_top_gui_to_universe == true.
	#
	# Note: ivoyager code always gets this node via IVGlobal.program.TopGUI,
	# never by node name. The actual node name doesn't matter.
	if !top_gui:
		top_gui = files.make_object_or_scene(IVTopGUI)


func _instantiate_and_index_program_objects() -> void:
	_program.Global = IVGlobal
	_program.Universe = universe
	_program.TopGUI = top_gui
	for dict in [initializers, program_refcounteds, program_nodes, gui_nodes]:
		for key in dict:
			var key_str: String = key
			if !dict[key_str]:
				continue
			var object_key: String = key_str.rstrip("_").lstrip("_")
			assert(!_program.has(object_key))
			var object: Object = files.make_object_or_scene(dict[key_str])
			_program[object_key] = object
			if object is Node:
				@warning_ignore("unsafe_property_access")
				object.name = object_key
	for dict in [initializers, program_refcounteds, program_nodes, gui_nodes, procedural_classes]:
		for key in dict:
			if !dict[key]:
				continue
			assert(!_script_classes.has(key))
			_script_classes[key] = dict[key]
	IVGlobal.project_objects_instantiated.emit()


func _init_program_objects() -> void:
	for key in initializers:
		var key_str: String = key
		if !initializers[key_str]:
			continue
		var object_key: String = key_str.rstrip("_").lstrip("_")
		if !_program.has(object_key): # might have removed itself already
			continue
		var object: Object = _program[object_key]
		if object.has_method("_project_init"):
			@warning_ignore("unsafe_method_access")
			object._project_init()
	if universe.has_method("_project_init"):
		@warning_ignore("unsafe_method_access")
		universe._project_init()
	if top_gui.has_method("_project_init"):
		@warning_ignore("unsafe_method_access")
		top_gui._project_init()
	for dict in [program_refcounteds, program_nodes, gui_nodes]:
		for key in dict:
			var key_str: String = key
			if !dict[key_str]:
				continue
			var object_key: String = key_str.rstrip("_").lstrip("_")
			var object: Object = _program[object_key]
			if object.has_method("_project_init"):
				@warning_ignore("unsafe_method_access")
				object._project_init()
	IVGlobal.project_inited.emit()
	await get_tree().process_frame
	init_step_finished.emit()


func _add_program_nodes() -> void:
	# TopGUI added after program_nodes, so gui_nodes will recieve input first
	# and then program_nodes.
	for key in program_nodes:
		var key_str: String = key
		if !program_nodes[key_str]:
			continue
		var object_key = key_str.rstrip("_").lstrip("_")
		universe.add_child(_program[object_key])
	if add_top_gui_to_universe:
		universe.add_child(top_gui)
	for key in gui_nodes:
		var key_str: String = key
		if !gui_nodes[key_str]:
			continue
		var object_key = key_str.rstrip("_").lstrip("_")
		top_gui.add_child(_program[object_key])
	IVGlobal.project_nodes_added.emit()
	await get_tree().process_frame
	init_step_finished.emit()


func _finish() -> void:
	IVGlobal.project_builder_finished.emit()

