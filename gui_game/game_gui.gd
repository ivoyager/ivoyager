# game_gui.gd
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
# Constructor and parent for game-style GUIs.

extends Control
class_name GameGUI

# project vars - modify on objects_instantiated signal
var draggable_panels := true
var run_gui_classes := {
	selection_panel = SelectionPanel,
	navigation_panel = NavigationPanel,
	}

# persisted
var selection_manager: SelectionManager
var gui_panels := []
const PERSIST_AS_PROCEDURAL_OBJECT := false
const PERSIST_OBJ_PROPERTIES := ["selection_manager", "gui_panels"]

# unpersisted
var last_focus: Control

var _bypass_focus := true
var _settings: Dictionary = Global.settings
var _state: Dictionary = Global.state
onready var _tree: SceneTree = get_tree()
onready var _root: Viewport = _tree.get_root()
onready var _registrar: Registrar = Global.program.Registrar
onready var _SelectionManager_: Script = Global.script_classes._SelectionManager_


func set_full_screen(is_hide_gui: bool) -> void:
	visible = !is_hide_gui

func project_init():
	Global.connect("project_builder_finished", self, "_on_project_builder_finished",
			[], CONNECT_ONESHOT)
	Global.connect("system_tree_built_or_loaded", self, "_on_system_tree_built_or_loaded")
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator")
	Global.connect("about_to_free_procedural_nodes", self, "_clear_procedural")
	Global.connect("show_hide_gui_requested", self, "_show_hide")
	Global.connect("toggle_show_hide_gui_requested", self, "_toggle_show_hide")
	set_anchors_and_margins_preset(PRESET_WIDE)
	mouse_filter = MOUSE_FILTER_IGNORE
	hide()

func _on_project_builder_finished() -> void:
	theme = Global.themes.main

func _clear_procedural() -> void:
	# remove game GUI on exit or before load
	selection_manager = null
	gui_panels.clear()
	hide()

func _on_system_tree_built_or_loaded(is_new_game: bool) -> void:
	if is_new_game: # rebuild game GUI
		selection_manager = _SelectionManager_.new()
		var start_selection: SelectionItem = _registrar.selection_items[Global.start_body_name]
		selection_manager.select(start_selection)
		for key in run_gui_classes:
			var gui_panel: Control = SaverLoader.make_object_or_scene(run_gui_classes[key])
			gui_panel.init(draggable_panels, gui_panels, selection_manager)
			gui_panels.append(gui_panel)
			add_child(gui_panel)
	else:
		for gui_panel in gui_panels:
			gui_panel.init(draggable_panels, gui_panels, null)

func _on_about_to_start_simulator(_is_new_game: bool) -> void:
	show()

func _show_hide(is_show: bool) -> void:
	visible = is_show
	
func _toggle_show_hide() -> void:
	if Global.state.is_running:
		visible = !visible

func _input(event: InputEvent) -> void:
	_on_input(event)
	
func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and !event.pressed and _settings.mouse_action_releases_gui_focus:
		# This is a hack to simulate a FOCUS_KEYBOARD mode (= FOCUS_ALL minus
		# FOCUS_CLICK) which we don't have.
		_release_gui_focus()
		return # don't consume this event
	if not event is InputEventKey or !event.is_pressed() or !is_visible_in_tree():
		return
	if event.is_action_pressed("release_gui_focus"):
		_release_gui_focus()
	elif _bypass_focus and event.is_action_pressed("obtain_gui_focus"):
		_obtain_gui_focus()
	else:
		return # nothing handled
	_tree.set_input_as_handled()

func _release_gui_focus() -> void:
	if !_state.is_running:
		return
	_bypass_focus = true
	var focus := get_focus_owner()
	if focus:
		last_focus = focus
		focus.release_focus()

func _obtain_gui_focus() -> void:
	if last_focus == null or !last_focus.is_visible_in_tree():
		if !_find_control_for_focus(self):
			return
	_bypass_focus = false
	last_focus.grab_focus()

func _find_control_for_focus(control: Control) -> bool:
	for child in control.get_children():
		if child.focus_mode != FOCUS_NONE and child.is_visible_in_tree():
			last_focus = child
			return true
		elif _find_control_for_focus(child):
			return true
	return false

