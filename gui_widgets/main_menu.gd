# main_menu.gd
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
# GUI widget. Parent control should modify is_splash_config, if appropriate.
# To add buttons, use IVMainMenuManager (prog_refs/main_menu_manager.gd).
# The menu is built on project_builder_finished signal with all buttons
# disabled. Button state is updated on state_manager_inited signal.

extends VBoxContainer

var is_splash_config := false # splash screen needs to set this

var _state: Dictionary = IVGlobal.state
onready var _state_manager: StateManager = IVGlobal.program.StateManager
onready var _main_menu_manager: IVMainMenuManager = IVGlobal.program.MainMenuManager
onready var _button_infos: Array = _main_menu_manager.button_infos
var _is_project_built := false


func _ready() -> void:
	theme = IVGlobal.themes.main_menu
	IVGlobal.connect("project_builder_finished", self, "_on_project_builder_finished", [], CONNECT_ONESHOT)
	IVGlobal.connect("state_manager_inited", self, "_on_state_manager_inited", [], CONNECT_ONESHOT)
	_main_menu_manager.connect("buttons_changed", self, "_build")
	_main_menu_manager.connect("button_state_changed", self, "_update_button_states")
	connect("visibility_changed", self, "_grab_button_focus")

func _on_project_builder_finished() -> void:
	_is_project_built = true
	_build()

func _on_state_manager_inited() -> void:
	_update_button_states()
	_grab_button_focus()

func _clear() -> void:
	for child in get_children():
		child.queue_free()

func _build() -> void:
	if !_is_project_built:
		return
	_clear()
	for button_info in _button_infos:
		# [text, priority, is_splash_button, is_running_button, target_object, target_method, target_args, button_state]
		var is_splash_button: bool = button_info[2]
		var is_running_button: bool = button_info[3]
		if (is_splash_config and !is_splash_button) or (!is_splash_config and !is_running_button):
			continue
		var button := Button.new()
		var text: String = button_info[0]
		var target: Object = button_info[4]
		var method: String = button_info[5]
		var args: Array = button_info[6]
		var button_state: int = button_info[7]
		button.focus_mode = Control.FOCUS_ALL
		button.text = text
		button.connect("pressed", target, method, args)
		button.visible = button_state != _main_menu_manager.HIDDEN
		# disabled will be updated at state_manager_inited signal
		button.disabled = !_state.is_inited or button_state == _main_menu_manager.DISABLED
		add_child(button)

func _update_button_states() -> void:
	if !_state.is_inited:
		return
	for child in get_children():
		var button := child as Button
		if !button:
			continue
		for button_info in _button_infos:
			var text: String = button_info[0]
			if text == button.text:
				var button_state: int = button_info[7]
				button.visible = button_state != _main_menu_manager.HIDDEN
				button.disabled = button_state == _main_menu_manager.DISABLED
				break

func _grab_button_focus() -> void:
	# Only grabs if no one else has focus
	if !is_visible_in_tree():
		return
	if get_focus_owner():
		return
	for child in get_children():
		var button := child as Button
		if !button:
			continue
		if button.visible and !button.disabled and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus() # top menu button that is not disabled
			return
