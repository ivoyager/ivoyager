# project_builder.gd
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
# Singleton "ProjectBuilder". Only extension init files should reference this
# node. RUNTIME CLASS FILES SHOULD NOT ACCESS THIS NODE! See
# https://ivoyager.dev/forum for extension instructions and best practices.
#
# To modify and extend I, Voyager:
# 1. Create a extension init file with path "res://<name>/<name>.gd" where
#    <name> is the name of your project or addon. This file must have an init()
#    function and can extend Reference or Node (if the latter, init file can
#    specify a scene; see addon examples). Instructions 2-5 refer to this file.
# 2. Use init() to:
#     a. modify "project init" values in Global singleton.
#     b. modify this node's dictionaries to extend (i.e., subclass) and replace
#        existing classes, remove classes, or add new classes.
# 3. Hook up to this node's "project_objects_instantiated" signal to modify init
#    values of nodes before they are added to tree or references before they
#    are used. Nodes and references can be accessed after instantiation in
#    the "objects" dictionary.
# 4. Modify init values in InGameGUI (following instruction #3) to remove or
#    add individual GUI scenes. (Or make your own GUI parent.)
# 5. Hook up to Global signal "run_gui_entered_tree" to modify init values of
#    individual GUI scenes (not defined here) before their _ready() call.  
#
# TODO: Move version control comments to README.md.
# I, Voyager is maintained as a Git submodule and "standalone project":
#    https://github.com/charliewhitfield/ivoyager_submodule
#    https://github.com/charliewhitfield/ivoyager_standalone
# You can use ivoyager_standalone as template to build your own project (with
# its own repository) that includes the ivoyager submodule. It's then possible
# to conduct version control of your project and the ivoyager submodule in
# parallel.

extends Node

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
# Global.objects dictionary and node names.

var program_references := {
	# ProjectBuilder instances one of each. No save/load persistence.
	_SettingsManager_ = SettingsManager, # 1st so Global.settings are valid
	_InputMapManager_ = InputMapManager,
	_EnumGlobalizer_ = EnumGlobalizer,
	_TableReader_ = TableReader,
	_SaverLoader_ = SaverLoader,
	_FontManager_ = FontManager, # ok to replace
	_ThemeManager_ = ThemeManager, # after FontManager; ok to replace
	_SystemBuilder_ = SystemBuilder,
	_BodyBuilder_ = BodyBuilder,
	_SelectionBuilder_ = SelectionBuilder,
	_OrbitBuilder_ = OrbitBuilder,
	_MinorBodiesBuilder_ = MinorBodiesBuilder,
	_LPointBuilder_ = LPointBuilder,
	_MouseClickSelector_ = MouseClickSelector,
	_FileHelper_ = FileHelper,
	_StringMaker_ = StringMaker,
	_Math_ = Math,
	_TestClass_ = TestClass,
}

var program_nodes := {
	# ProjectBuilder instances one of each and adds as child to Global. Use
	# PERSIST_AS_PROCEDURAL_OBJECT = false if save/load persisted.
	_Main_ = Main,
	_Timekeeper_ = GregorianTimekeeper, # Timekeeper ok
	_InputHandler_ = InputHandler,
	_Registrar_ = Registrar,
	_TreeManager_ = TreeManager,
	_PointsManager_ = PointsManager,
	_MinorBodiesManager_ = MinorBodiesManager,
}

var gui_top_nodes := {
	# ProjectBuilder will instance one of each and add as child to GUITop. Use
	# PERSIST_AS_PROCEDURAL_OBJECT = false if save/load persisted. Last in list
	# is "on top" for viewing and 1st for input processing.
	_HUD2dControl_ = HUD2dControl, # Control ok
	_InGameGUI_ = InGameGUI, # Control ok; builder & parent for in-game GUIs
	_SplashScreen_ = PBDSplashScreen, # Control ok
	_MainMenu_ = MainMenu, # before other admin so Esc capture is last
	_LoadDialog_ = LoadDialog,
	_SaveDialog_ = SaveDialog,
	_OptionsPopup_ = OptionsPopup,
	_CreditsPopup_ = CreditsPopup,
	_HotkeysPopup_ = HotkeysPopup,
	_MainProgBar_ = MainProgBar,
}

var procedural_classes := {
	# Nodes and references not instanced by ProjectBuilder.
	# system_refs
	_SelectionItem_ = SelectionItem,
	_SelectionManager_ = SelectionManager,
	_Orbit_ = Orbit,
	_AsteroidGroup_ = AsteroidGroup,
	_BodyList_ = BodyList,
	# system_nodes
	_Body_ = Body,
	_LagrangePoint_ = LagrangePoint,
	_VoyagerCamera_ = VoyagerCamera,
	_WorldEnvironment_ = VoyagerEnvironment, # WorldEnvironment ok
	_Model_ = Model, # Spatial ok
	_Rings_ = TempRings, # Spatial ok
	_Starlight_ = Starlight, # OmniLight ok
	_HUDIcon_ = HUDIcon,
	_HUDLabel_ = HUDLabel,
	_HUDOrbit_ = HUDOrbit,
	_HUDPoints_ = HUDPoints,
}

var extensions := []
var objects: Dictionary = Global.objects
var script_classes: Dictionary = Global.script_classes

onready var gui_top: Control = get_node("/root/GUITop") # start scene & UI parent

# **************************** INIT SEQUENCE **********************************

func init_extensions() -> void:
	# Instantiates objects or scenes from files matching "res://<name>/<name>.gd"
	# (where <name> != "ivoyager" and does not start with ".") and then calls
	# their extension_init() function.
	var dir := Directory.new()
	var file := File.new()
	dir.open("res://")
	dir.list_dir_begin()
	var dir_name := dir.get_next()
	while dir_name:
		if dir.current_is_dir() and dir_name != "ivoyager" and !dir_name.begins_with("."):
			var path := "res://" + dir_name + "/" + dir_name + ".gd"
			if file.file_exists(path):
				var extension_script: Script = load(path)
				if "EXTENSION_NAME" in extension_script \
						and "EXTENSION_VERSION" in extension_script \
						and "EXTENSION_YMD_INT" in extension_script:
					var extension: Object = FileHelper.make_object_or_scene(extension_script)
					extensions.append(extension)
		dir_name = dir.get_next()
	for extension in extensions:
		extension.extension_init() # extension files must have this method!
	emit_signal("extentions_inited")

func instantiate_and_index() -> void:
	for dict in [program_references, program_nodes, gui_top_nodes]:
		for key in dict:
			var object_key: String = key.rstrip("_").lstrip("_")
			assert(!objects.has(object_key))
			var object: Object = FileHelper.make_object_or_scene(dict[key])
			objects[object_key] = object
			if object is Node:
				object.name = object_key
	assert(!objects.has("GUITop") and !objects.has("tree") and !objects.has("root"))
	objects.GUITop = gui_top
	objects.tree = get_tree()
	objects.root = get_tree().get_root()
	for dict in [program_references, program_nodes, gui_top_nodes, procedural_classes]:
		for key in dict:
			assert(!script_classes.has(key))
			script_classes[key] = dict[key]
	emit_signal("project_objects_instantiated")

func init_project() -> void:
	for dict in [program_references, program_nodes, gui_top_nodes]:
		for key in dict:
			var object_key: String = key.rstrip("_").lstrip("_")
			var object: Object = objects[object_key]
			object.project_init() # ProjectBuilder instantiated must have this method!
	emit_signal("project_inited")
	yield(get_tree(), "idle_frame")
	emit_signal("init_step_finished")

func add_project_nodes() -> void:
	for key in program_nodes:
		var object_key = key.rstrip("_").lstrip("_")
		Global.add_child(objects[object_key])
	for key in gui_top_nodes:
		var object_key = key.rstrip("_").lstrip("_")
		gui_top.add_child(objects[object_key])
	emit_signal("project_nodes_added")
	yield(get_tree(), "idle_frame")
	emit_signal("init_step_finished")

func signal_finished() -> void:
	Global.emit_signal("project_builder_finished")

# ****************************** PROJECT BUILD ********************************

func _ready() -> void:
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