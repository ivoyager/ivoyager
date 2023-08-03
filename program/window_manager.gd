# window_manager.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2023 Charlie Whitfield
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
class_name IVWindowManager
extends Node

# Handles Full Screen toggles. Optionally adds a menu button.

# TODO34: This node should signal changes and NOT reference IVMainMenuManager.

var add_menu_button := false
var button_priority := 1001

var _allow_fullscreen_toggle: bool = IVGlobal.allow_fullscreen_toggle
var _is_fullscreen := false
var _test_countdown := 0

@onready var _tree := get_tree()
@onready var _viewport := get_viewport()
@onready var _main_menu_manager: IVMainMenuManager = IVGlobal.program.MainMenuManager


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	if add_menu_button:
		_main_menu_manager.make_button("BUTTON_FULL_SCREEN", button_priority, false, true, self,
				"_change_fullscreen")
		_main_menu_manager.make_button("BUTTON_MINIMIZE", button_priority, false, true, self,
				"_change_fullscreen", [], _main_menu_manager.HIDDEN)
		IVGlobal.update_gui_requested.connect(_update_buttons)
		_viewport.size_changed.connect(_extended_test_for_screen_resize)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		_change_fullscreen()
		_viewport.set_input_as_handled()


func _change_fullscreen() -> void:
	if !_allow_fullscreen_toggle:
		return
	var is_fullscreen := ((get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN)
			or (get_window().mode == Window.MODE_FULLSCREEN))
	get_window().mode = (Window.MODE_EXCLUSIVE_FULLSCREEN if !is_fullscreen else Window.MODE_WINDOWED)


func _update_buttons() -> void:
	if _is_fullscreen == ((get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN)
			or (get_window().mode == Window.MODE_FULLSCREEN)):
		return
	_is_fullscreen = !_is_fullscreen
	if _is_fullscreen:
		_main_menu_manager.change_button_state("BUTTON_FULL_SCREEN", _main_menu_manager.HIDDEN)
		_main_menu_manager.change_button_state("BUTTON_MINIMIZE", _main_menu_manager.ACTIVE)
	else:
		_main_menu_manager.change_button_state("BUTTON_FULL_SCREEN", _main_menu_manager.ACTIVE)
		_main_menu_manager.change_button_state("BUTTON_MINIMIZE", _main_menu_manager.HIDDEN)


func _extended_test_for_screen_resize() -> void:
	# In some browsers OS.window_fullscreen takes a while to give changed
	# result. So we keep checking for a while.
	if _test_countdown: # already running
		_test_countdown = 20
		return
	_test_countdown = 20
	_update_buttons()
	while _test_countdown:
		await _tree.process_frame
		_update_buttons()
		_test_countdown -= 1
