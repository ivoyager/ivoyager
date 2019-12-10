# planetarium_gui.gd
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
# Constructor and parent for Planetarium-style GUIs.

extends Control
class_name PlanetariumGUI
const SCENE := "res://ivoyager/gui_planetarium/planetarium_gui.tscn"

onready var _SelectionManager_: Script = Global.script_classes._SelectionManager_
var selection_manager: SelectionManager

func project_init() -> void:
	Global.connect("system_tree_built_or_loaded", self, "_on_system_tree_built_or_loaded")

func _ready() -> void:
#	theme = Global.themes.global
	pass

func _on_system_tree_built_or_loaded(_is_new_game: bool) -> void:
	selection_manager = _SelectionManager_.new()
	selection_manager.init_as_camera_selection()
	var registrar: Registrar = Global.objects.Registrar
	var start_selection: SelectionItem = registrar.selection_items[Global.start_body_name]
	selection_manager.select(start_selection)

	# debug
#	var gui_panel: Control = SaverLoader.make_object_or_scene(NavigationPanel)
#	gui_panel.init(true, gui_panels, selection_manager)
#	gui_panels.append(gui_panel)
#	add_child(gui_panel)



