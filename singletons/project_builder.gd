# project_builder.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
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
# Singleton "ProjectBuilder".
# This node builds the program (not the solar system!) and makes program
# nodes, references and classes availible in Global dictionaries. "Program
# nodes" and "program references" are "small-s singletons". I.e., there is only
# one instance of each, but they are instantiated here and are not global.
#
# Only extension init files should reference this node.
# RUNTIME CLASS FILES SHOULD NOT ACCESS THIS NODE!
# See https://ivoyager.dev/forum for extension instructions and best practices.
#
# To modify and extend I, Voyager:
# 1. Create an extension init file with path "res://<name>/<name>.gd" where
#    <name> is the name of your project or addon. This file must have an
#    extension_init() function and can extend Reference or Node (if the latter, 
#    init file can specify a scene; see addon examples). Instructions 2-5 refer
#    to this file.
# 2. Use extension_init() to:
#     a. modify "project init" values in Global singleton.
#     b. modify this node's dictionaries to extend (i.e., subclass) and replace
#        existing classes, remove classes, or add new classes.
#     (Above happens before anything else is instantiated!)
# 3. Hook up to this node's "project_objects_instantiated" signal to modify
#    init values of instantiated nodes (before they are added to tree) or
#    instantiated references (before they are used). Nodes and references can
#    be accessed after instantiation in the "program" dictionary.
# 4. Modify init values in GameGUI (following instruction #3) to remove or
#    add individual GUI scenes. (Or make your own ProjectGUI.)
# 5. Hook up to Global signal "gui_entered_tree" to modify init values of
#    individual GUI scenes (not defined here) before their _ready() call.  

extends Node

const file_utils := preload("res://ivoyager/static/file_utils.gd")

signal extentions_inited()
signal project_objects_instantiated()
signal project_inited()
signal project_nodes_added()
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

# Replace classes below with a subclass of the original unless comment
# indicates otherwise. E.g., "Spatial ok", replace with a class that extends
# Spatial.
#
# Classes instantiated by ProjectBuilder (the next 3 dictionaries) must have
# function "project_init". This is enforced to provide consistent expectation
# when subclassing.
#
# Key formatting "_ClassName_" below is meant to be a reminder that the keyed
# item at runtime might be a project-specific subclass (or in some cases
# replacement) for the original class. For objects instantiated by
# ProjectBuilder, edge underscores are removed to form keys in the
# Global.program dictionary (and name property for nodes).

var program_builders := {
	# ProjectBuilder instances one of each. No save/load persistence. These are
	# treated exactly like program_references (separate for organization).
	_TableImporter_ = TableImporter,
	_SaverLoader_ = SaverLoader,
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
	# ProjectBuilder instances one of each. No save/load persistence.
	_SettingsManager_ = SettingsManager, # 1st so Global.settings are valid
	_InputMapManager_ = InputMapManager,
	_FontManager_ = FontManager, # ok to replace
	_ThemeManager_ = ThemeManager, # after FontManager; ok to replace
	_MouseClickSelector_ = MouseClickSelector,
	_QtyStrings_ = QtyStrings,
	_TableReader_ = TableReader,
}

var program_nodes := {
	# ProjectBuilder instances one of each and adds as child to Global. Use
	# PERSIST_AS_PROCEDURAL_OBJECT = false if there is data to persist.
	_Main_ = Main,
	_Timekeeper_ = Timekeeper,
	_InputHandler_ = InputHandler,
	_BCameraInput_ = BCameraInput, # remove or replace if not using BCamera
	_Registrar_ = Registrar,
	_TreeManager_ = TreeManager,
	_PointsManager_ = PointsManager,
	_MinorBodiesManager_ = MinorBodiesManager,
}

var gui_controls := {
	# ProjectBuilder instances one of each and adds as child to Universe. Use
	# PERSIST_AS_PROCEDURAL_OBJECT = false if save/load persisted. Last in list
	# is "on top" for viewing and 1st for input processing. (Since you can't
	# "insert" into dictionary, you might need to reorder children of Universe
	# after project start.)
	_HUD2dSurface_ = HUD2dSurface, # Control ok
	_ProjectGUI_ = GameGUI, # Control ok (e.g., = PlanetariumGUI in Planetarium)
	_SplashScreen_ = PBDSplashScreen, # Control ok; safe to remove
	_MainMenu_ = MainMenu, # safe to remove
	_LoadDialog_ = LoadDialog, # safe to remove
	_SaveDialog_ = SaveDialog, # safe to remove
	_OptionsPopup_ = OptionsPopup, # safe to remove
	_CreditsPopup_ = CreditsPopup, # safe to remove
	_HotkeysPopup_ = HotkeysPopup, # safe to remove
	_RichTextPopup_ = RichTextPopup, # safe to remove
	_MainProgBar_ = MainProgBar, # safe to remove
}

var procedural_classes := {
	# Nodes and references not instantiated by ProjectBuilder. These classes
	# plus all above can be accessed from Global.script_classes (keys still
	# have underscores). 
	# tree_nodes
	_Body_ = Body,
	_LPoint_ = LPoint,
	_Camera_ = BCamera, # Camera ok, but see comments in b_camera.gd
	_HUDLabel_ = HUDLabel,
	_HUDOrbit_ = HUDOrbit,
	_HUDPoints_ = HUDPoints,
	# tree_refs
	_Orbit_ = Orbit,
	_ModelManager_ = ModelManager,
	_Properties_ = Properties,
	_SelectionItem_ = SelectionItem,
	_SelectionManager_ = SelectionManager,
	_AsteroidGroup_ = AsteroidGroup,
	_BodyList_ = BodyList, # WIP
}

var extensions := []
var program: Dictionary = Global.program
var script_classes: Dictionary = Global.script_classes
var universe: Spatial

# **************************** INIT SEQUENCE **********************************

func init_extensions() -> void:
	# Instantiates objects or scenes from files matching "res://<name>/<name>.gd"
	# (where <name> != "ivoyager" and does not start with ".") and then calls
	# their extension_init() function.
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
					var extension: Object = SaverLoader.make_object_or_scene(extension_script)
					extensions.append(extension)
		dir_name = dir.get_next()
	for extension in extensions:
		extension.extension_init() # extension files must have this method!
	emit_signal("extentions_inited")

func instantiate_and_index() -> void:
	for dict in [program_builders, program_references, program_nodes, gui_controls]:
		for key in dict:
			var object_key: String = key.rstrip("_").lstrip("_")
			assert(!program.has(object_key))
			var object: Object = SaverLoader.make_object_or_scene(dict[key])
			program[object_key] = object
			if object is Node:
				object.name = object_key
	assert(!program.has("Universe"))
	universe = get_node("/root/Universe")
	program.universe = universe
	assert(!program.has("tree"))
	program.tree = get_tree()
	assert(!program.has("root"))
	program.root = get_tree().get_root()
	for dict in [program_builders,program_references, program_nodes, gui_controls,
			procedural_classes]:
		for key in dict:
			assert(!script_classes.has(key))
			script_classes[key] = dict[key]
	emit_signal("project_objects_instantiated")

func init_project() -> void:
	Global.project_init()
	for dict in [program_builders, program_references, program_nodes, gui_controls]:
		for key in dict:
			var object_key: String = key.rstrip("_").lstrip("_")
			var object: Object = program[object_key]
			object.project_init() # all defined here must have this method!
	emit_signal("project_inited")
	yield(get_tree(), "idle_frame")
	emit_signal("init_step_finished")

func add_project_nodes() -> void:
	for key in program_nodes:
		var object_key = key.rstrip("_").lstrip("_")
		Global.add_child(program[object_key])
	for key in gui_controls:
		var object_key = key.rstrip("_").lstrip("_")
		universe.add_child(program[object_key])
	emit_signal("project_nodes_added")
	yield(get_tree(), "idle_frame")
	emit_signal("init_step_finished")

func signal_finished() -> void:
	Global.emit_signal("project_builder_finished")

# ****************************** PROJECT BUILD ********************************

func _ready() -> void:
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
