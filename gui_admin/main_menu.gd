# main_menu.gd
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

extends VBoxContainer
class_name MainMenu
const SCENE := "res://ivoyager/gui_admin/main_menu.tscn"

var button_infos := [] # shouldn't need but public just in case

var planetarium_mode := false

var _state: Dictionary = Global.state
var _main: Main

func make_button(text: String, priority: int, is_splash: bool, is_running: bool,
		press_object: Object, press_method: String, press_args := []) -> Button:
	# Highest priority is top.
	# is_splash & is_running have no effect if planetarium_mode
	var button := Button.new()
	button.text = text
	button.connect("pressed", press_object, press_method, press_args)
	button_infos.append([button, priority, is_splash, is_running])
	return button

func project_init():
	connect("ready", self, "_on_ready")
	if !planetarium_mode:
		Global.connect("open_main_menu_requested", self, "_open")
		Global.connect("close_main_menu_requested", self, "_close")
		Global.connect("system_tree_built_or_loaded", self, "_set_running_config")
		Global.connect("simulator_exited", self, "_set_splash_screen_config")
		theme = Global.themes.main_menu
	Global.connect("main_inited", self, "_on_main_inited", [], CONNECT_ONESHOT)
	_main = Global.program.Main
	if !Global.skip_splash_screen:
		make_button("BUTTON_START", 1000, true, false, self, "_on_start_pressed")
		make_button("BUTTON_EXIT", 300, false, true, _main, "exit", [false])
	if !Global.disable_quit:
		make_button("BUTTON_QUIT", 200, true, true, _main, "quit", [false])
	if !planetarium_mode:
		make_button("BUTTON_RESUME", 100, false, true, self, "_close")
	# Other admin GUI's init their own buttons

func _on_ready() -> void:
	button_infos.sort_custom(self, "_sort_button_infos")
	for button_info in button_infos:
		var button: Button = button_info[0]
		button.disabled = true
		add_child(button)
	if planetarium_mode:
		set_process_unhandled_key_input(false)
		show()
	elif Global.skip_splash_screen:
		_set_running_config(true)
	else:
		_set_splash_screen_config()

func _sort_button_infos(a: Array, b: Array) -> bool:
	return a[1] > b[1] # priority

func _set_splash_screen_config() -> void:
	for button_info in button_infos:
		var button: Button = button_info[0]
		var is_splash: bool = button_info[2]
		button.visible = is_splash
	_open()
	
func _set_running_config(_is_new_game: bool) -> void:
	for button_info in button_infos:
		var button: Button = button_info[0]
		var is_running: bool = button_info[3]
		button.visible = is_running
	_close()

func _on_main_inited() -> void:
	for button_info in button_infos:
		var button: Button = button_info[0]
		button.disabled = false
	_grab_focus()
	
func _grab_focus() -> void:
	for child in get_children():
		if child is Button and child.visible and !child.disabled:
			child.grab_focus() # top menu button
			break

func _on_start_pressed() -> void:
	_close()
	_main.build_system_tree()

func _toggle_open_close() -> void:
	if is_visible_in_tree():
		_close()
	else:
		_open()
		
func _open() -> void:
	_main.require_stop(self)
	Global.emit_signal("show_hide_gui_requested", false)
	show()
	_grab_focus()

func _close() -> void:
	hide()
	Global.emit_signal("show_hide_gui_requested", true) # always show again
	_main.allow_run(self)

func _unhandled_key_input(event: InputEventKey) -> void:
	_on_unhandled_key_input(event)
	
func _on_unhandled_key_input(event: InputEventKey) -> void:
	if event.is_action_pressed("ui_cancel") and !_state.is_splash_screen:
		get_tree().set_input_as_handled()
		_toggle_open_close()
