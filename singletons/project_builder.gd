# project_builder.gd
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
# Singleton "ProjectBuilder"
#
# This node builds the program (not the solar system!) and makes program
# nodes, references and classes availible in Global dictionaries. All
# dictionaries here (except procedural_classes) define "small-s singletons".
# A single instance of each class is instantiated and added to Global.program.
#
# Only extension init files should reference this node.
# RUNTIME CLASS FILES SHOULD NOT ACCESS THIS NODE!
# See https://ivoyager.dev/forum for extension instructions and best practices.
#
# To modify and extend I, Voyager:
# 1. Create an extension init file with path "res://<name>/<name>.gd" where
#    <name> is the name of your project or addon. This file should have an
#    _extension_init() function and extend Reference. Instructions 2-5 refer
#    to this file.
# 2. Use _extension_init() to:
#     a. modify "project init" values in Global singleton.
#     b. modify this node's dictionaries to extend (i.e., subclass) or replace
#        existing classes, remove classes, or add new classes.
#     (Above happens before anything else is instantiated!)
# 3. Hook up to Global "project_objects_instantiated" signal to modify
#    init values of instantiated nodes (before they are added to tree) or
#    instantiated references (before they are used). Nodes and references can
#    be accessed after instantiation in the "program" dictionary.
#
# See comments in ivoyager/gui_example/example_game_gui.gd for project GUI
# construction and how to use I, Voyager GUI widgets.

extends Node

const file_utils := preload("res://ivoyager/static/file_utils.gd")

signal init_step_finished()

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

# Extension can assign another Spatial to var universe here. Code below will
# assign this value to Global.program.Universe. I, Voyager always uses the
# Global.program dictionary to find Universe and other program nodes, so node
# names and tree locations don't matter.

onready var universe: Spatial = get_node_or_null("/root/Universe")

# Replace classes below with a subclass of the original unless comment
# indicates otherwise. E.g., "Spatial ok", replace with a class that extends
# Spatial.
#
# Key formatting "_ClassName_" below is meant to be a reminder that the keyed
# item at runtime might be a project-specific subclass (or in some cases
# replacement) for the original class. For objects instanced by ProjectBuilder,
# edge underscores are removed to form keys in the Global.program dictionary
# and the "name" property of nodes.

var program_importers := {
	# Reference classes. ProjectBuilder instances these first. They may erase
	# themselves from Global.program when done (thus, freeing themselves).
	_TranslationImporter_ = TranslationImporter,
	_TableImporter_ = TableImporter,
}

var program_builders := {
	# Reference classes. ProjectBuilder instances one of each. No save/load
	# persistence. These are treated exactly like program_references below, but
	# separated for project organization.
	_SaveBuilder_ = SaveBuilder, # ok to remove if you don't need game save
	_EnvironmentBuilder_ = EnvironmentBuilder,
	_SystemBuilder_ = SystemBuilder,
	_BodyBuilder_ = BodyBuilder,
	_OrbitBuilder_ = OrbitBuilder,
	_ModelBuilder_ = ModelBuilder,
	_RingsBuilder_ = RingsBuilder,
	_LightBuilder_ = LightBuilder,
	_HUDsBuilder_ = HUDsBuilder,
	_MinorBodiesBuilder_ = MinorBodiesBuilder,
	_LPointBuilder_ = LPointBuilder,
	_SelectionBuilder_ = SelectionBuilder,
}

var program_references := {
	# Reference classes. ProjectBuilder instances one of each. No save/load
	# persistence.
	_SettingsManager_ = SettingsManager, # 1st so Global.settings are valid
	_InputMapManager_ = InputMapManager,
	_IOManager_ = IOManager,
	_FontManager_ = FontManager, # ok to replace
	_ThemeManager_ = ThemeManager, # after FontManager; ok to replace
	_QtyTxtConverter_ = QtyTxtConverter,
	_TableReader_ = TableReader,
	_MainMenuManager_ = MainMenuManager,
	_SleepManager_ = SleepManager,
	_Scheduler_ = Scheduler,
}

var program_nodes := {
	# ProjectBuilder instances one of each and adds as child of Universe. Use
	# PERSIST_AS_PROCEDURAL_OBJECT = false if there is data to persist.
	_StateManager_ = StateManager,
	_SaveManager_ = SaveManager, # remove if you don't need game saves
	_Timekeeper_ = Timekeeper,
	_BodyRegistry_ = BodyRegistry,
	_InputHandler_ = InputHandler,
	_VygrCameraHandler_ = VygrCameraHandler, # replace if not using VygrCamera
	_HUDsManager_ = HUDsManager,
	_PointsManager_ = PointsManager,
	_MinorBodiesManager_ = MinorBodiesManager,
}

var keep_gui_under_existing_controls := true # add before other children

var gui_controls := {
	# ProjectBuilder instances one of each and adds as child of Universe. Use
	# PERSIST_AS_PROCEDURAL_OBJECT = false for save/load persistence.
	# ORDER MATTERS!!! Last in list is "on top" for viewing and 1st for input
	# processing. To reorder, either: 1) clear and rebuild this dictionary on
	# project init, or 2) reorder children of Universe after project build.
	_ProjectionSurface_ = ProjectionSurface, # Control ok
	_ProjectGUI_ = ExampleGameGUI, # Project should supply its own top Control!
	_SplashScreen_ = PBDSplashScreen, # Replace or remove (set Global.skip_splash_screen)
	_MainMenuPopup_ = MainMenuPopup, # safe to replace or remove
	_LoadDialog_ = LoadDialog, # safe to replace or remove
	_SaveDialog_ = SaveDialog, # safe to replace or remove
	_OptionsPopup_ = OptionsPopup, # safe to replace or remove
	_CreditsPopup_ = CreditsPopup, # safe to replace or remove
	_HotkeysPopup_ = HotkeysPopup, # safe to replace or remove
	_RichTextPopup_ = RichTextPopup, # safe to replace or remove
	_MainProgBar_ = MainProgBar, # safe to replace or remove
}

var procedural_classes := {
	# Nodes and references NOT instantiated by ProjectBuilder. These classes
	# plus all above can be accessed from Global.script_classes (keys still
	# have underscores). 
	# tree_nodes
	_Body_ = Body,
	_LPoint_ = LPoint,
	_Camera_ = VygrCamera, # possible to replace, but look for dependencies
	_HUDLabel_ = HUDLabel,
	_HUDOrbit_ = HUDOrbit,
	_HUDPoints_ = HUDPoints,
	# tree_refs
	_Orbit_ = Orbit,
	_ModelGeometry_ = ModelGeometry,
	_Properties_ = Properties,
	_SelectionItem_ = SelectionItem,
	_SelectionManager_ = SelectionManager,
	_View_ = View,
	_AsteroidGroup_ = AsteroidGroup,
	_BodyList_ = BodyList, # WIP
}

var extensions := []
var program: Dictionary = Global.program
var script_classes: Dictionary = Global.script_classes

# **************************** INIT SEQUENCE **********************************

func init_extensions() -> void:
	# Instantiates objects or scenes from files matching "res://<name>/<name>.gd"
	# (where <name> != "ivoyager" and does not start with ".") and then calls
	# their _extension_init() function.
	var dir := Directory.new()
	dir.open("res://")
	dir.list_dir_begin()
	var dir_name := dir.get_next()
	while dir_name:
		if dir.current_is_dir() and dir_name != "ivoyager" and !dir_name.begins_with("."):
			var path := "res://" + dir_name + "/" + dir_name + ".gd"
			if file_utils.exists(path):
				var extension_script: Script = load(path)
				if "EXTENSION_NAME" in extension_script \
						and "EXTENSION_VERSION" in extension_script \
						and "EXTENSION_VERSION_YMD" in extension_script:
					var extension: Object = extension_script.new()
					extensions.append(extension)
		dir_name = dir.get_next()
	for extension in extensions:
		if extension.has_method("_extension_init"):
			extension._extension_init()
		Global.extensions.append([extension.EXTENSION_NAME,
				extension.EXTENSION_VERSION, extension.EXTENSION_VERSION_YMD])
	Global.load_assets() # here so extensions can alter paths
	Global.emit_signal("extentions_inited")

func instantiate_and_index() -> void:
	program.Global = Global
	program.Universe = universe
	for dict in [program_importers, program_builders, program_references, program_nodes, gui_controls]:
		for key in dict:
			var object_key: String = key.rstrip("_").lstrip("_")
			assert(!program.has(object_key))
			var object: Object = SaveBuilder.make_object_or_scene(dict[key])
			program[object_key] = object
			if object is Node:
				object.name = object_key
	for dict in [program_importers, program_builders, program_references, program_nodes, gui_controls,
			procedural_classes]:
		for key in dict:
			assert(!script_classes.has(key))
			script_classes[key] = dict[key]
	Global.emit_signal("project_objects_instantiated")

func init_project() -> void:
	for key in program_importers:
		var object_key: String = key.rstrip("_").lstrip("_")
		if program.has(object_key): # might have removed themselves already
			var object: Object = program[object_key]
			if object.has_method("_project_init"):
				object._project_init()
	for dict in [program_builders, program_references, program_nodes, gui_controls]:
		for key in dict:
			var object_key: String = key.rstrip("_").lstrip("_")
			var object: Object = program[object_key]
			if object.has_method("_project_init"):
				object._project_init()
	Global.emit_signal("project_inited")
	yield(get_tree(), "idle_frame")
	emit_signal("init_step_finished")

func add_project_nodes() -> void:
	var index := 0
	for key in gui_controls:
		var object_key = key.rstrip("_").lstrip("_")
		universe.add_child(program[object_key])
		if keep_gui_under_existing_controls:
			universe.move_child(program[object_key], index)
		index += 1
	for key in program_nodes:
		var object_key = key.rstrip("_").lstrip("_")
		universe.add_child(program[object_key])
	Global.emit_signal("project_nodes_added")
	yield(get_tree(), "idle_frame")
	emit_signal("init_step_finished")

func signal_finished() -> void:
	Global.emit_signal("project_builder_finished")

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
