# load_dialog.gd
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

extends FileDialog
class_name LoadDialog
const SCENE := "res://ivoyager/gui_admin/load_dialog.tscn"

const files := preload("res://ivoyager/static/files.gd")

# project var
var add_quick_load_button := true

var _state: Dictionary = IVGlobal.state
var _main_menu_manager: IVMainMenuManager

func _project_init():
	if !IVGlobal.enable_save_load:
		return
	_main_menu_manager = IVGlobal.program.MainMenuManager
	add_filter("*." + IVGlobal.save_file_extension + ";" + IVGlobal.save_file_extension_name)
	IVGlobal.connect("load_dialog_requested", self, "_open")
	IVGlobal.connect("system_tree_ready", self, "_on_system_tree_ready")
	IVGlobal.connect("game_save_finished", self, "_update_quick_load_button")
	IVGlobal.connect("close_all_admin_popups_requested", self, "hide")
	connect("file_selected", self, "_load_file")
	connect("popup_hide", self, "_on_hide")

func _ready():
	theme = IVGlobal.themes.main
	set_process_unhandled_key_input(false)

func _on_system_tree_ready(_is_new_game: bool) -> void:
	_update_quick_load_button()

func _open() -> void:
	set_process_unhandled_key_input(true)
	IVGlobal.emit_signal("sim_stop_required", self)
	popup_centered()
	access = ACCESS_FILESYSTEM
	var save_dir := files.get_save_dir_path(IVGlobal.is_modded, IVGlobal.settings.save_dir)
	current_dir = save_dir
	if _state.last_save_path:
		current_path = _state.last_save_path
		deselect_items()

func _load_file(path: String) -> void:
	IVGlobal.emit_signal("close_main_menu_requested")
	IVGlobal.emit_signal("load_requested", path, false)

func _update_quick_load_button() -> void:
	if add_quick_load_button and _main_menu_manager:
		var button_state := _main_menu_manager.DISABLED
		if _state.last_save_path:
			button_state = _main_menu_manager.ACTIVE
		_main_menu_manager.change_button_state("BUTTON_QUICK_LOAD", button_state)

func _on_hide() -> void:
	set_process_unhandled_key_input(false)
	IVGlobal.emit_signal("sim_run_allowed", self)

func _unhandled_key_input(event: InputEventKey) -> void:
	_on_unhandled_key_input(event)

func _on_unhandled_key_input(event: InputEventKey) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		hide()
