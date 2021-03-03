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
#   is_splash_screen: bool - this node & SaveManager
#   is_system_built: bool - this node & SaveManager
#   is_running: bool - _run/_stop_simulator(); is_running == !SceneTree.paused
#   is_paused: bool - Timekeeper maintains; NOT SceneTree.paused !!!!
#   is_quitting: bool
#   is_loaded_game: bool - this node & SaveManager
#   last_save_path: String - this node & SaveManager
#   network_state: Enums.NetworkState - if exists, NetworkLobby also writes
#
# Note: SceneTree.paused is set only when simulatator "stopped". Simulator
# "paused" is managed by Timekeeper and works more like a game speed (process
# still happens so the camera can move, etc.).
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

signal threads_allowed() # ok to start threads that affect gamestate
signal finish_threads_required() # finish threads that affect gamestate
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
var blocking_threads := []

# private
onready var _tree: SceneTree = get_tree()
var _state: Dictionary = Global.state
var _nodes_requiring_stop := []
var _signal_when_threads_finished := false


# Multithreading note: Godot's SceneTree and almost all I, Voyager public
# functions run in the main thread. Use call_defered() to invoke any function
# from another thread unless the function is guaranteed to be thread-safe. Most
# functions are NOT thread-safe!

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
		emit_signal("threads_finished")

func signal_threads_finished() -> void:
	# Generates a delayed "threads_finished" signal if/when there are no
	# blocking threads. Called by require_stop if not rejected.
	yield(_tree, "idle_frame")
	if !_signal_when_threads_finished:
		_signal_when_threads_finished = true
		remove_blocking_thread(null)

func require_stop(who: Object, network_sync_type := -1, bypass_checks := false) -> bool:
	# network_sync_type used only if we are the network server.
	# bypass_checks intended for this node & NetworkLobby; could break sync.
	# Returns false if the caller doesn't have authority to stop the sim.
	# "Stopped" means SceneTree is paused, the player is locked out from most
	# input, and we have signaled "finish_threads_required" (any Threads added
	# via add_blocking_thread() should then be removed as they finish).
	# In many cases, you should yield to "threads_finished" after calling this.
	if !bypass_checks:
		if !Global.popops_can_stop_sim and who is Popup:
			return false
		if _state.network_state == IS_CLIENT:
			return false
		elif _state.network_state == IS_SERVER:
			if Global.limit_stops_in_multiplayer:
				return false
	if _state.network_state == IS_SERVER:
		if network_sync_type != NetworkStopSync.DONT_SYNC:
			emit_signal("server_about_to_stop", network_sync_type)
	assert(DPRINT and prints("require_stop", who, network_sync_type) or true)
	if !_nodes_requiring_stop.has(who):
		_nodes_requiring_stop.append(who)
	if _state.is_running:
		_stop_simulator()
	signal_threads_finished()
	return true

func allow_run(who: Object) -> void:
	assert(DPRINT and prints("allow_run", who) or true)
	_nodes_requiring_stop.erase(who)
	if _state.is_running or _nodes_requiring_stop:
		return
	if _state.network_state == IS_SERVER:
		emit_signal("server_about_to_run")
	_run_simulator()

func exit(force_exit := false, following_server := false) -> void:
	# force_exit == true means we've confirmed and finished other preliminaries
	if Global.disable_exit:
		return
	if !force_exit:
		if _state.network_state == IS_CLIENT:
			OneUseConfirm.new("Disconnect from multiplayer game?", self, "exit", [true]) # TODO: text key
			return
		elif Global.enable_save_load: # single player or network server
			OneUseConfirm.new("LABEL_EXIT_WITHOUT_SAVING", self, "exit", [true])
			return
	if _state.network_state == IS_CLIENT:
		if !following_server:
			emit_signal("client_is_dropping_out", true)
	_state.is_splash_screen = true
	_state.is_system_built = false
	_state.is_running = false
	_tree.paused = true
	_state.is_loaded_game = false
	_state.last_save_path = ""
	require_stop(self, NetworkStopSync.EXIT, true)
	yield(self, "threads_finished")
	Global.emit_signal("about_to_exit")
	Global.emit_signal("about_to_free_procedural_nodes")
	yield(_tree, "idle_frame")
	SaveBuilder.free_procedural_nodes(Global.program.Universe)
	Global.emit_signal("close_all_admin_popups_requested")
	Global.emit_signal("simulator_exited")

func quit(force_quit := false) -> void:
	if Global.disable_quit:
		return
	if !force_quit:
		if _state.network_state == IS_CLIENT:
			OneUseConfirm.new("Disconnect from multiplayer game?", self, "quit", [true]) # TODO: text key
			return
		elif Global.enable_save_load and !_state.is_splash_screen:
			OneUseConfirm.new("LABEL_QUIT_WITHOUT_SAVING", self, "quit", [true])
			return
	if _state.network_state == IS_CLIENT:
		emit_signal("client_is_dropping_out", false)
	_state.is_quitting = true
	Global.emit_signal("about_to_quit")
	require_stop(self, NetworkStopSync.QUIT, true)
	yield(self, "threads_finished")
	assert(!print_stray_nodes())
	print("Quitting...")
	_tree.quit()
	# Below throws error as of early 2021. I think it's a browser change.
	# It's best for now to set Global.disable_quit (removes Quit button) in
	# HTML builds.
#	if Global.is_html5:
#		JavaScript.eval("window.close()")

# *****************************************************************************

func _init() -> void:
	_on_init()

func _on_init() -> void:
	_state.is_inited = false
	_state.is_splash_screen = true
	_state.is_system_built = false
	_state.is_running = false # SceneTree.pause set in ProjectBuilder
	_state.is_quitting = false
	_state.is_loaded_game = false
	_state.last_save_path = ""
	_state.network_state = NO_NETWORK

func _ready():
	_on_ready()

func _on_ready() -> void:
	Global.connect("project_builder_finished", self, "_finish_init", [], CONNECT_ONESHOT)
	Global.connect("about_to_build_system_tree", self, "_on_about_to_build_system_tree")
	Global.connect("system_tree_built_or_loaded", self, "_on_system_tree_built_or_loaded")
	Global.connect("system_tree_ready", self, "_on_system_tree_ready")
	Global.connect("sim_stop_required", self, "require_stop")
	Global.connect("sim_run_allowed", self, "allow_run")
	Global.connect("quit_requested", self, "quit")
	Global.connect("exit_requested", self, "exit")
	require_stop(self, -1, true)

func _finish_init() -> void:
	yield(_tree, "idle_frame")
	_state.is_inited = true
	print("StateManager inited...")
	Global.emit_signal("state_manager_inited")

func _on_about_to_build_system_tree() -> void:
	_state.is_splash_screen = false

func _on_system_tree_built_or_loaded(_is_new_game: bool) -> void:
	_state.is_system_built = true

func _on_system_tree_ready(is_new_game: bool) -> void:
	print("System tree ready...")
	yield(_tree, "idle_frame")
	Global.emit_signal("about_to_start_simulator", is_new_game)
	Global.emit_signal("close_all_admin_popups_requested")
	yield(_tree, "idle_frame")
	allow_run(self)
	yield(_tree, "idle_frame")
	Global.emit_signal("update_gui_needed")
	yield(_tree, "idle_frame")
	Global.emit_signal("simulator_started")

func _stop_simulator() -> void:
	# Project must ensure that state does not change during stop (in
	# particular, persist vars during save/load).
	print("Stop simulator")
	assert(DPRINT and prints("signal finish_threads_required") or true)
	allow_threads = false
	emit_signal("finish_threads_required")
	_state.is_running = false
	_tree.paused = true
	Global.emit_signal("run_state_changed", false)
	
func _run_simulator() -> void:
	print("Run simulator")
	_state.is_running = true
	_tree.paused = false
	Global.emit_signal("run_state_changed", true)
	assert(DPRINT and prints("signal threads_allowed") or true)
	allow_threads = true
	emit_signal("threads_allowed")

func _test_load_version_warning() -> void:
	if Global.current_project_version != Global.project_version \
			or Global.current_ivoyager_version != Global.ivoyager_version:
		print("WARNING! Loaded game was created with a different version...")
		prints("Present running version: ", Global.current_ivoyager_version,
				Global.current_project_version)
		prints("Loaded game started as:  ", Global.ivoyager_version, Global.project_version)

