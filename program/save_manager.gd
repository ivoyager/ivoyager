# save_load_manager.gd
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
class_name IVSaveManager
extends Node

# To remove save/load functionality, set IVGlobal.enable_save_load = false. You
# can then (optionally) delete these from IVProjectBuilder:
#
#   - _SaveManager_
#   - _SaveBuilder_
#   - _SaveDialog_
#   - _LoadDialog_

const files := preload("res://ivoyager/static/files.gd")
const NO_NETWORK = IVEnums.NetworkState.NO_NETWORK
const IS_SERVER = IVEnums.NetworkState.IS_SERVER
const IS_CLIENT = IVEnums.NetworkState.IS_CLIENT
const NetworkStopSync = IVEnums.NetworkStopSync

const DPRINT := false

const PERSIST_MODE := IVEnums.PERSIST_PROPERTIES_ONLY
const PERSIST_PROPERTIES := [
	"project_version",
	"project_ymd",
	"ivoyager_version",
	"ivoyager_ymd",
	"is_modded"
]
	
# persisted - values will be replaced by file values on game load!
var project_version: String = IVGlobal.project_version
var project_ymd: int = IVGlobal.project_ymd
var ivoyager_version: String = IVGlobal.IVOYAGER_VERSION
var ivoyager_ymd: int = IVGlobal.IVOYAGER_YMD
var is_modded: bool = IVGlobal.is_modded

# private
var _state: Dictionary = IVGlobal.state
var _settings: Dictionary = IVGlobal.settings
var _has_been_saved := false

@onready var _io_manager: IVIOManager = IVGlobal.program.IOManager
@onready var _state_manager: IVStateManager = IVGlobal.program.StateManager
@onready var _timekeeper: IVTimekeeper = IVGlobal.program.Timekeeper
@onready var _save_builder: IVSaveBuilder = IVGlobal.program.SaveBuilder
@onready var _universe: Node3D = IVGlobal.program.Universe


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	IVGlobal.save_requested.connect(_on_save_requested)
	IVGlobal.load_requested.connect(_on_load_requested)
	IVGlobal.save_quit_requested.connect(save_quit)


func _unhandled_key_input(event: InputEvent) -> void:
	if !event.is_action_type() or !event.is_pressed():
		return
	if event.is_action_pressed(&"quick_save"):
		_on_save_requested("", true)
	elif event.is_action_pressed(&"save_as"):
		_on_save_requested("", false)
	elif event.is_action_pressed(&"quick_load"):
		_on_load_requested("", true)
	elif event.is_action_pressed(&"load_game"):
		_on_load_requested("", false)
	elif event.is_action_pressed(&"save_quit"):
		save_quit()
	else:
		return
	get_viewport().set_input_as_handled()


func save_quit() -> void:
	if !_state.is_system_built:
		return
	if _state.network_state == IS_CLIENT:
		return
	if quick_save():
		IVGlobal.game_save_finished.connect(_state_manager.quit.bind(true))


func quick_save() -> bool:
	if !_state.is_system_built:
		return false
	if _state.network_state == IS_CLIENT:
		return false
	if !_has_been_saved or !_settings.save_base_name or !files.is_valid_dir(_settings.save_dir):
		IVGlobal.save_dialog_requested.emit()
		return false
	IVGlobal.close_main_menu_requested.emit()
	var date_string := ""
	if _settings.append_date_to_save:
		date_string = _timekeeper.get_current_date_for_file()
	var path := files.get_save_path(_settings.save_dir, _settings.save_base_name,
			date_string, true)
	save_game(path)
	return true


func save_game(path := "") -> void:
	if !_state.is_system_built:
		return
	if _state.network_state == IS_CLIENT:
		return
	if !path:
		IVGlobal.save_dialog_requested.emit()
		return
	print("Saving " + path)
	_state.last_save_path = path
	_state_manager.require_stop(self, NetworkStopSync.SAVE, true)
	await _state_manager.threads_finished
	IVGlobal.game_save_started.emit()
	assert(IVDebug.dlog("Tree status before save..."))
	assert(IVDebug.dlog(_save_builder.debug_log(_universe)))
	var gamesave := _save_builder.generate_gamesave(_universe)
	_io_manager.store_var_to_file(gamesave, path, self, "_save_callback")
	IVGlobal.game_save_finished.emit()
	_has_been_saved = true
	_state_manager.allow_run(self)


func quick_load() -> void:
	if !(_state.is_splash_screen or _state.is_system_built):
		return
	if _state.network_state == IS_CLIENT:
		return
	if _state.last_save_path:
		IVGlobal.close_main_menu_requested.emit()
		load_game(_state.last_save_path)
	else:
		IVGlobal.load_dialog_requested.emit()


func load_game(path := "", network_gamesave := []) -> void:
	if !(_state.is_splash_screen or _state.is_system_built):
		return
	if !network_gamesave and _state.network_state == IS_CLIENT:
		return
	if !network_gamesave and path == "":
		IVGlobal.load_dialog_requested.emit()
		return
	if !network_gamesave:
		print("Loading " + path)
		if !FileAccess.file_exists(path):
			print("ERROR: Could not find " + path)
			return
	else:
		print("Loading game from network sync...")
	_state.is_splash_screen = false
	_state.is_system_built = false
	_state_manager.require_stop(_state_manager, NetworkStopSync.LOAD, true)
	await _state_manager.threads_finished
	_state.is_game_loading = true
	_state.is_loaded_game = true
	IVGlobal.about_to_free_procedural_nodes.emit()
	IVGlobal.game_load_started.emit()
	await get_tree().process_frame
	IVUtils.free_procedural_nodes(_universe)
	# Give freeing procedural nodes time so they won't respond to game signals.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if !network_gamesave:
		_io_manager.get_var_from_file(path, self, "_load_callback")
	else:
		_load_callback(network_gamesave, OK)


# *****************************************************************************

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
			or project_ymd != IVGlobal.project_ymd \
			or ivoyager_version != IVGlobal.IVOYAGER_VERSION \
			or ivoyager_ymd != IVGlobal.IVOYAGER_YMD:
		print("WARNING! Loaded game was created with different program version...")
		prints(" ivoayger running: ", IVGlobal.IVOYAGER_VERSION, IVGlobal.IVOYAGER_YMD)
		prints(" ivoyager loaded:  ", ivoyager_version, ivoyager_ymd)
		prints(" project running:  ", IVGlobal.project_version, IVGlobal.project_ymd)
		prints(" project loaded:   ", project_version, project_ymd)


# *****************************************************************************
# IVIOManager callbacks

func _save_callback(err: int) -> void: # Main thread
	if err != OK:
		print("ERROR on Save; error code = ", err)


func _load_callback(gamesave: Array, err: int) -> void:
	if err != OK:
		print("ERROR on Load; error code = ", err)
		return # TODO: Exit and give user feedback
	_save_builder.build_tree(_universe, gamesave)
	_test_version()
	IVGlobal.game_load_finished.emit()
	_state.is_system_built = true
	IVGlobal.system_tree_built_or_loaded.emit(false)
	IVGlobal.simulator_started.connect(_simulator_started_after_load, CONNECT_ONE_SHOT)


func _simulator_started_after_load() -> void:
	print("Nodes in tree after load & sim started: ", get_tree().get_node_count())
	print("If differant than pre-save, set debug in save_builder.gd and check debug.log")
	assert(IVDebug.dlog("Tree status after load & simulator started..."))
	assert(IVDebug.dlog(_save_builder.debug_log(_universe)))

