# io_manager.gd
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
# Manages a separate I/O thread for disk operations including resource loading.
# As per Godot docs, loading a resource from multiple threads can crash. Thus,
# you should not mix use of IOManager with resource loading on the Main thread.
# Also, all interaction with the scene tree MUST happen on the Main thread; use
# callback() and supply "finish_method" to do this. 

class_name IOManager

signal finished()

const DPRINT := true

var _use_threads: bool = Global.use_threads
var _state_manager: StateManager
var _thread: Thread
var _mutex: Mutex
var _semaphore: Semaphore
var _callback_queue := []
var _process_stack := []
var _is_work := false
var _stop_thread := false
var _callback_count := 0

# *****************************************************************************
# Thread-safe public

func callback(object: Object, io_method: String, finish_method := "", array := []) -> void:
	# Callback to io_method will happen on the I/O thread. Callback to optional
	# finish_method will subsequently happen on main thread. The array arg is
	# optional here but is required in callback methods signatures.
	# Will emit "finished" on a later frame (main thread) after all current
	# callbacks have been fully processed.
	_callback_count += 1
	var args := [object, io_method, finish_method, array]
	if !_use_threads:
		_process_callback(args)
		return
	_mutex.lock()
	_callback_queue.append(args)
	_is_work = true
	_mutex.unlock()
	_semaphore.post()

# TODO: Add specific I/O functions here, using callbacks to self.

# *****************************************************************************
# Init & private

func project_init() -> void:
	_state_manager = Global.program.StateManager
	if !_use_threads:
		return
	Global.connect("about_to_free_procedural_nodes", self, "_on_about_to_free_procedural_nodes")
	Global.connect("about_to_quit", self, "_on_about_to_quit")
	_state_manager.connect("active_threads_allowed", self, "_on_active_threads_allowed")
	_state_manager.connect("finish_threads_required", self, "_on_finish_threads_required")
	_thread = Thread.new()
	_mutex = Mutex.new()
	_semaphore = Semaphore.new()
	_thread.start(self, "_run_thread", 0)

# Before sim starts, and on exit or load, we want thread to run while sim is
# stopped. However, during runtime (after "active_threads_allowed") we want
# thread to start/stop with the simulator. We also want to block quit until
# thread finishes to avoid "leaked" warnings.

func _on_about_to_free_procedural_nodes() -> void:
	_stop_thread = false
	_state_manager.remove_active_thread(_thread) # don't block
	if !_thread.is_active():
		_thread.start(self, "_run_thread", 0)

func _on_about_to_quit() -> void:
	_stop_thread = true
	if _thread.is_active():
		_state_manager.add_active_thread(_thread) # block quit
		_semaphore.post()
		_thread.wait_to_finish()
		_state_manager.call_deferred("remove_active_thread", _thread)

func _on_active_threads_allowed() -> void:
	_stop_thread = false
	_state_manager.add_active_thread(_thread)
	if !_thread.is_active():
		_thread.start(self, "_run_thread", 0)

func _on_finish_threads_required() -> void:
	_stop_thread = true
	if _thread.is_active():
		_semaphore.post()
		_thread.wait_to_finish()
		_state_manager.call_deferred("remove_active_thread", _thread)

# I/O processing

func _run_thread(_dummy: int) -> void: # I/O thread
	assert(DPRINT and print("Run I/O thread!") or true)
	while !_stop_thread:
		if _is_work:
			_mutex.lock()
			while _callback_queue:
				_process_stack.append(_callback_queue.pop_back())
			_is_work = false
			_mutex.unlock()
#		assert(DPRINT and print("I/O items to process: ", _process_stack.size()) or true)
		while _process_stack:
			var args: Array = _process_stack.pop_back()
			_process_callback(args)
		_semaphore.wait()
	assert(DPRINT and print("Stop I/O thread!") or true)

func _process_callback(args: Array) -> void: # I/O thread (or Main if !_use_threads)
	var object: Object = args[0]
	var io_method: String = args[1]
	var array: Array = args[3]
	if is_instance_valid(object):
		object.call(io_method, array)
	call_deferred("_finish", args)

func _finish(args: Array) -> void: # Main thread
	var finish_method: String = args[2]
	if finish_method:
		var object: Object = args[0]
		var array: Array = args[3]
		if is_instance_valid(object):
			object.call(finish_method, array)
	_callback_count -= 1
	if _callback_count == 0:
		assert(DPRINT and print("I/O finished!") or true)
		emit_signal("finished")
