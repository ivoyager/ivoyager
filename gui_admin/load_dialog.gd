# load_dialog.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield
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

extends FileDialog
class_name LoadDialog
const SCENE := "res://ivoyager/gui_admin/load_dialog.tscn"

const file_utils := preload("res://ivoyager/static/file_utils.gd")

# project var
var add_quick_load_button := true

var _state: Dictionary = Global.state
var _main_menu_manager: MainMenuManager

func _project_init():
	if !Global.enable_save_load:
		return
	_main_menu_manager = Global.program.MainMenuManager
	add_filter("*." + Global.save_file_extension + ";" + Global.save_file_extension_name)
	Global.connect("load_dialog_requested", self, "_open")
	Global.connect("system_tree_ready", self, "_on_system_tree_ready")
	Global.connect("game_save_finished", self, "_update_quick_load_button")
	Global.connect("close_all_admin_popups_requested", self, "hide")
	connect("file_selected", self, "_load_file")
	connect("popup_hide", self, "_on_hide")

func _ready():
	theme = Global.themes.main
	set_process_unhandled_key_input(false)

func _on_system_tree_ready(_is_new_game: bool) -> void:
	_update_quick_load_button()

func _open() -> void:
	set_process_unhandled_key_input(true)
	Global.emit_signal("sim_stop_required", self)
	popup_centered()
	access = ACCESS_FILESYSTEM
	var save_dir := file_utils.get_save_dir_path(Global.is_modded, Global.settings.save_dir)
	current_dir = save_dir
	if _state.last_save_path:
		current_path = _state.last_save_path
		deselect_items()

func _load_file(path: String) -> void:
	Global.emit_signal("close_main_menu_requested")
	Global.emit_signal("load_requested", path, false)

func _update_quick_load_button() -> void:
	if add_quick_load_button and _main_menu_manager:
		var button_state := _main_menu_manager.DISABLED
		if _state.last_save_path:
			button_state = _main_menu_manager.ACTIVE
		_main_menu_manager.change_button_state("BUTTON_QUICK_LOAD", button_state)

func _on_hide() -> void:
	set_process_unhandled_key_input(false)
	Global.emit_signal("sim_run_allowed", self)

func _unhandled_key_input(event: InputEventKey) -> void:
	_on_unhandled_key_input(event)

func _on_unhandled_key_input(event: InputEventKey) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		hide()
