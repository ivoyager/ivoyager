# save_load_manager.gd
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
# To remove save/load functionality, set Global.enable_save_load = false and
# delete these from ProjectBuilder:
#   - SaveLoadManager
#   - SaverLoader
#   - SaveDialog
#   - LoadDialog

class_name SaveLoadManager

const file_utils := preload("res://ivoyager/static/file_utils.gd")
const DPRINT := false
const NO_NETWORK = Enums.NetworkState.NO_NETWORK
const IS_SERVER = Enums.NetworkState.IS_SERVER
const IS_CLIENT = Enums.NetworkState.IS_CLIENT
const NetworkStopSync = Enums.NetworkStopSync

var _io_manager: IOManager
var _state_manager: StateManager
var _timekeeper: Timekeeper
var _saver_loader: SaverLoader
var _main_prog_bar: MainProgBar
var _tree := Global.get_tree()
var _state: Dictionary = Global.state
var _settings: Dictionary = Global.settings
var _enable_save_load: bool = Global.enable_save_load

var _has_been_saved := false


func save_quit() -> void:
	if _state.network_state == IS_CLIENT:
		return
	if quick_save():
		Global.connect("game_save_finished", _state_manager, "quit", [true])

func quick_save() -> bool:
	if _state.network_state == IS_CLIENT:
		return false
	if !_has_been_saved or !_settings.save_base_name or !file_utils.is_valid_dir(_settings.save_dir):
		Global.emit_signal("save_dialog_requested")
		return false
	Global.emit_signal("close_main_menu_requested")
	var date_string := ""
	if _settings.append_date_to_save:
		date_string = _timekeeper.get_current_date_for_file()
	var path := file_utils.get_save_path(_settings.save_dir, _settings.save_base_name,
			date_string, true)
	save_game(path)
	return true

func save_game(path: String) -> void:
	if _state.network_state == IS_CLIENT:
		return
	if !path:
		Global.emit_signal("save_dialog_requested")
		return
	print("Saving " + path)
	_state_manager.require_stop(self, NetworkStopSync.SAVE, true)
	yield(_state_manager, "threads_finished")
	assert(Debug.dlog("This is before save!"))
	assert(Debug.dlog(_saver_loader.debug_log(_tree)))
	var save_file := File.new()
	save_file.open(path, File.WRITE)
	_state.last_save_path = path
	if _main_prog_bar:
		_main_prog_bar.start(_saver_loader)
	Global.emit_signal("game_save_started")
	_saver_loader.save_game(save_file, _tree)
	yield(_saver_loader, "finished")
	Global.emit_signal("game_save_finished")
	if _main_prog_bar:
		_main_prog_bar.stop()
	_has_been_saved = true
	_state_manager.allow_run(self)

func quick_load() -> void:
	if _state.network_state == IS_CLIENT:
		return
	if _state.last_save_path:
		Global.emit_signal("close_main_menu_requested")
		load_game(_state.last_save_path)
	else:
		Global.emit_signal("load_dialog_requested")

func load_game(path: String, network_gamesave := []) -> void:
	if !network_gamesave and _state.network_state == IS_CLIENT:
		return
	if !network_gamesave and path == "":
		Global.emit_signal("load_dialog_requested")
		return
	var save_file: File
	if !network_gamesave:
		print("Loading " + path)
		save_file = File.new()
		if !save_file.file_exists(path):
			print("ERROR: Could not find " + path)
			return
		save_file.open(path, File.READ)
	else:
		print("Loading game from network sync...")
	_state.is_splash_screen = false
	_state.is_system_built = false
	_state_manager.require_stop(_state_manager, NetworkStopSync.LOAD, true)
#	_state_manager.signal_threads_finished()
	yield(_state_manager, "threads_finished")
	_state.is_loaded_game = true
	if _main_prog_bar:
		_main_prog_bar.start(_saver_loader)
	Global.emit_signal("about_to_free_procedural_nodes")
	Global.emit_signal("game_load_started")
	_saver_loader.load_game(save_file, _tree, network_gamesave)
	yield(_saver_loader, "finished")
	_test_version()
	Global.emit_signal("game_load_finished")
	if _main_prog_bar:
		_main_prog_bar.stop()
	assert(Debug.dlog("This is after load & system_tree_ready!"))
	assert(Debug.dlog(_saver_loader.debug_log(_tree)))
	assert(!Global.print_stray_nodes())
	_state.is_system_built = true
	Global.emit_signal("system_tree_built_or_loaded", false)

# *****************************************************************************

func project_init() -> void:
	_state_manager = Global.program.StateManager
	_io_manager = Global.program.IOManager
	_timekeeper = Global.program.Timekeeper
	_saver_loader = Global.program.get("SaverLoader")
	_main_prog_bar = Global.program.get("MainProgBar")
	Global.connect("save_requested", self, "_on_save_requested")
	Global.connect("load_requested", self, "_on_load_requested")
	Global.connect("save_quit_requested", self, "save_quit")

func _on_save_requested(path: String, is_quick_save := false) -> void:
	if path or !is_quick_save:
		save_game(path)
	else:
		quick_save()

func _on_load_requested(path: String, is_quick_load := false) -> void:
	if path or !is_quick_load:
		load_game(path)
	else:
		quick_load()

func _test_version() -> void:
	if Global.current_project_version != Global.project_version \
			or Global.current_ivoyager_version != Global.ivoyager_version:
		print("WARNING! Loaded game was created with a different version...")
		prints("Present running version: ", Global.current_ivoyager_version,
				Global.current_project_version)
		prints("Loaded game started as:  ", Global.ivoyager_version, Global.project_version)


