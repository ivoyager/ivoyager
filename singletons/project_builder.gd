# project_builder.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2022 Charlie Whitfield
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

# Singleton "IVProjectBuilder"
#
# This node builds the program (not the solar system!) and makes program
# nodes, references and classes availible in IVGlobal dictionaries. All
# dictionaries here (except procedural_classes) define "small-s singletons".
# A single instance of each class is instantiated and added to IVGlobal.program.
#
# Only extension init files should reference this node.
# RUNTIME CLASS FILES SHOULD NOT ACCESS THIS NODE!
# See https://www.ivoyager.dev/forum for extension instructions and best
# practices.
#
# To modify and extend I, Voyager:
# 1. Create an extension init file with path "res://<name>/<name>.gd" where
#    <name> is the name of your project or addon. This file should have an
#    _extension_init() function. Instructions 2-3 refer to this file.
# 2. Use _extension_init() to:
#     a. modify "project init" values in IVGlobal singleton.
#     b. modify this node's dictionaries to extend (i.e., subclass) or replace
#        existing classes, remove classes, or add new classes.
#     (Above happens before anything else is instantiated!)
# 3. Hook up to IVGlobal "project_objects_instantiated" signal to modify
#    init values of instantiated nodes (before they are added to tree) or
#    instantiated references (before they are used). Nodes and references can
#    be accessed after instantiation in the IVGlobal.program dictionary.
#
# See comments in ivoyager/gui_example/example_game_gui.gd for project GUI
# construction and how to use I, Voyager GUI widgets.

signal init_step_finished() # for internal use only

const files := preload("res://ivoyager/static/files.gd")


# ******************** PROJECT VARS - EXTEND HERE !!! *************************

# init_sequence could be changed by singleton or by an extension created at the
# first step of the sequence.
var init_sequence := [
	# [object, method, wait_for_signal]
	[self, "init_extensions", false],
	[self, "instantiate_and_index", false],
	[self, "init_project", true],
	[self, "add_project_nodes", true],
	[self, "signal_finished", false]
]

# Replace classes below with a subclass of the original unless comment
# indicates otherwise. E.g., "Spatial ok", replace with a class that extends
# Spatial.
#
# Key formatting "_ClassName_" below is meant to be a reminder that the keyed
# item at runtime might be a project-specific subclass (or in some cases
# replacement) for the original class. For objects instanced by IVProjectBuilder,
# edge underscores are removed to form keys in the IVGlobal.program dictionary
# and the "name" property of nodes.

var initializers := {
	# Reference classes. IVProjectBuilder instances these first. They may erase
	# themselves from IVGlobal.program when done (thereby freeing themselves).
	_LogInitializer_ = IVLogInitializer,
	_AssetInitializer_ = IVAssetInitializer,
	_WikiInitializer_ = IVWikiInitializer,
	_TranslationImporter_ = IVTranslationImporter,
	_TableImporter_ = IVTableImporter,
}

var prog_builders := {
	# Reference classes. IVProjectBuilder instances one of each. No save/load
	# persistence. These are treated exactly like prog_refs below, but
	# separated for project organization.
	_SaveBuilder_ = IVSaveBuilder, # ok to remove if you don't need game save
	_EnvironmentBuilder_ = IVEnvironmentBuilder,
	_SystemBuilder_ = IVSystemBuilder,
	_BodyBuilder_ = IVBodyBuilder,
	_OrbitBuilder_ = IVOrbitBuilder,
	_ModelBuilder_ = IVModelBuilder,
	_RingsBuilder_ = IVRingsBuilder,
	_LightBuilder_ = IVLightBuilder,
	_HUDsBuilder_ = IVHUDsBuilder,
	_MinorBodiesBuilder_ = IVMinorBodiesBuilder,
	_LagrangePointBuilder_ = IVLagrangePointBuilder,
	_SelectionBuilder_ = IVSelectionBuilder,
	_CompositionBuilder_ = IVCompositionBuilder,
}

var prog_refs := {
	# Reference classes. IVProjectBuilder instances one of each. No save/load
	# persistence.
	_SettingsManager_ = IVSettingsManager, # 1st so IVGlobal.settings are valid
	_InputMapManager_ = IVInputMapManager,
	_IOManager_ = IVIOManager,
	_FontManager_ = IVFontManager, # ok to replace
	_ThemeManager_ = IVThemeManager, # after IVFontManager; ok to replace
	_QuantityFormatter_ = IVQuantityFormatter,
	_TableReader_ = IVTableReader,
	_MainMenuManager_ = IVMainMenuManager,
	_SleepManager_ = IVSleepManager,
	_VisualsHelper_ = IVVisualsHelper,
	_WikiManager_ = IVWikiManager,
}

var prog_nodes := {
	# IVProjectBuilder instances one of each and adds as child of Universe. Use
	# PERSIST_AS_PROCEDURAL_OBJECT = false if there is data to persist.
	_StateManager_ = IVStateManager,
	_SaveManager_ = IVSaveManager, # remove if you don't need game saves
	_Timekeeper_ = IVTimekeeper,
	_Scheduler_ = IVScheduler,
	_BodyRegistry_ = IVBodyRegistry,
	_CameraHandler_ = IVCameraHandler, # replace if not using IVCamera
	_HUDsManager_ = IVHUDsManager,
	_PointsManager_ = IVPointsManager,
	_MinorBodiesManager_ = IVMinorBodiesManager,
}

var gui_nodes := {
	# IVProjectBuilder instances one of each and adds as child of Universe. Use
	# PERSIST_AS_PROCEDURAL_OBJECT = false for save/load persistence.
	# ORDER MATTERS!!! Last in list is "on top" for viewing and 1st for input
	# processing. To reorder, either: 1) clear and rebuild this dictionary on
	# project init, or 2) reorder children of Universe after project build.
	_ProjectionSurface_ = IVProjectionSurface, # Control ok
	_ProjectGUI_ = null, # Project MUST supply its own top Control!
	_SplashScreen_ = null, # Project MUST set unless IVGlobal.skip_splash_screen
	_MainMenuPopup_ = IVMainMenuPopup, # safe to replace or remove
	_LoadDialog_ = IVLoadDialog, # safe to replace or remove
	_SaveDialog_ = IVSaveDialog, # safe to replace or remove
	_OptionsPopup_ = IVOptionsPopup, # safe to replace or remove
	_CreditsPopup_ = IVCreditsPopup, # safe to replace or remove
	_HotkeysPopup_ = IVHotkeysPopup, # safe to replace or remove
	_RichTextPopup_ = IVRichTextPopup, # safe to replace or remove
	_MainProgBar_ = IVMainProgBar, # safe to replace or remove
}

var procedural_classes := {
	# Nodes and references NOT instantiated by IVProjectBuilder. These classes
	# plus all above can be accessed from IVGlobal.script_classes (keys still
	# have underscores). 
	# tree_nodes
	_Body_ = IVBody,
	_Camera_ = IVCamera, # possible to replace, but look for dependencies
	_LPoint_ = IVLPoint,
	_HUDLabel_ = IVHUDLabel,
	_HUDOrbit_ = IVHUDOrbit,
	_HUDPoints_ = IVHUDPoints,
	_SelectionManager_ = IVSelectionManager,
	# tree_refs
	_Orbit_ = IVOrbit,
	_ModelController_ = IVModelController,
	_SelectionItem_ = IVSelectionItem,
	_View_ = IVView,
	_AsteroidGroup_ = IVAsteroidGroup,
	_Composition_ = IVComposition,
	# _BodyList_ = IVBodyList, # WIP
}

# Extension can assign another Spatial to var 'universe' here. Code will
# assign this value to IVGlobal.program.Universe. I, Voyager always uses the
# IVGlobal.program dictionary to find Universe and other program nodes, so node
# names and tree locations don't matter.
onready var universe: Spatial = get_node_or_null("/root/Universe")


# ***************************** PRIVATE VARS **********************************

var _project_extensions := [] # keep reference so they don't self-free
var _program: Dictionary = IVGlobal.program
var _script_classes: Dictionary = IVGlobal.script_classes


# **************************** INIT SEQUENCE **********************************

func init_extensions() -> void:
	# Instantiates objects or scenes from files matching "res://<name>/<name>.gd"
	# (where <name> != "ivoyager" and does not start with ".") and then calls
	# their _extension_init() function.
	var dir := Directory.new()
	dir.open("res://")
	dir.list_dir_begin()
	while true:
		var dir_name := dir.get_next()
		if !dir_name:
			break
		if !dir.current_is_dir() or dir_name == "ivoyager" or dir_name.begins_with("."):
			continue
		var path := "res://" + dir_name + "/" + dir_name + ".gd"
		if !files.exists(path):
			continue
		var extension_script: Script = load(path)
		if not "EXTENSION_NAME" in extension_script \
				or not "EXTENSION_VERSION" in extension_script \
				or not "EXTENSION_VERSION_YMD" in extension_script:
			continue
		var extension: Object = extension_script.new()
		_project_extensions.append(extension)
		IVGlobal.extensions.append([
			extension.EXTENSION_NAME,
			extension.EXTENSION_VERSION,
			extension.EXTENSION_VERSION_YMD
			])
	for extension in _project_extensions:
		if extension.has_method("_extension_init"):
			extension._extension_init()
	IVGlobal.emit_signal("extentions_inited")


func instantiate_and_index() -> void:
	_program.Global = IVGlobal
	_program.Universe = universe
	for dict in [initializers, prog_builders, prog_refs, prog_nodes, gui_nodes]:
		for key in dict:
			var object_key: String = key.rstrip("_").lstrip("_")
			assert(!_program.has(object_key))
			var object: Object = files.make_object_or_scene(dict[key])
			_program[object_key] = object
			if object is Node:
				object.name = object_key
	for dict in [initializers, prog_builders, prog_refs, prog_nodes, gui_nodes,
			procedural_classes]:
		for key in dict:
			assert(!_script_classes.has(key))
			_script_classes[key] = dict[key]
	IVGlobal.emit_signal("project_objects_instantiated")


func init_project() -> void:
	for key in initializers:
		var object_key: String = key.rstrip("_").lstrip("_")
		if _program.has(object_key): # might have removed themselves already
			var object: Object = _program[object_key]
			if object.has_method("_project_init"):
				object._project_init()
	for dict in [prog_builders, prog_refs, prog_nodes, gui_nodes]:
		for key in dict:
			var object_key: String = key.rstrip("_").lstrip("_")
			var object: Object = _program[object_key]
			if object.has_method("_project_init"):
				object._project_init()
	IVGlobal.emit_signal("project_inited")
	yield(get_tree(), "idle_frame")
	emit_signal("init_step_finished")


func add_project_nodes() -> void:
	for key in prog_nodes:
		var object_key = key.rstrip("_").lstrip("_")
		universe.add_child(_program[object_key])
	for key in gui_nodes:
		var object_key = key.rstrip("_").lstrip("_")
		universe.add_child(_program[object_key])
	IVGlobal.emit_signal("project_nodes_added")
	yield(get_tree(), "idle_frame")
	emit_signal("init_step_finished")


func signal_finished() -> void:
	IVGlobal.emit_signal("project_builder_finished")


# ****************************** PROJECT BUILD ********************************

func _ready() -> void:
	get_tree().paused = true
	call_deferred("_build_deferred")


func _build_deferred() -> void:
	var init_index := 0
	while init_index < init_sequence.size():
		var init_array: Array = init_sequence[init_index]
		var object: Object = init_array[0]
		var method: String = init_array[1]
		var wait_for_signal: bool = init_array[2]
		object.call(method)
		if wait_for_signal:
			yield(self, "init_step_finished")
		init_index += 1
