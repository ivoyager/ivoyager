# save_load_manager.gd
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
# To remove save/load functionality, set IVGlobal.enable_save_load = false. You
# can then (optionally) delete these from IVProjectBuilder:
#
#   - SaveManager
#   - SaveBuilder
#   - SaveDialog
#   - LoadDialog

extends Node
class_name SaveManager

const files := preload("res://ivoyager/static/files.gd")
const DPRINT := false
const NO_NETWORK = IVEnums.NetworkState.NO_NETWORK
const IS_SERVER = IVEnums.NetworkState.IS_SERVER
const IS_CLIENT = IVEnums.NetworkState.IS_CLIENT
const NetworkStopSync = IVEnums.NetworkStopSync

# persistence - values will be replaced by file values on game load!
var project_version: String = IVGlobal.project_version
var project_version_ymd: int = IVGlobal.project_version_ymd
var ivoyager_version: String = IVGlobal.IVOYAGER_VERSION
var ivoyager_version_ymd: int = IVGlobal.IVOYAGER_VERSION_YMD
var is_modded: bool = IVGlobal.is_modded

const PERSIST_AS_PROCEDURAL_OBJECT := false
const PERSIST_PROPERTIES := ["project_version", "project_version_ymd",
	"ivoyager_version", "ivoyager_version_ymd", "is_modded"]

# private
onready var _io_manager: IOManager = IVGlobal.program.IOManager
onready var _state_manager: StateManager = IVGlobal.program.StateManager
onready var _timekeeper: Timekeeper = IVGlobal.program.Timekeeper
onready var _save_builder: SaveBuilder = IVGlobal.program.SaveBuilder
onready var _universe: Spatial = IVGlobal.program.Universe
onready var _tree := get_tree()
var _state: Dictionary = IVGlobal.state
var _settings: Dictionary = IVGlobal.settings
var _enable_save_load: bool = IVGlobal.enable_save_load
var _has_been_saved := false


func save_quit() -> void:
	if _state.network_state == IS_CLIENT:
		return
	if quick_save():
		IVGlobal.connect("game_save_finished", _state_manager, "quit", [true])

func quick_save() -> bool:
	if _state.network_state == IS_CLIENT:
		return false
	if !_has_been_saved or !_settings.save_base_name or !files.is_valid_dir(_settings.save_dir):
		IVGlobal.emit_signal("save_dialog_requested")
		return false
	IVGlobal.emit_signal("close_main_menu_requested")
	var date_string := ""
	if _settings.append_date_to_save:
		date_string = _timekeeper.get_current_date_for_file()
	var path := files.get_save_path(_settings.save_dir, _settings.save_base_name,
			date_string, true)
	save_game(path)
	return true

func save_game(path := "") -> void:
	if _state.network_state == IS_CLIENT:
		return
	if !path:
		IVGlobal.emit_signal("save_dialog_requested")
		return
	print("Saving " + path)
	_state.last_save_path = path
	_state_manager.require_stop(self, NetworkStopSync.SAVE, true)
	yield(_state_manager, "threads_finished")
	IVGlobal.emit_signal("game_save_started")
	assert(IVDebug.dlog("Tree status before save..."))
	assert(IVDebug.dlog(_save_builder.debug_log(_universe)))
	var gamesave := _save_builder.generate_gamesave(_universe)
	_io_manager.store_var_to_file(gamesave, path, self, "_save_callback")
	IVGlobal.emit_signal("game_save_finished")
	_has_been_saved = true
	_state_manager.allow_run(self)

func quick_load() -> void:
	if _state.network_state == IS_CLIENT:
		return
	if _state.last_save_path:
		IVGlobal.emit_signal("close_main_menu_requested")
		load_game(_state.last_save_path)
	else:
		IVGlobal.emit_signal("load_dialog_requested")

func load_game(path := "", network_gamesave := []) -> void:
	if !network_gamesave and _state.network_state == IS_CLIENT:
		return
	if !network_gamesave and path == "":
		IVGlobal.emit_signal("load_dialog_requested")
		return
	var save_file: File
	if !network_gamesave:
		print("Loading " + path)
		save_file = File.new()
		if !save_file.file_exists(path):
			print("ERROR: Could not find " + path)
			return
	else:
		print("Loading game from network sync...")
	_state.is_splash_screen = false
	_state.is_system_built = false
	_state_manager.require_stop(_state_manager, NetworkStopSync.LOAD, true)
	yield(_state_manager, "threads_finished")
	_state.is_loaded_game = true
	IVGlobal.emit_signal("about_to_free_procedural_nodes")
	IVGlobal.emit_signal("game_load_started")
	yield(_tree, "idle_frame")
	_save_builder.free_procedural_nodes(_universe)
	# Give freeing procedural nodes time so they won't respond to game signals.
	yield(_tree, "idle_frame")
	yield(_tree, "idle_frame")
	yield(_tree, "idle_frame")
	yield(_tree, "idle_frame")
	yield(_tree, "idle_frame")
	yield(_tree, "idle_frame")
	if !network_gamesave:
		_io_manager.get_var_from_file(path, self, "_load_callback")
	else:
		_load_callback(network_gamesave, OK)

# *****************************************************************************
# IOManager callbacks

func _save_callback(err: int) -> void: # Main thread
	if err != OK:
		print("ERROR on Save; error code = ", err)

func _load_callback(gamesave: Array, err: int) -> void:
	if err != OK:
		print("ERROR on Load; error code = ", err)
		return # TODO: Exit and give user feedback
	_save_builder.build_tree(_universe, gamesave)
	_test_version()
	IVGlobal.emit_signal("game_load_finished")
	_state.is_system_built = true
	IVGlobal.emit_signal("system_tree_built_or_loaded", false)
	IVGlobal.connect("simulator_started", self, "_simulator_started_after_load", [], CONNECT_ONESHOT)

func _simulator_started_after_load() -> void:
	print("Nodes in tree after load & sim started: ", _tree.get_node_count())
	print("If differant than pre-save, set debug in save_builder.gd and check debug.log")
	assert(IVDebug.dlog("Tree status after load & simulator started..."))
	assert(IVDebug.dlog(_save_builder.debug_log(_universe)))

# *****************************************************************************

func _ready():
	IVGlobal.connect("save_requested", self, "_on_save_requested")
	IVGlobal.connect("load_requested", self, "_on_load_requested")
	IVGlobal.connect("save_quit_requested", self, "save_quit")

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
	if project_version != IVGlobal.project_version \
			or project_version_ymd != IVGlobal.project_version_ymd \
			or ivoyager_version != IVGlobal.IVOYAGER_VERSION \
			or ivoyager_version_ymd != IVGlobal.IVOYAGER_VERSION_YMD:
		print("WARNING! Loaded game was created with different program version...")
		prints(" ivoayger running: ", IVGlobal.IVOYAGER_VERSION, IVGlobal.IVOYAGER_VERSION_YMD)
		prints(" ivoyager loaded:  ", ivoyager_version, ivoyager_version_ymd)
		prints(" project running:  ", IVGlobal.project_version, IVGlobal.project_version_ymd)
		prints(" project loaded:   ", project_version, project_version_ymd)
