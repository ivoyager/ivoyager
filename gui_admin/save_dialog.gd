# save_dialog.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
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
class_name SaveDialog
const SCENE := "res://ivoyager/gui_admin/save_dialog.tscn"

const file_utils := preload("res://ivoyager/static/file_utils.gd")

# project var
var add_quick_save_button := true

var _settings: Dictionary = Global.settings
onready var _settings_manager: SettingsManager = Global.program.SettingsManager
onready var _timekeeper: Timekeeper = Global.program.Timekeeper
var _state_manager: StateManager

func project_init() -> void:
	if !Global.enable_save_load:
		return
	_state_manager = Global.program.StateManager
	var main_menu_manager: MainMenuManager = Global.program.MainMenuManager
	main_menu_manager.make_button("BUTTON_SAVE_AS", 900, false, true, _state_manager, "save_game", [""])
	if add_quick_save_button:
		main_menu_manager.make_button("BUTTON_QUICK_SAVE", 800, false, true, _state_manager, "quick_save")
	add_filter("*." + Global.save_file_extension + ";" + Global.save_file_extension_name)
	Global.connect("save_dialog_requested", self, "_open")
	Global.connect("close_all_admin_popups_requested", self, "hide")
	connect("file_selected", self, "_save_file")
	connect("popup_hide", self, "_on_hide")

func _ready():
	theme = Global.themes.main
	set_process_unhandled_key_input(false)

func _open() -> void:
	set_process_unhandled_key_input(true)
	_state_manager.require_stop(self)
	popup_centered()
	access = ACCESS_FILESYSTEM
	var save_dir = file_utils.get_save_dir_path(Global.is_modded, _settings.save_dir)
	var date_string: String = _timekeeper.get_current_date_for_file() \
			if _settings.append_date_to_save else ""
	current_path = file_utils.get_save_path(save_dir, _settings.save_base_name, date_string, false)
	deselect_items()
	
func _save_file(path: String) -> void:
	var cache_settings := false
	var save_base_name := file_utils.get_base_file_name(current_file)
	if save_base_name != _settings.save_base_name:
		_settings_manager.change_current("save_base_name", save_base_name, true)
		cache_settings = true
	if current_dir != _settings.save_dir:
		_settings_manager.change_current("save_dir", current_dir, true)
		cache_settings = true
	if cache_settings:
		_settings_manager.cache_now()
	Global.emit_signal("close_main_menu_requested")
	_state_manager.save_game(path)

func _on_hide() -> void:
	set_process_unhandled_key_input(false)
	_state_manager.allow_run(self)

func _unhandled_key_input(event: InputEventKey) -> void:
	_on_unhandled_key_input(event)

func _on_unhandled_key_input(event: InputEventKey) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		hide()
