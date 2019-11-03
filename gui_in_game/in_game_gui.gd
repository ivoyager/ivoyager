# in_game_gui.gd
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
# Constructor and parent for in-game GUIs.

extends Control
class_name InGameGUI

# project vars - modify on "objects_instantiated" signal
var draggable_panels := true
var run_gui_classes := {
	selection_panel = SelectionPanel,
	navigation_panel = NavigationPanel,
	info_panel = InfoPanel,
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
onready var _registrar: Registrar = Global.objects.Registrar
onready var _file_helper: FileHelper = Global.objects.FileHelper
onready var _SelectionManager_: Script = Global.script_classes._SelectionManager_


func set_full_screen(is_hide_gui: bool) -> void:
	visible = !is_hide_gui

func project_init():
	hide()
	Global.connect("system_tree_built_or_loaded", self, "_on_system_tree_built_or_loaded")
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator")
	Global.connect("about_to_free_procedural_nodes", self, "_clear_procedural")
	Global.connect("show_hide_gui_requested", self, "_show_hide")
	Global.connect("toggle_show_hide_gui_requested", self, "_toggle_show_hide")
	set_anchors_and_margins_preset(PRESET_WIDE)
	mouse_filter = MOUSE_FILTER_IGNORE

func _clear_procedural() -> void:
	selection_manager = null
	gui_panels.clear()
	hide()

func _on_system_tree_built_or_loaded(is_new_game: bool) -> void:
	if is_new_game:
		selection_manager = _SelectionManager_.new()
		selection_manager.init_as_camera_selection()
		var start_selection: SelectionItem = _registrar.selection_items[Global.start_body_name]
		selection_manager.select(start_selection)
		for key in run_gui_classes:
			var gui_panel: Control = _file_helper.make_object_or_scene(run_gui_classes[key])
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

