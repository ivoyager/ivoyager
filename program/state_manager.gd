# state_manager.gd
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
class_name IVStateManager
extends Node

# Maintains high-level simulator state and writes IVGlobal.state; only this
# node writes IVGlobal.state except where noted.
#
# IVGlobal.state keys:
#   is_inited: bool
#   is_splash_screen: bool - this node & IVSaveManager
#   is_system_built: bool - this node & IVSaveManager
#   is_system_ready: bool
#	is_started_or_about_to_start: bool
#   is_running: bool - _run/_stop_simulator(); not the same as pause!
#   is_quitting: bool
#   is_game_loading: bool - this node & IVSaveManager (true while loading)
#   is_loaded_game: bool - this node & IVSaveManager (stays true after load)
#   last_save_path: String - this node & IVSaveManager
#   network_state: IVEnums.NetworkState - if exists, NetworkLobby also writes
#
# if IVGlobal.pause_only_stops_time == true, then PAUSE_MODE_PROCESS is
# set in Universe and TopGUI so IVCamera can still move, visuals work (some are
# responsve to camera) and user can interact with the world. In this mode, only
# IVTimekeeper pauses to stop time.
#
# There is no NetworkLobby in base I, Voyager. It's is a very application-
# specific manager that you'll have to code yourself, but see:
# https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
# Be sure to set IVGlobal.state.network_state and emit IVGlobal signal
# "network_state_changed".
#
# IMPORTANT! Non-main threads should coordinate with signals and functions here
# for thread-safety. We wait for all threads to finish before proceding to save,
# load, exit, quit, etc.
#
# Multithreading note: Godot's SceneTree and almost all I, Voyager public
# functions run in the main thread. Use call_defered() to invoke any function
# from another thread unless the function is guaranteed to be thread-safe. Most
# functions are NOT thread-safe!

signal run_threads_allowed() # ok to start threads that affect gamestate
signal run_threads_must_stop() # finish threads that affect gamestate
signal threads_finished() # all blocking threads removed
signal client_is_dropping_out(is_exit)
signal server_about_to_stop(network_sync_type) # IVEnums.NetworkStopSync; server only
signal server_about_to_run() # server only

const NO_NETWORK = IVEnums.NetworkState.NO_NETWORK
const IS_SERVER = IVEnums.NetworkState.IS_SERVER
const IS_CLIENT = IVEnums.NetworkState.IS_CLIENT
const NetworkStopSync = IVEnums.NetworkStopSync

const DPRINT := false

const PERSIST_MODE := IVEnums.PERSIST_PROPERTIES_ONLY
const PERSIST_PROPERTIES := ["is_user_paused"]

# persisted - read-only!
var is_user_paused := false # ignores pause from sim stop

# read-only!
var allow_threads := false
var blocking_threads := []

# private
var _state: Dictionary = IVGlobal.state
var _settings: Dictionary = IVGlobal.settings
var _nodes_requiring_stop := []
var _signal_when_threads_finished := false

@onready var _tree: SceneTree = get_tree()


# *****************************************************************************
# virtual functions

func _project_init() -> void:
	_state.is_inited = false
	_state.is_splash_screen = false
	_state.is_system_built = false
	_state.is_system_ready = false
	_state.is_started_or_about_to_start = false
	_state.is_running = false # SceneTree.pause set in IVProjectBuilder
	_state.is_quitting = false
	_state.is_game_loading = false
	_state.is_loaded_game = false
	_state.last_save_path = ""
	_state.network_state = NO_NETWORK


func _ready() -> void:
	_on_ready()


func _on_ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	IVGlobal.project_builder_finished.connect(_on_project_builder_finished, CONNECT_ONE_SHOT)
	IVGlobal.about_to_build_system_tree.connect(_on_about_to_build_system_tree)
	IVGlobal.system_tree_built_or_loaded.connect(_on_system_tree_built_or_loaded)
	IVGlobal.system_tree_ready.connect(_on_system_tree_ready)
	IVGlobal.simulator_exited.connect(_on_simulator_exited)
	IVGlobal.change_pause_requested.connect(change_pause)
	IVGlobal.sim_stop_required.connect(require_stop)
	IVGlobal.sim_run_allowed.connect(allow_run)
	IVGlobal.quit_requested.connect(quit)
	IVGlobal.exit_requested.connect(exit)
	_tree.paused = true
	require_stop(self, -1, true)


func _unhandled_key_input(event: InputEvent) -> void:
	_on_unhandled_key_input(event)


func _on_unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_pause"):
		change_pause()
	elif event.is_action_pressed(&"quit"):
		quit(false)
	else:
		return
	get_window().set_input_as_handled()


# *****************************************************************************
# public functions

func add_blocking_thread(thread: Thread) -> void:
	# Add before thread.start() if you want certain functions (e.g., save/load)
	# to wait until these are removed. This is essential for any thread that
	# might change persist data used in gamesave.
	if !blocking_threads.has(thread):
		blocking_threads.append(thread)


func remove_blocking_thread(thread: Thread) -> void:
	# Call on main thread after your thread has finished.
	if thread:
		blocking_threads.erase(thread)
	if _signal_when_threads_finished and !blocking_threads:
		_signal_when_threads_finished = false
		threads_finished.emit()


func signal_threads_finished() -> void:
	# Generates a delayed "threads_finished" signal if/when there are no
	# blocking threads. Called by require_stop if not rejected.
	await _tree.process_frame
	if !_signal_when_threads_finished:
		_signal_when_threads_finished = true
		remove_blocking_thread(null)


func change_pause(is_toggle := true, is_pause := true) -> void:
	# Only allowed if running and not otherwise prohibited.
	if _state.network_state == IS_CLIENT:
		return
	if !_state.is_running or IVGlobal.disable_pause:
		return
	is_user_paused = !_tree.paused if is_toggle else is_pause
	_tree.paused = is_user_paused
	IVGlobal.user_pause_changed.emit(is_user_paused)


func require_stop(who: Object, network_sync_type := -1, bypass_checks := false) -> bool:
	# network_sync_type used only if we are the network server.
	# bypass_checks intended for this node & NetworkLobby; could break sync.
	# Returns false if the caller doesn't have authority to stop the sim.
	# "Stopped" means SceneTree is paused, the player is locked out from most
	# input, and we have signaled "run_threads_must_stop" (any Threads added
	# via add_blocking_thread() should then be removed as they finish).
	# In many cases, you should yield to "threads_finished" after calling this.
	if !bypass_checks:
		if !IVGlobal.popops_can_stop_sim and who is Popup:
			return false
		if _state.network_state == IS_CLIENT:
			return false
		elif _state.network_state == IS_SERVER:
			if IVGlobal.limit_stops_in_multiplayer:
				return false
	if _state.network_state == IS_SERVER:
		if network_sync_type != NetworkStopSync.DONT_SYNC:
			server_about_to_stop.emit(network_sync_type)
	assert(!DPRINT or IVDebug.dprint("require_stop", who, network_sync_type))
	if !_nodes_requiring_stop.has(who):
		_nodes_requiring_stop.append(who)
	if _state.is_running:
		_stop_simulator()
	signal_threads_finished()
	return true


func allow_run(who: Object) -> void:
	assert(!DPRINT or IVDebug.dprint("allow_run", who))
	_nodes_requiring_stop.erase(who)
	if _state.is_running or _nodes_requiring_stop:
		return
	if _state.network_state == IS_SERVER:
		server_about_to_run.emit()
	_run_simulator()


func exit(force_exit := false, following_server := false) -> void:
	# force_exit == true means we've confirmed and finished other preliminaries
	if !_state.is_system_ready or IVGlobal.disable_exit:
		return
	if !force_exit:
		if _state.network_state == IS_CLIENT:
			IVOneUseConfirm.new("Disconnect from multiplayer game?", self, "exit", [true]) # TODO: text key
			return
		elif IVGlobal.enable_save_load: # single player or network server
			IVOneUseConfirm.new("LABEL_EXIT_WITHOUT_SAVING", self, "exit", [true])
			return
	if _state.network_state == IS_CLIENT:
		if !following_server:
			client_is_dropping_out.emit(true)
	_state.is_system_built = false
	_state.is_system_ready = false
	_state.is_started_or_about_to_start = false
	_state.is_running = false
	_tree.paused = true
	_state.is_loaded_game = false
	_state.last_save_path = ""
	require_stop(self, NetworkStopSync.EXIT, true)
	await self.threads_finished
	IVGlobal.about_to_exit.emit()
	IVGlobal.about_to_free_procedural_nodes.emit()
	await _tree.process_frame
	IVUtils.free_procedural_nodes(IVGlobal.program.Universe)
	IVGlobal.close_all_admin_popups_requested.emit()
	await _tree.process_frame
	_state.is_splash_screen = true
	IVGlobal.simulator_exited.emit()


func quit(force_quit := false) -> void:
	if !(_state.is_splash_screen or _state.is_system_ready) or IVGlobal.disable_quit:
		return
	if !force_quit:
		if _state.network_state == IS_CLIENT:
			IVOneUseConfirm.new("Disconnect from multiplayer game?", self, "quit", [true]) # TODO: text key
			return
		elif IVGlobal.enable_save_load and !_state.is_splash_screen:
			IVOneUseConfirm.new("LABEL_QUIT_WITHOUT_SAVING", self, "quit", [true])
			return
	if _state.network_state == IS_CLIENT:
		client_is_dropping_out.emit(false)
	_state.is_quitting = true
	IVGlobal.about_to_stop_before_quit.emit()
	require_stop(self, NetworkStopSync.QUIT, true)
	await threads_finished
	IVGlobal.about_to_quit.emit()
	assert(IVDebug.dprint_orphan_nodes())
	print("Quitting...")
	_tree.quit()


# *****************************************************************************
# private functions

func _on_project_builder_finished() -> void:
	await _tree.process_frame
	_state.is_inited = true
	_state.is_splash_screen = true
	IVGlobal.state_manager_inited.emit()


func _on_about_to_build_system_tree() -> void:
	_state.is_splash_screen = false


func _on_system_tree_built_or_loaded(_is_new_game: bool) -> void:
	_state.is_system_built = true
	_state.is_game_loading = false


func _on_system_tree_ready(is_new_game: bool) -> void:
	_state.is_system_ready = true
	print("System tree ready...")
	await _tree.process_frame
	_state.is_started_or_about_to_start = true
	IVGlobal.about_to_start_simulator.emit(is_new_game)
	IVGlobal.close_all_admin_popups_requested.emit()
	await _tree.process_frame
	allow_run(self)
	await _tree.process_frame
	IVGlobal.update_gui_requested.emit()
	await _tree.process_frame
	IVGlobal.simulator_started.emit()
	if !is_new_game and _settings.pause_on_load:
		is_user_paused = true


func _on_simulator_exited() -> void:
	is_user_paused = false


func _stop_simulator() -> void:
	# Project must ensure that state does not change during stop (in
	# particular, persist vars during save/load).
	print("Stop simulator")
	assert(!DPRINT or IVDebug.dprint("signal run_threads_must_stop"))
	allow_threads = false
	run_threads_must_stop.emit()
	_state.is_running = false
	_tree.paused = true
	IVGlobal.run_state_changed.emit(false)


func _run_simulator() -> void:
	print("Run simulator")
	_state.is_running = true
	_tree.paused = is_user_paused
	IVGlobal.run_state_changed.emit(true)
	assert(!DPRINT or IVDebug.dprint("signal run_threads_allowed"))
	allow_threads = true
	run_threads_allowed.emit()
	
