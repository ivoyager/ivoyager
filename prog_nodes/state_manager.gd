# state_manager.gd
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
# Maintains high-level simulator state and writes Global.state; only this node
# writes Global.state except where noted:
#
#   is_inited: bool
#   is_splash_screen: bool
#   is_system_built: bool
#   is_running: bool # follows _run_simulator() / _stop_simulator()
#   is_quitting: bool
#   is_loaded_game: bool
#   last_save_path: String
#   network_state: int (Enums.NetworkState) - if exists, NetworkLobby also writes
#
# There is no NetworkLobby in base I, Voyager. It's is a very application-
# specific manager that you'll have to code yourself, but see:
# https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
# Be sure to set Global.state.network_state and emit Global signal
# "network_state_changed".
#
# IMPORTANT! Non-main threads should coordinate with signals and functions here
# for thread-safety. We wait for all threads to finish before proceding to save,
# load, exit, quit, etc.

extends Node
class_name StateManager

signal active_threads_allowed() # can start threads in external projct
signal finish_threads_required() # finish threads for any external projects
signal threads_finished()
signal client_is_dropping_out(is_exit)
signal server_about_to_stop(network_sync_type) # Enums.NetworkStopSync; server only
signal server_about_to_run() # server only

const file_utils := preload("res://ivoyager/static/file_utils.gd")
const DPRINT := false
const NO_NETWORK = Enums.NetworkState.NO_NETWORK
const IS_SERVER = Enums.NetworkState.IS_SERVER
const IS_CLIENT = Enums.NetworkState.IS_CLIENT
const NetworkStopSync = Enums.NetworkStopSync

# public - read-only!
var allow_threads := false
var active_threads := []

# private
var _state: Dictionary = Global.state
var _settings: Dictionary = Global.settings
var _enable_save_load: bool = Global.enable_save_load
var _popops_can_stop_sim: bool = Global.popops_can_stop_sim
var _limit_stops_in_multiplayer: bool = Global.limit_stops_in_multiplayer
onready var _tree := get_tree()
onready var _saver_loader: SaverLoader = Global.program.get("SaverLoader")
onready var _main_prog_bar: MainProgBar = Global.program.get("MainProgBar")
onready var _system_builder: SystemBuilder = Global.program.SystemBuilder
onready var _environment_builder: EnvironmentBuilder = Global.program.EnvironmentBuilder
onready var _timekeeper: Timekeeper = Global.program.Timekeeper
var _has_been_saved := false
var _was_paused := false
var _nodes_requiring_stop := []

# Multithreading note: Godot's SceneTree and all I, Voyager public functions
# run in the main thread. Use call_defered() to invoke any function from
# another thread unless the function is guaranteed to be thread-safe (e.g,
# read-only). Most functions are NOT thread-safe!

func add_active_thread(thread: Thread) -> void:
	# Add before thread.start() if you want certain functions (e.g., save/load)
	# to wait until these are removed. This is essential for any thread that
	# might change persist data used in gamesave.
	active_threads.append(thread)

func remove_active_thread(thread: Thread) -> void:
	active_threads.erase(thread)

func signal_when_threads_finished() -> void:
	set_process(true) # next frame at soonest

func require_stop(who: Object, network_sync_type := -1, bypass_checks := false) -> bool:
	# network_sync_type used only if we are the network server.
	# bypass_checks intended for this node & NetworkLobby; could break sync.
	# Returns false if the caller doesn't have authority to stop the sim.
	if !bypass_checks:
		if !_popops_can_stop_sim and who is Popup:
			return false
		if _state.network_state == IS_CLIENT:
			return false
		elif _state.network_state == IS_SERVER:
			if _limit_stops_in_multiplayer:
				return false
	if _state.network_state == IS_SERVER:
		if network_sync_type != NetworkStopSync.DONT_SYNC:
			emit_signal("server_about_to_stop", network_sync_type)
	# "Stopped" means the game is paused, the player is locked out from most
	# input, and non-main threads have finished. In many cases you should yield
	# to "threads_finished" after calling this function before proceeding.
	assert(DPRINT and prints("require_stop", who, network_sync_type) or true)
	if !_nodes_requiring_stop.has(who):
		_nodes_requiring_stop.append(who)
	if _state.is_running:
		_stop_simulator()
	signal_when_threads_finished()
	return true

func allow_run(who: Object) -> void:
	assert(DPRINT and prints("allow_run", who) or true)
	_nodes_requiring_stop.erase(who)
	if _state.is_running or _nodes_requiring_stop:
		return
	if _state.network_state == IS_SERVER:
		emit_signal("server_about_to_run")
	_run_simulator()

func build_system_tree() -> void:
	require_stop(self, NetworkStopSync.BUILD_SYSTEM, true)
	_state.is_splash_screen = false
	Global.emit_signal("about_to_build_system_tree")
	_system_builder.build()
	yield(_system_builder, "finished")
	_state.is_system_built = true
	Global.emit_signal("system_tree_built_or_loaded", true)
	yield(_tree, "idle_frame")
	Global.emit_signal("system_tree_ready", true)
	yield(_tree, "idle_frame")
	Global.emit_signal("about_to_start_simulator", true)
	Global.emit_signal("close_all_admin_popups_requested")
	yield(_tree, "idle_frame")
	allow_run(self)
	Global.emit_signal("simulator_started")
	yield(_tree, "idle_frame")
	Global.emit_signal("gui_refresh_requested")

func exit(force_exit := false, following_server := false) -> void:
	# force_exit == true means we've confirmed and finished other preliminaries
	if Global.disable_exit:
		return
	if !force_exit:
		if _state.network_state == IS_CLIENT:
			OneUseConfirm.new("Disconnect from multiplayer game?", self, "exit", [true]) # TODO: text key
			return
		elif _enable_save_load: # single player or network server
			OneUseConfirm.new("LABEL_EXIT_WITHOUT_SAVING", self, "exit", [true])
			return
	if _state.network_state == IS_CLIENT:
		if !following_server:
			emit_signal("client_is_dropping_out", true)
	_state.is_splash_screen = true
	_state.is_system_built = false
	_state.is_running = false
	_state.is_loaded_game = false
	_state.last_save_path = ""
	require_stop(self, NetworkStopSync.EXIT, true)
	yield(self, "threads_finished")
	Global.emit_signal("about_to_exit")
	Global.emit_signal("about_to_free_procedural_nodes")
	yield(_tree, "idle_frame")
	SaverLoader.free_procedural_nodes(_tree.get_root())
	Global.emit_signal("close_all_admin_popups_requested")
	_was_paused = false
	Global.emit_signal("simulator_exited")

func quick_save() -> void:
	if _state.network_state == IS_CLIENT:
		return
	if _has_been_saved and _settings.save_base_name and file_utils.is_valid_dir(_settings.save_dir):
		Global.emit_signal("close_main_menu_requested")
		var date_string: String = _timekeeper.get_current_date_for_file() \
				if _settings.append_date_to_save else ""
		save_game(file_utils.get_save_path(_settings.save_dir, _settings.save_base_name,
				date_string, true))
	else:
		Global.emit_signal("save_dialog_requested")

func save_game(path: String) -> void:
	if _state.network_state == IS_CLIENT:
		return
	if !path:
		Global.emit_signal("save_dialog_requested")
		return
	print("Saving " + path)
	require_stop(self, NetworkStopSync.SAVE, true)
	yield(self, "threads_finished")
	assert(!print_stray_nodes())
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
	allow_run(self)

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
	require_stop(self, NetworkStopSync.LOAD, true)
	yield(self, "threads_finished")
	_state.is_loaded_game = true
	if _main_prog_bar:
		_main_prog_bar.start(_saver_loader)
	Global.emit_signal("about_to_free_procedural_nodes")
	Global.emit_signal("game_load_started")
	_saver_loader.load_game(save_file, _tree, network_gamesave)
	yield(_saver_loader, "finished")
	_test_load_version_warning()
	Global.emit_signal("game_load_finished")
	if _main_prog_bar:
		_main_prog_bar.stop()
	_was_paused = _settings.loaded_game_is_paused or _timekeeper.is_paused
	_state.is_system_built = true
	Global.emit_signal("system_tree_built_or_loaded", false)
	yield(_tree, "idle_frame")
	Global.emit_signal("system_tree_ready", false)
	yield(_tree, "idle_frame")
	assert(Debug.dlog("This is after load & system_tree_ready!"))
	assert(Debug.dlog(_saver_loader.debug_log(_tree)))
	assert(!print_stray_nodes())
	Global.emit_signal("about_to_start_simulator", false)
	Global.emit_signal("close_all_admin_popups_requested")
	yield(_tree, "idle_frame")
	allow_run(self)
	Global.emit_signal("simulator_started")
	yield(_tree, "idle_frame")
	Global.emit_signal("gui_refresh_requested")

func quit(force_quit: bool) -> void:
	if Global.disable_quit:
		return
	if !force_quit:
		if _state.network_state == IS_CLIENT:
			OneUseConfirm.new("Disconnect from multiplayer game?", self, "quit", [true]) # TODO: text key
			return
		elif _enable_save_load and !_state.is_splash_screen:
			OneUseConfirm.new("LABEL_QUIT_WITHOUT_SAVING", self, "quit", [true])
			return
	if _state.network_state == IS_CLIENT:
		emit_signal("client_is_dropping_out", false)
	_state.is_quitting = true
	require_stop(self, NetworkStopSync.QUIT, true)
	yield(self, "threads_finished")
	Global.emit_signal("about_to_quit")
	assert(!print_stray_nodes())
	print("Quitting...")
	_tree.quit()
	
	# below recently started throwing error; removed Quit button
#	if Global.is_html5:
#		JavaScript.eval("window.close()")

func save_quit() -> void:
	if _state.network_state == IS_CLIENT:
		return
	Global.connect("game_save_finished", self, "quit", [true])
	quick_save()

# *****************************************************************************

func project_init() -> void:
	pass

func _init() -> void:
	_on_init()

func _on_init() -> void:
	_state.is_inited = false
	_state.is_splash_screen = true
	_state.is_system_built = false
	_state.is_running = false
	_state.is_quitting = false
	_state.is_loaded_game = false
	_state.last_save_path = ""
	_state.network_state = NO_NETWORK

func _ready():
	_on_ready()

func _on_ready() -> void:
	Global.connect("project_builder_finished", self, "_on_project_builder_finished", [],
			CONNECT_ONESHOT)
	Global.connect("table_data_imported", self, "_finish_init", [], CONNECT_ONESHOT)
	Global.connect("sim_stop_required", self, "require_stop")
	Global.connect("sim_run_allowed", self, "allow_run")
	if _saver_loader:
		_saver_loader.use_thread = Global.use_threads
	set_process(false)
	require_stop(self, -1, true)

func _process(delta: float)-> void:
	_on_process(delta)

func _on_process(_delta: float)-> void:
	# We use only for _signal_when_threads_finished()
	if active_threads:
		return
	set_process(false)
	emit_signal("threads_finished")

func _on_project_builder_finished() -> void:
	yield(_tree, "idle_frame")
	_import_table_data()

func _import_table_data() -> void:
	var table_importer: TableImporter = Global.program.TableImporter
	table_importer.import_table_data()
	Global.program.erase("TableImporter")
	Global.emit_signal("table_data_imported")

func _finish_init() -> void:
	_environment_builder.add_world_environment() # this is really slow!!!
	yield(_tree, "idle_frame")
	_state.is_inited = true
	print("StateManager inited...")
	Global.emit_signal("state_manager_inited")
	if Global.skip_splash_screen:
		build_system_tree()

func _stop_simulator() -> void:
	# Project must ensure that state does not change during stop (in
	# particular, persist vars during save/load).
	print("Stop simulator")
	assert(DPRINT and prints("signal finish_threads_required") or true)
	allow_threads = false
	emit_signal("finish_threads_required")
	_was_paused = _tree.paused
	_tree.paused = true
	_state.is_running = false
	Global.emit_signal("run_state_changed", false)
	
func _run_simulator() -> void:
	print("Run simulator")
	_state.is_running = true
	Global.emit_signal("run_state_changed", true)
	_tree.paused = _was_paused
	assert(DPRINT and prints("signal active_threads_allowed") or true)
	allow_threads = true
	emit_signal("active_threads_allowed")

func _test_load_version_warning() -> void:
	if Global.current_project_version != Global.project_version \
			or Global.current_ivoyager_version != Global.ivoyager_version:
		print("WARNING! Loaded game was created with a different version...")
		prints("Present running version: ", Global.current_ivoyager_version,
				Global.current_project_version)
		prints("Loaded game started as:  ", Global.ivoyager_version, Global.project_version)

