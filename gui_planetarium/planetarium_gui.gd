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
onready var _viewport := get_viewport()
var _mouse_trigger_guis := []
var _is_mouse_button_pressed := false

func project_init() -> void:
	Global.connect("system_tree_built_or_loaded", self, "_on_system_tree_built_or_loaded")
	Global.connect("simulator_exited", self, "_on_simulator_exited")

func register_mouse_trigger_guis(mouse_trigger: Control, guis: Array) -> void:
	_mouse_trigger_guis.append([mouse_trigger, guis])

func _ready() -> void:
	pass
#	theme = Global.themes.web

func _on_system_tree_built_or_loaded(_is_new_game: bool) -> void:
	selection_manager = _SelectionManager_.new()
	selection_manager.init_as_camera_selection()
	var registrar: Registrar = Global.objects.Registrar
	var start_selection: SelectionItem = registrar.selection_items[Global.start_body_name]
	selection_manager.select(start_selection)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _is_mouse_button_pressed:
			return
		var mouse_pos := _viewport.get_mouse_position()
		for mouse_trigger_gui in _mouse_trigger_guis:
			var mouse_trigger: Control = mouse_trigger_gui[0]
			var guis: Array = mouse_trigger_gui[1]
			var is_visible := mouse_trigger.get_global_rect().has_point(mouse_pos)
			if is_visible != guis[0].visible:
				for gui in guis:
					gui.visible = is_visible
					gui.mouse_filter = MOUSE_FILTER_PASS if is_visible else MOUSE_FILTER_IGNORE
	elif event is InputEventMouseButton:
		_is_mouse_button_pressed = event.pressed
