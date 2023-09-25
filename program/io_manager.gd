# io_manager.gd
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
class_name IVIOManager
extends RefCounted

# Manages a separate thread for I/O operations including resource loading.
# Per Godot docs (3.x), loading a resource from multiple threads can crash.
# Thus, you should not mix use of IVIOManager with resource loading on the main
# thread*.
#
# The 'io_method' supplied in callback() is handy for doing I/O-adjacent work
# such as processing resources or assembling parts of scene trees. However, all
# interaction with the current scene tree MUST happen on the main thread*. To
# do so, use call_deferred() at the end of your io_method.
#
# [* Godot 4.x edit: above statements may or may not be true anymore. Our code
# still does all scene tree changes on the main thread.] 
#
# All work is processed in the order added using the callback() method.
#
# If IVGlobal.use_threads == false, callback() will still work but the
# callback will happen immediately on the main thread w/out queuing.

signal finished() # emitted when all I/O jobs completed

const DPRINT := false

var _use_threads: bool = IVGlobal.use_threads
var _state_manager: IVStateManager
var _thread: Thread
var _mutex: Mutex
var _semaphore: Semaphore
var _callback_queue: Array[Callable] = []
var _process_stack: Array[Callable] = []
var _is_work := false
var _stop_thread := false
var _job_count := 0
var _null_lambda := func(): return


# *****************************************************************************
# Init & app exit

func _project_init() -> void:
	_state_manager = IVGlobal.program[&"StateManager"]
	if !_use_threads:
		return
	IVGlobal.about_to_stop_before_quit.connect(_block_quit_until_finished)
	_thread = Thread.new()
	_mutex = Mutex.new()
	_semaphore = Semaphore.new()
	_thread.start(_run_thread)


func _block_quit_until_finished() -> void:
	# Block the quit until we finish the thread; otherwise, we'll have leaks.
	_stop_thread = true
	if _thread.is_alive():
		_state_manager.add_blocking_thread(_thread) # block quit
		_semaphore.post()
		_thread.wait_to_finish()
		_state_manager.remove_blocking_thread.call_deferred(_thread)


# *****************************************************************************
# Public. These are NOT thread-safe! Call on Main thread.


func callback(io_method: Callable) -> void:
	# 'io_method' will be called on I/O thread if IVGlobal.use_threads == true.
	# IVIOManager will emit 'finished' signal on main thread after all current
	# callbacks have been processed.
	_job_count += 1
	if !_use_threads:
		_process_callback(io_method)
		return
	_mutex.lock()
	_callback_queue.append(io_method)
	_is_work = true
	_mutex.unlock()
	_semaphore.post()


func store_var_to_file(value: Variant, file_path: String, err_callback := _null_lambda) -> void:
	# If err_callback supplied, you will get a callback with err argument. 
	# Otherwise, we print a simple "ERROR!..." message if there is a problem.
	callback(_store_var_to_file.bind(value, file_path, err_callback))


func get_var_from_file(file_path: String, result_callback: Callable) -> void:
	# Gets var from file on O/I thread; sends to 'result_callback' on main
	# thread. 'result_callback' will receive 2 args: 'value' and 'err'.
	# (If err != OK, then value is null.)
	callback(_get_var_from_file.bind(file_path, result_callback))


# *****************************************************************************
# specific function callbacks

func _store_var_to_file(value: Variant, file_path: String, err_callback: Callable) -> void:
	var is_err_callback: bool = err_callback != _null_lambda
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	var err := FileAccess.get_open_error()
	if err == OK:
		file.store_var(value)
		file.close() # file ready for another call before I/O thread proceeds
	elif !is_err_callback: # no err callback; just do simple error print
		prints("ERROR! Could not open for write:", file_path)
	if is_err_callback and err_callback.is_valid():
		err_callback.call_deferred(err)


func _get_var_from_file(file_path: String, result_callback: Callable) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	var err := FileAccess.get_open_error()
	var value: Variant
	if err == OK:
		value = file.get_var()
		file.close()
	if result_callback.is_valid():
		result_callback.call_deferred(value, err)


# *****************************************************************************
# I/O processing

func _run_thread() -> void: # I/O thread
	print("Run I/O thread")
	while !_stop_thread:
		if _is_work:
			# We only lock while moving work items from _callback_queue to
			# _process_stack!
			_mutex.lock()
			while _callback_queue:
				_process_stack.append(_callback_queue.pop_back())
			_is_work = false
			_mutex.unlock()
			# debug print only if something in _process_stack
			assert(!DPRINT or (_process_stack and IVDebug.dprint("I/O batch: ", _process_stack.size()) or true))
			while _process_stack:
				var io_method: Callable = _process_stack.pop_back()
				_process_callback(io_method)
		_semaphore.wait()
	print("Stop I/O thread")


func _process_callback(io_method: Callable) -> void: # I/O thread, or Main if !_use_threads
	if io_method.is_valid():
		io_method.call()
	_finish.call_deferred()


func _finish() -> void: # Main thread
	_job_count -= 1
	if _job_count == 0:
		assert(!DPRINT or IVDebug.dprint("I/O finished!"))
		finished.emit()

