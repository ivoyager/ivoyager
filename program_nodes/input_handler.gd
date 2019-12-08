# input_handler.gd
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
#
# I, Voyager handles input in these ways:
#   - here as _input()
#   - VoyagerCamera as _unhandled_input() [various mouse & key actions]
#   - InGameGUI as _input()
#   - MainMenu & popups as _unhandled_key_input() [to capture ESC]
#   - UIs as _gui_input
# Actions can be defined or modified in InputMapManager.

extends Node
class_name InputHandler

var _state: Dictionary = Global.state
var _settings: Dictionary = Global.settings
var _script_classes: Dictionary = Global.script_classes
var _allow_dev_tools: bool = Global.allow_dev_tools
var _toggle_real_time_not_pause: bool = Global.toggle_real_time_not_pause
var _tree: SceneTree
var _main: Main
var _tree_manager: TreeManager
var _in_game_gui: Control
var _timekeeper: Timekeeper
var _file_helper: FileHelper
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
	_tree = Global.objects.tree
	_main = Global.objects.Main
	_tree_manager = Global.objects.TreeManager
	_in_game_gui = Global.objects.InGameGUI
	_timekeeper = Global.objects.Timekeeper
	_file_helper = Global.objects.FileHelper

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
		return # e.g., main menu is up (it should handle allowed actions)
	
	# Order matters! E.g., cntr-S must be captured before S. This could be
	# troublesome for player modified hotkeys. One way to solve is to match
	# event.get_scancode_with_modifiers().
	if _allow_dev_tools and event.is_action_pressed("write_debug_logs_now"):
		Debug.force_logging()
	elif event.is_action_pressed("toggle_options"):
		Global.emit_signal("options_requested")
	elif event.is_action_pressed("toggle_hotkeys"):
		Global.emit_signal("hotkeys_requested")
	elif event.is_action_pressed("toggle_full_screen"):
		Global.emit_signal("toggle_show_hide_gui_requested")
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
	elif event.is_action_pressed("toggle_pause_or_real_time"):
		if _toggle_real_time_not_pause:
			_timekeeper.set_real_time(!_timekeeper.is_real_time())
		else:
			_tree.paused = !_tree.paused
	elif event.is_action_pressed("incr_speed"):
		_timekeeper.increment_speed(1)
	elif event.is_action_pressed("decr_speed"):
		_timekeeper.increment_speed(-1)
	elif event.is_action_pressed("reverse_time"):
		_timekeeper.reverse_time()
	elif event.is_action_pressed("toggle_orbits"):
		_tree_manager.set_show_orbits(!_tree_manager.show_orbits)
	elif event.is_action_pressed("toggle_icons"):
		_tree_manager.set_show_icons(!_tree_manager.show_icons)
	elif event.is_action_pressed("toggle_labels"):
		_tree_manager.set_show_labels(!_tree_manager.show_labels)
#	elif event.is_action_pressed("select_system"):
#		pass
#	elif event.is_action_pressed("previous_star"):
#		_in_game_gui.selection_manager.toggle_type(-1, Global.SYSTEM_STAR)
#	elif event.is_action_pressed("next_star"):
#		_in_game_gui.selection_manager.toggle_type(1, Global.SYSTEM_STAR)
#	elif event.is_action_pressed("previous_planet"):
#		_in_game_gui.selection_manager.toggle_type(-1, Global.SYSTEM_PLANET, Global.SYSTEM_DWARF_PLANET)
#	elif event.is_action_pressed("next_planet"):
#		_in_game_gui.selection_manager.toggle_type(1, Global.SYSTEM_PLANET, Global.SYSTEM_DWARF_PLANET)
#	elif event.is_action_pressed("previous_moon"):
#		_in_game_gui.selection_manager.toggle_type(-1, Global.SYSTEM_MOON, Global.SYSTEM_MINOR_MOON)
#	elif event.is_action_pressed("next_moon"):
#		_in_game_gui.selection_manager.toggle_type(1, Global.SYSTEM_MOON, Global.SYSTEM_MINOR_MOON)
	elif event.is_action_pressed("select_forward"):
		pass
	elif event.is_action_pressed("select_back"):
		pass
	elif event.is_action_pressed("select_left"):
		_in_game_gui.selection_manager.toggle(-1)
	elif event.is_action_pressed("select_right"):
		_in_game_gui.selection_manager.toggle(1)
	elif event.is_action_pressed("select_up"):
		_in_game_gui.selection_manager.up()
	elif event.is_action_pressed("select_down"):
		_in_game_gui.selection_manager.down()
	else:
		return
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
		return
	_tree.set_input_as_handled()

