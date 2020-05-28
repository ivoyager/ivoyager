# input_handler.gd
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
# I, Voyager handles input in three  ways:
#   - here as _input()
#   - various GUI as _gui_input() or _unhandled_key_input()
#   - BCameraInput as _unhandled_input()
#
# Most actions are defined at runtime by InputMapManager (not project.godot!).

extends Node
class_name InputHandler

var _state: Dictionary = Global.state
var _script_classes: Dictionary = Global.script_classes
var _disable_pause: bool
var _allow_time_reversal: bool
var _allow_dev_tools: bool
var _allow_fullscreen_toggle: bool
var _tree: SceneTree
var _main: Main
var _tree_manager: TreeManager
var _timekeeper: Timekeeper
var _selection_manager: SelectionManager
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

func project_init():
	Global.connect("system_tree_ready", self, "_on_system_ready")
	Global.connect("about_to_free_procedural_nodes", self, "_on_about_to_free_procedural_nodes")
	_disable_pause = Global.disable_pause
	_allow_time_reversal = Global.allow_time_reversal
	_allow_dev_tools = Global.allow_dev_tools
	_allow_fullscreen_toggle = Global.allow_fullscreen_toggle
	_tree = Global.program.tree
	_main = Global.program.Main
	_tree_manager = Global.program.TreeManager
	_timekeeper = Global.program.Timekeeper

func _on_system_ready(_is_new_game: bool) -> void:
	var project_gui = Global.program.ProjectGUI
	if "selection_manager" in project_gui:
		_selection_manager = project_gui.selection_manager

func _on_about_to_free_procedural_nodes() -> void:
	_selection_manager = null

func _input(event: InputEvent) -> void:
	_on_input(event)
	
func _on_input(event: InputEvent) -> void:
	if _suppressors:
		return
	if !event.is_action_type() or !event.is_pressed():
		return
	if _state.is_splash_screen and _state.is_inited:
		_input_for_splash_screen(event)
		return
	if !_state.is_running:
		return # e.g., main menu has input control
	
	# Order matters! E.g., cntr-S must be captured before S. This could be
	# troublesome for player modified hotkeys. One way to solve is to match
	# event.get_scancode_with_modifiers().
	if _allow_dev_tools and event.is_action_pressed("write_debug_logs_now"):
		Debug.force_logging()
	elif event.is_action_pressed("toggle_options"):
		Global.emit_signal("options_requested")
	elif event.is_action_pressed("toggle_hotkeys"):
		Global.emit_signal("hotkeys_requested")
	elif event.is_action_pressed("toggle_all_gui"):
		Global.emit_signal("toggle_show_hide_gui_requested")
	elif _allow_fullscreen_toggle and event.is_action_pressed("toggle_fullscreen"):
		OS.window_fullscreen = !OS.window_fullscreen
	elif event.is_action_pressed("quick_save"):
		_main.quick_save()
	elif event.is_action_pressed("save_as"):
		_main.save_game("")
	elif event.is_action_pressed("quick_load"):
		_main.quick_load()
	elif event.is_action_pressed("load_game"):
		_main.load_game("")
	elif event.is_action_pressed("quit"):
		_main.quit(false)
	elif event.is_action_pressed("save_quit"):
		_main.save_quit()
	elif !_disable_pause and event.is_action_pressed("toggle_pause"):
		_tree.paused = !_tree.paused
	elif event.is_action_pressed("incr_speed"):
		_timekeeper.change_speed(1)
	elif event.is_action_pressed("decr_speed"):
		_timekeeper.change_speed(-1)
	elif _allow_time_reversal and event.is_action_pressed("reverse_time"):
		_timekeeper.set_time_reversed(!_timekeeper.is_reversed)
	elif event.is_action_pressed("toggle_orbits"):
		_tree_manager.set_show_orbits(!_tree_manager.show_orbits)
	elif event.is_action_pressed("toggle_symbols"):
		_tree_manager.set_show_symbols(!_tree_manager.show_symbols)
	elif event.is_action_pressed("toggle_names"):
		_tree_manager.set_show_names(!_tree_manager.show_names)
	else:
		if _selection_manager:
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
		else:
			return # input NOT handled!
	_tree.set_input_as_handled()

func _input_for_splash_screen(event: InputEvent) -> void:
	if _allow_dev_tools and event.is_action_pressed("write_debug_logs_now"):
		Debug.force_logging()
	elif event.is_action_pressed("load_game") or event.is_action_pressed("quick_load"):
		_main.load_game("")
	elif event.is_action_pressed("toggle_options"):
		Global.emit_signal("options_requested")
	elif event.is_action_pressed("toggle_hotkeys"):
		Global.emit_signal("hotkeys_requested")
	elif event.is_action_pressed("quit"):
		_main.quit(true)
	else:
		return # input NOT handled!
	_tree.set_input_as_handled()

