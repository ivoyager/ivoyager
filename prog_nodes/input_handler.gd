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
# Most actions are defined in prog_refs/input_map_manager.gd, not in
# project.godot!
#
# I, Voyager handles input in three  ways:
#   - here as _input()
#   - VygrCameraHandler as _unhandled_input()
#   - various GUIs as _gui_input() or _unhandled_key_input()
#

extends Node
class_name InputHandler


const IS_CLIENT := Enums.NetworkState.IS_CLIENT


onready var _tree: SceneTree = get_tree()
onready var _huds_manager: HUDsManager = IVGlobal.program.HUDsManager
onready var _timekeeper: Timekeeper = IVGlobal.program.Timekeeper
var _selection_manager: SelectionManager
var _state: Dictionary = IVGlobal.state
var _script_classes: Dictionary = IVGlobal.script_classes
var _disable_pause: bool = IVGlobal.disable_pause
var _allow_time_reversal: bool = IVGlobal.allow_time_reversal
var _allow_dev_tools: bool = IVGlobal.allow_dev_tools
var _allow_fullscreen_toggle: bool = IVGlobal.allow_fullscreen_toggle
var _suppressors := []

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

# *****************************************************************************

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
	if _state.is_splash_screen and _state.is_inited:
		_input_for_splash_screen(event)
		return
	if !_state.is_running:
		return # main menu or some other admin GUI has input control
	# Order matters! E.g., cntr-S must be captured before S. This could be
	# troublesome for player modified hotkeys. One way to solve is to match
	# event.get_scancode_with_modifiers().
	if event.is_action_pressed("toggle_options"):
		IVGlobal.emit_signal("options_requested")
	elif event.is_action_pressed("toggle_hotkeys"):
		IVGlobal.emit_signal("hotkeys_requested")
	elif event.is_action_pressed("toggle_all_gui"):
		IVGlobal.emit_signal("toggle_show_hide_gui_requested")
	elif _allow_fullscreen_toggle and event.is_action_pressed("toggle_fullscreen"):
		OS.window_fullscreen = !OS.window_fullscreen
	elif event.is_action_pressed("quick_save"):
		IVGlobal.emit_signal("save_requested", "", true)
	elif event.is_action_pressed("save_as"):
		IVGlobal.emit_signal("save_requested", "", false)
	elif event.is_action_pressed("quick_load"):
		IVGlobal.emit_signal("load_requested", "", true)
	elif event.is_action_pressed("load_game"):
		IVGlobal.emit_signal("load_requested", "", false)
	elif event.is_action_pressed("quit"):
		IVGlobal.emit_signal("quit_requested", false)
	elif event.is_action_pressed("save_quit"):
		IVGlobal.emit_signal("save_quit_requested")
	elif !_disable_pause and event.is_action_pressed("toggle_pause"):
		if _state.network_state != IS_CLIENT:
			IVGlobal.emit_signal("pause_requested", false, true)
	elif event.is_action_pressed("incr_speed"):
		_timekeeper.change_speed(1)
	elif event.is_action_pressed("decr_speed"):
		_timekeeper.change_speed(-1)
	elif _allow_time_reversal and event.is_action_pressed("reverse_time"):
		_timekeeper.set_time_reversed(!_timekeeper.is_reversed)
	elif event.is_action_pressed("toggle_orbits"):
		_huds_manager.set_show_orbits(!_huds_manager.show_orbits)
	elif event.is_action_pressed("toggle_symbols"):
		_huds_manager.set_show_symbols(!_huds_manager.show_symbols)
	elif event.is_action_pressed("toggle_names"):
		_huds_manager.set_show_names(!_huds_manager.show_names)
	elif _selection_manager:
		_input_for_selection_manager(event)
		return
	else:
		return # input NOT handled!
	_tree.set_input_as_handled()

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

func _input_for_splash_screen(event: InputEvent) -> void:
	if event.is_action_pressed("load_game"):
		IVGlobal.emit_signal("load_requested", "", false)
	elif event.is_action_pressed("quick_load"):
		IVGlobal.emit_signal("load_requested", "", true)
	elif event.is_action_pressed("toggle_options"):
		IVGlobal.emit_signal("options_requested")
	elif event.is_action_pressed("toggle_hotkeys"):
		IVGlobal.emit_signal("hotkeys_requested")
	elif event.is_action_pressed("quit"):
		IVGlobal.emit_signal("quit_requested", true)
	else:
		return # input NOT handled!
	_tree.set_input_as_handled()

