# save_dialog.gd
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
class_name IVSaveDialog
extends FileDialog
const SCENE := "res://ivoyager/gui_popups/save_dialog.tscn"

# Key actions for save/load are handled in save_manager.gd.

const files := preload("res://ivoyager/static/files.gd")

# project var
var add_quick_save_button := true

var _settings: Dictionary = IVGlobal.settings
var _blocking_windows: Array[Window] = IVGlobal.blocking_windows

@onready var _settings_manager: IVSettingsManager = IVGlobal.program[&"SettingsManager"]
@onready var _timekeeper: IVTimekeeper = IVGlobal.program[&"Timekeeper"]


func _project_init() -> void:
	if !IVGlobal.enable_save_load:
		return
	add_filter("*." + IVGlobal.save_file_extension + ";" + IVGlobal.save_file_extension_name)


func _ready():
	IVGlobal.save_dialog_requested.connect(_open)
	IVGlobal.close_all_admin_popups_requested.connect(_close)
	file_selected.connect(_save_file)
	canceled.connect(_on_canceled)
	theme = IVGlobal.themes.main
	_blocking_windows.append(self)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		set_input_as_handled()


func _open() -> void:
	if visible:
		return
	if !IVGlobal.state.is_started_or_about_to_start:
		return
	if _is_blocking_popup():
		return
	IVGlobal.sim_stop_required.emit(self)
	popup_centered()
	access = ACCESS_FILESYSTEM
	var save_dir := files.get_save_dir_path(IVGlobal.is_modded, _settings[&"save_dir"])
	var date_string: String = (_timekeeper.get_current_date_for_file()
			if _settings[&"append_date_to_save"] else "")
	current_path = files.get_save_path(save_dir, _settings[&"save_base_name"], date_string, false)
	deselect_all()


func _close() -> void:
	hide()
	_on_canceled()


func _save_file(path: String) -> void:
	var cache_settings := false
	var save_base_name := files.get_base_file_name(current_file)
	if save_base_name != _settings[&"save_base_name"]:
		_settings_manager.change_current(&"save_base_name", save_base_name, true)
		cache_settings = true
	if current_dir != _settings[&"save_dir"]:
		_settings_manager.change_current(&"save_dir", current_dir, true)
		cache_settings = true
	if cache_settings:
		_settings_manager.cache_now()
	IVGlobal.close_main_menu_requested.emit()
	IVGlobal.save_requested.emit(path, false)
	IVGlobal.sim_run_allowed.emit(self)


func _on_canceled() -> void:
	IVGlobal.sim_run_allowed.emit(self)


func _is_blocking_popup() -> bool:
	for window in _blocking_windows:
		if window.visible:
			return true
	return false

