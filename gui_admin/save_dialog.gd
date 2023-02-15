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
const SCENE := "res://ivoyager/gui_admin/save_dialog.tscn"

# Key actions for save/load are handled in save_manager.gd. This Control handles
# dialog request and only processes _input() when open.

const files := preload("res://ivoyager/static/files.gd")

# project var
var add_quick_save_button := true

var _settings: Dictionary = IVGlobal.settings
var _blocking_popups: Array = IVGlobal.blocking_popups

onready var _settings_manager: IVSettingsManager = IVGlobal.program.SettingsManager
onready var _timekeeper: IVTimekeeper = IVGlobal.program.Timekeeper


func _project_init() -> void:
	if !IVGlobal.enable_save_load:
		return
	add_filter("*." + IVGlobal.save_file_extension + ";" + IVGlobal.save_file_extension_name)
	IVGlobal.connect("save_dialog_requested", self, "_open")
	IVGlobal.connect("close_all_admin_popups_requested", self, "hide")
	connect("file_selected", self, "_save_file")
	connect("popup_hide", self, "_on_hide")


func _ready():
	theme = IVGlobal.themes.main
	set_process_input(false)
	_blocking_popups.append(self)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		hide()


func _open() -> void:
	if visible:
		hide()
		return
	if _is_blocking_popup():
		return
	set_process_input(true)
	IVGlobal.emit_signal("sim_stop_required", self)
	popup_centered()
	access = ACCESS_FILESYSTEM
	var save_dir := files.get_save_dir_path(IVGlobal.is_modded, _settings.save_dir)
	var date_string: String = _timekeeper.get_current_date_for_file() \
			if _settings.append_date_to_save else ""
	current_path = files.get_save_path(save_dir, _settings.save_base_name, date_string, false)
	deselect_items()


func _save_file(path: String) -> void:
	var cache_settings := false
	var save_base_name := files.get_base_file_name(current_file)
	if save_base_name != _settings.save_base_name:
		_settings_manager.change_current("save_base_name", save_base_name, true)
		cache_settings = true
	if current_dir != _settings.save_dir:
		_settings_manager.change_current("save_dir", current_dir, true)
		cache_settings = true
	if cache_settings:
		_settings_manager.cache_now()
	IVGlobal.emit_signal("close_main_menu_requested")
	IVGlobal.emit_signal("save_requested", path, false)


func _on_hide() -> void:
	set_process_input(false)
	IVGlobal.emit_signal("sim_run_allowed", self)


func _is_blocking_popup() -> bool:
	for popup in _blocking_popups:
		if popup.visible:
			return true
	return false
