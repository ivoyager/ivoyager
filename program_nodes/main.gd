# main.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2019 Charlie Whitfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# *****************************************************************************
#
# Maintains high-level simulator state. Non-main thread starts/finishes should
# coordinate with signals and methods here. 

extends Node
class_name Main

# debug
const DPRINT := false

signal active_threads_allowed()
signal finish_threads_requested()
signal threads_finished()

# ******************************* PERSISTED ***********************************

var project_version := "" # external project can set for save debuging
var ivoyager_version := "dev"
var is_modded := false # this is aspirational

const PERSIST_AS_PROCEDURAL_OBJECT := false
const PERSIST_PROPERTIES := ["project_version", "ivoyager_version", "is_modded"]

# ****************************** UNPERSISTED **********************************

var _state: Dictionary = Global.state
var _settings: Dictionary = Global.settings
var _tree: SceneTree
var _gui_top: GUITop
var _table_reader: TableReader
var _saver_loader: SaverLoader
var _main_prog_bar: MainProgBar
var _system_builder: SystemBuilder
var _timekeeper: Timekeeper
var _file_helper: FileHelper
var _has_been_saved := false
var _was_paused := false
var _nodes_requiring_stop := []
var _active_threads := []

# DEPRECIATE
var _threads := []

# *************************** PUBLIC FUNCTIONS ********************************
# Multithreading note: Godot's SceneTree and all I, Voyager public functions
# run in the main thread. Use call_defered() to invoke any function from
# another thread unless the function is guaranteed to be thread-safe (e.g,
# read-only). Most functions are NOT thread safe!

func add_thread(thread: Thread) -> void: # DEPRECIATE
	# Add non-main threads here. We wait_to_finish() on active threads at
	# simulator stop (eg, before save/load, exit, etc.).
	_threads.append(thread)

func add_active_thread(thread: Thread) -> void:
	# add before thread.start()
	_active_threads.append(thread)

func remove_active_thread(thread: Thread) -> void:
	_active_threads.erase(thread)
	if !_active_threads:
		assert(DPRINT and prints("signal threads_finished") or true)
		emit_signal("threads_finished")

func test_active_threads() -> void:
	if !_active_threads:
		assert(DPRINT and prints("signal threads_finished") or true)
		emit_signal("threads_finished")

func require_stop(who: Object) -> void:
	# "Stopped" means the game is paused, the player is locked out from most
	# input, and non-main threads have finished. In most cases you should yield
	# to "threads_finished" after calling this function before proceeding.
	assert(DPRINT and prints("require_stop", who) or true)
	assert(DPRINT and prints("signal finish_threads_requested") or true)
	emit_signal("finish_threads_requested")
	if !_nodes_requiring_stop.has(who):
		_nodes_requiring_stop.append(who)
	if _state.is_running:
		_stop_simulator()
	call_deferred("test_active_threads")
	
func allow_run(who: Object) -> void:
	assert(DPRINT and prints("allow_run", who) or true)
	_nodes_requiring_stop.erase(who)
	if !_state.is_running and !_nodes_requiring_stop:
		_run_simulator()

func build_system_tree() -> void:
	_state.is_splash_screen = false
	_system_builder.build()
	yield(_system_builder, "finished")
	Global.emit_signal("system_tree_built_or_loaded", true)
	yield(_tree, "idle_frame")
	Global.emit_signal("system_tree_ready", true)
	yield(_tree, "idle_frame")
	Global.emit_signal("about_to_start_simulator", true)
	allow_run(self)
	yield(_tree, "idle_frame")
	Global.emit_signal("gui_refresh_requested")

func exit(exit_now: bool) -> void:
	if !exit_now:
		OneUseConfirm.new("LABEL_EXIT_WITHOUT_SAVING", self, "exit", [true])
		return
	require_stop(self)
	yield(self, "threads_finished")
	Global.emit_signal("about_to_free_procedural_nodes")
	yield(_tree, "idle_frame")
	_saver_loader.free_procedural_nodes(_tree.get_root())
	_tree.set_current_scene(_gui_top)
	_state.is_splash_screen = true
	Global.emit_signal("simulator_exited")

func quick_save() -> void:
	if _has_been_saved and _settings.save_base_name and _file_helper.is_valid_dir(_settings.save_dir):
		Global.emit_signal("close_main_menu_requested")
		var date_string: String = _timekeeper.get_current_date_string("-") if _settings.append_date_to_save else ""
		save_game(_file_helper.get_save_path(_settings.save_dir, _settings.save_base_name, date_string, true))
	else:
		Global.emit_signal("save_dialog_requested")

func save_game(path: String) -> void:
	if path == "":
		Global.emit_signal("save_dialog_requested")
		return
	print("Saving " + path)
	require_stop(self)
	yield(self, "threads_finished")
	assert(Debug.rprint("Node count before save: ", _tree.get_node_count()))
	assert(!print_stray_nodes())
	assert(_saver_loader.debug_log("This is before save!", _tree))
	var save_file := File.new()
	save_file.open(path, File.WRITE)
	_state.last_save_path = path
	_main_prog_bar.start(_saver_loader)
	Global.emit_signal("game_save_started")
	_saver_loader.save_game(save_file)
	yield(_saver_loader, "finished")
	Global.emit_signal("game_save_finished")
	_main_prog_bar.stop()
	_has_been_saved = true
	allow_run(self)

func quick_load() -> void:
	if _state.last_save_path:
		Global.emit_signal("close_main_menu_requested")
		load_game(_state.last_save_path)
	else:
		Global.emit_signal("load_dialog_requested")
	
func load_game(path: String) -> void:
	if path == "":
		Global.emit_signal("load_dialog_requested")
		return
	print("Loading " + path)
	var save_file := File.new()
	if !save_file.file_exists(path):
		print("ERROR: Could not find " + path)
		return
	_state.is_splash_screen = false
	require_stop(self)
	yield(self, "threads_finished")
	_state.is_loaded_game = true
	save_file.open(path, File.READ)
	_main_prog_bar.start(_saver_loader)
	Global.emit_signal("about_to_free_procedural_nodes")
	Global.emit_signal("game_load_started")
	_saver_loader.load_game(save_file)
	yield(_saver_loader, "finished")
	Global.emit_signal("game_load_finished")
	_main_prog_bar.stop()
	_was_paused = _settings.loaded_game_is_paused or _timekeeper.is_paused
	Global.emit_signal("system_tree_built_or_loaded", false)
	yield(_tree, "idle_frame")
	Global.emit_signal("system_tree_ready", false)
	yield(_tree, "idle_frame")
	assert(_saver_loader.debug_log("This is after load & system_tree_ready!", _tree))
	assert(Debug.rprint("Node count after load: ", _tree.get_node_count()))
	assert(!print_stray_nodes())
	Global.emit_signal("about_to_start_simulator", false)
	yield(_tree, "idle_frame")
	allow_run(self)
	Global.emit_signal("gui_refresh_requested")
	
func quit(quit_now: bool) -> void:
	if !quit_now and !_state.is_splash_screen:
		OneUseConfirm.new("LABEL_QUIT_WITHOUT_SAVING", self, "quit", [true])
		return
	require_stop(self)
	yield(self, "threads_finished")
	assert(!print_stray_nodes())
	print("Quitting...")
	
	# DEPRECIATE
	for thread in _threads:
		thread.wait_to_finish()
	
	
	_tree.quit()

func save_quit() -> void:
	Global.connect("game_save_finished", self, "quit", [true])
	quick_save()

# *********************** VIRTUAL & PRIVATE FUNCTIONS *************************

func _init() -> void:
	_on_init()

func _on_init() -> void:
	_state.is_inited = false
	_state.is_splash_screen = true
	_state.is_running = false
	_state.is_loaded_game = false
	_state.last_save_path = ""

func project_init() -> void:
	connect("ready", self, "_on_ready")
	Global.connect("project_builder_finished", self, "_import_table_data")
	Global.connect("table_data_imported", self, "_finish_init")
	Global.connect("require_stop_requested", self, "require_stop")
	Global.connect("allow_run_requested", self, "allow_run")
	_tree = Global.objects.tree
	_gui_top = Global.objects.GUITop
	_table_reader = Global.objects.TableReader
	_saver_loader = Global.objects.SaverLoader
	_main_prog_bar = Global.objects.MainProgBar
	_system_builder = Global.objects.SystemBuilder
	_timekeeper = Global.objects.Timekeeper
	_file_helper = Global.objects.FileHelper

func _on_ready() -> void:
	require_stop(self)
	prints("I, Voyager", ivoyager_version, project_version)

func _import_table_data() -> void:
	_table_reader.import_table_data()
	Global.emit_signal("table_data_imported")

func _finish_init() -> void:
	_state.is_inited = true
	Global.emit_signal("main_inited")
	if Global.skip_splash_screen:
		build_system_tree()

func _stop_simulator() -> void:
	# Project must ensure that state does not change during stop (in
	# particular, persist vars during save/load).
	print("stop simulator")
	_was_paused = _tree.paused
	_tree.paused = true
	_state.is_running = false
	Global.emit_signal("run_state_changed", false)
	
func _run_simulator() -> void:
	print("run simulator")
	_state.is_running = true
	Global.emit_signal("run_state_changed", true)
	if !_was_paused:
		_tree.paused = false
	_timekeeper.reset()
	assert(DPRINT and prints("signal active_threads_allowed") or true)
	emit_signal("active_threads_allowed")
