# input_handler.gd
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
class_name IVInputHandler
extends Node

# Most actions are defined in prog_refs/input_map_manager.gd, not in
# project.godot!
#
# I, Voyager handles input in three  ways:
#   - here as _input()
#   - IVCameraHandler as _unhandled_input()
#   - various GUIs as _gui_input() or _unhandled_key_input()

const IS_CLIENT := IVEnums.NetworkState.IS_CLIENT

var _state: Dictionary = IVGlobal.state
var _script_classes: Dictionary = IVGlobal.script_classes
var _allow_time_reversal: bool = IVGlobal.allow_time_reversal
var _allow_dev_tools: bool = IVGlobal.allow_dev_tools
var _allow_fullscreen_toggle: bool = IVGlobal.allow_fullscreen_toggle
var _suppressors := []
var _selection_manager: IVSelectionManager

onready var _tree: SceneTree = get_tree()


func _ready():
	IVGlobal.connect("system_tree_ready", self, "_on_system_ready")
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_on_about_to_free_procedural_nodes")


func _on_system_ready(_is_new_game: bool) -> void:
	var project_gui = IVGlobal.program.ProjectGUI
	if "selection_manager" in project_gui:
		_selection_manager = project_gui.selection_manager


func _on_about_to_free_procedural_nodes() -> void:
	_selection_manager = null


func _input(event: InputEvent) -> void:
	_on_input(event)


func _on_input(event: InputEvent) -> void:
	if !event.is_action_type() or !event.is_pressed():
		return
	if _allow_dev_tools and _test_input_for_debug(event):
		return
	if _suppressors:
		return
	if !_state.is_running:
		return # main menu or some other admin GUI has input control
	# Order matters! E.g., cntr-S must be captured before S. This could be
	# troublesome for player modified hotkeys. One way to solve is to match
	# event.get_scancode_with_modifiers().
	if event.is_action_pressed("toggle_all_gui"):
		IVGlobal.emit_signal("toggle_show_hide_gui_requested")
	elif _allow_fullscreen_toggle and event.is_action_pressed("toggle_fullscreen"):
		OS.window_fullscreen = !OS.window_fullscreen


	elif _selection_manager:
		_input_for_selection_manager(event)
		return
	else:
		return # input NOT handled!
	_tree.set_input_as_handled()


func suppress(object: Object) -> void:
	_suppressors.append(object)


func unsuppress(object: Object) -> void:
	_suppressors.erase(object)


func make_action(action: String, is_pressed := true) -> void:
	# Cause an action as if a key was pressed or released. Many camera actions
	# require a release (is_pressed = false) after a press.
	var event := InputEventAction.new()
	event.action = action
	event.pressed = is_pressed
	_tree.input_event(event)


func _test_input_for_debug(event: InputEvent) -> bool:
	if _allow_dev_tools and event.is_action_pressed("emit_debug_signal"):
		IVGlobal.emit_signal("debug_pressed")
	else:
		return false # input NOT handled!
	_tree.set_input_as_handled()
	return true


func _input_for_selection_manager(event: InputEvent) -> void:
	if event.is_action_pressed("select_forward"):
		_selection_manager.forward()
	elif event.is_action_pressed("select_back"):
		_selection_manager.back()
	elif event.is_action_pressed("select_left"):
		_selection_manager.next_last(-1)
	elif event.is_action_pressed("select_right"):
		_selection_manager.next_last(1)
	elif event.is_action_pressed("select_up"):
		_selection_manager.up()
	elif event.is_action_pressed("select_down"):
		_selection_manager.down()
	elif event.is_action_pressed("next_star"):
		_selection_manager.next_last(1, _selection_manager.SELECTION_STAR)
	elif event.is_action_pressed("previous_planet"):
		_selection_manager.next_last(-1, _selection_manager.SELECTION_PLANET)
	elif event.is_action_pressed("next_planet"):
		_selection_manager.next_last(1, _selection_manager.SELECTION_PLANET)
	elif event.is_action_pressed("previous_nav_moon"):
		_selection_manager.next_last(-1, _selection_manager.SELECTION_NAVIGATOR_MOON)
	elif event.is_action_pressed("next_nav_moon"):
		_selection_manager.next_last(1, _selection_manager.SELECTION_NAVIGATOR_MOON)
	elif event.is_action_pressed("previous_moon"):
		_selection_manager.next_last(-1, _selection_manager.SELECTION_MOON)
	elif event.is_action_pressed("next_moon"):
		_selection_manager.next_last(1, _selection_manager.SELECTION_MOON)
	elif event.is_action_pressed("previous_spacecraft"):
		_selection_manager.next_last(-1, _selection_manager.SELECTION_SPACECRAFT)
	elif event.is_action_pressed("next_spacecraft"):
		_selection_manager.next_last(1, _selection_manager.SELECTION_SPACECRAFT)
	else:
		return # input NOT handled!
	_tree.set_input_as_handled()
