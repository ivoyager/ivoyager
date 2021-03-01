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
# To remove save/load functionality, set Global.enable_save_load = false. You
# can then (optionally) delete these from ProjectBuilder:
#
#   - SaveManager
#   - SaveBuilder
#   - SaveDialog
#   - LoadDialog

extends Node
class_name SaveManager

const file_utils := preload("res://ivoyager/static/file_utils.gd")
const DPRINT := false
const NO_NETWORK = Enums.NetworkState.NO_NETWORK
const IS_SERVER = Enums.NetworkState.IS_SERVER
const IS_CLIENT = Enums.NetworkState.IS_CLIENT
const NetworkStopSync = Enums.NetworkStopSync


# persistence - values will be replaced by file values on game load!
var project_version: String = Global.project_version
var ivoyager_version: String = Global.ivoyager_version
var is_modded: bool = Global.is_modded

const PERSIST_AS_PROCEDURAL_OBJECT := false
const PERSIST_PROPERTIES := ["project_version", "ivoyager_version", "is_modded"]


# private
onready var _io_manager: IOManager = Global.program.IOManager
onready var _state_manager: StateManager = Global.program.StateManager
onready var _timekeeper: Timekeeper = Global.program.Timekeeper
onready var _save_builder: SaveBuilder = Global.program.SaveBuilder
onready var _main_prog_bar: MainProgBar = Global.program.get("MainProgBar")
onready var _universe: Spatial = Global.program.Universe
onready var _tree := get_tree()
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
	_state.last_save_path = path
	_state_manager.require_stop(self, NetworkStopSync.SAVE, true)
	yield(_state_manager, "threads_finished")
	Global.emit_signal("game_save_started")
	if _main_prog_bar:
		_main_prog_bar.start(_save_builder)
	assert(Debug.dlog("This is before save!"))
	assert(Debug.dlog(_save_builder.debug_log(_universe)))
	yield(_tree, "idle_frame")
	_io_manager.callback(self, "save_on_io_callback", "finish_save", [path])

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
	else:
		print("Loading game from network sync...")
	_state.is_splash_screen = false
	_state.is_system_built = false
	_state_manager.require_stop(_state_manager, NetworkStopSync.LOAD, true)
	yield(_state_manager, "threads_finished")
	_state.is_loaded_game = true
	Global.emit_signal("about_to_free_procedural_nodes")
	Global.emit_signal("game_load_started")
	yield(_tree, "idle_frame")
	_save_builder.free_procedural_nodes(_universe)
	# Give freeing procedural nodes time so they won't respond to game signals.
	yield(_tree, "idle_frame")
	yield(_tree, "idle_frame")
	yield(_tree, "idle_frame")
	yield(_tree, "idle_frame")
	yield(_tree, "idle_frame")
	yield(_tree, "idle_frame")
	if _main_prog_bar:
		_main_prog_bar.start(_save_builder)
	_io_manager.callback(self, "load_on_io_callback", "finish_load", [save_file, path, network_gamesave])

# *****************************************************************************
# IOManager callbacks

func save_on_io_callback(array: Array) -> void: # I/O thread
	var path: String = array[0]
	var save_file := File.new()
	save_file.open(path, File.WRITE)
	var gamesave := _save_builder.generate_gamesave(_universe)
	save_file.store_var(gamesave)

func finish_save(_array: Array) -> void: # Main thread
	Global.emit_signal("game_save_finished")
	if _main_prog_bar:
		_main_prog_bar.stop()
	_has_been_saved = true
	_state_manager.allow_run(self)

func load_on_io_callback(array: Array) -> void: # I/O thread
	var save_file: File = array[0]
	var path: String = array[1]
	var network_gamesave: Array = array[2]
	var gamesave: Array
	if !network_gamesave:
		save_file.open(path, File.READ)
		gamesave = save_file.get_var()
	else:
		gamesave = network_gamesave
	var base_procedurals := _save_builder.build_tree(_universe, gamesave, true)
	array.append(base_procedurals)
	
func finish_load(array: Array) -> void: # Main thread
	var base_procedurals: Array = array[3]
	while base_procedurals:
		var base_procedural: Node = base_procedurals.pop_front()
		_universe.add_child(base_procedural)
	_test_version()
	Global.emit_signal("game_load_finished")
	if _main_prog_bar:
		_main_prog_bar.stop()
	_state.is_system_built = true
	Global.emit_signal("system_tree_built_or_loaded", false)
	Global.connect("simulator_started", self, "_simulator_started_after_load", [], CONNECT_ONESHOT)

func _simulator_started_after_load() -> void:
	print("Nodes in tree after load: ", _tree.get_node_count(), ". If this differs from pre-save,",
			"\n  set debug settings in SaveBuilder and check debug.log.")
	assert(Debug.dlog("This is after load & simulator started!"))
	assert(Debug.dlog(_save_builder.debug_log(_universe)))

# *****************************************************************************

func project_init() -> void:
	pass

func _ready():
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
	if project_version != Global.project_version or ivoyager_version != Global.ivoyager_version:
		print("WARNING! Loaded game was created with a different version...")
		prints("Present running version: ", Global.ivoyager_version, Global.project_version)
		prints("Loaded game started as:  ", ivoyager_version, project_version)
