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
# Manages a separate thread for I/O operations including resource loading.
# As per Godot docs, loading a resource from multiple threads can crash. Thus,
# you should not mix use of IOManager with resource loading on the Main thread.
#
# The "io_method" supplied in callback() is handy for doing "I/O-adjacent" work
# such as processing resources or assembling parts of scene trees. However, all
# interaction with the current scene tree MUST happen on the Main thread. To do
# so, supply the "finish_method" callback.
#
# Work is processed in the order added on the I/O thread. Finish callbacks
# on the Main thread will occur in future frames, but are guarantied to be in
# the order added. TEST THIS!!!
#
# All methods will work on the Main thread if Global.use_threads == false.

class_name IOManager

signal finished() # emitted when all I/O jobs completed 

const DPRINT := false

var _use_threads: bool = Global.use_threads
var _state_manager: StateManager
var _thread: Thread
var _mutex: Mutex
var _semaphore: Semaphore
var _callback_queue := []
var _process_stack := []
var _is_work := false
var _stop_thread := false
var _job_count := 0

# *****************************************************************************
# Public. These are NOT thread-safe! Call on Main thread.

func callback(object: Object, io_method: String, finish_method := "", array := []) -> void:
	# Callback to io_method will happen on the I/O thread. Callback to optional
	# finish_method will happen subsequently on the main thread. The array arg
	# is optional here but is required in callback methods signatures.
	# IOManager will emit "finished" on a later frame after all current
	# callbacks have been processed. This is guaranteed to be delayed at least
	# one frame.
	_job_count += 1
	var args := [object, io_method, finish_method, array]
	if !_use_threads:
		_process_callback(args)
		return
	_mutex.lock()
	_callback_queue.append(args)
	_is_work = true
	_mutex.unlock()
	_semaphore.post()

func store_var_to_file(value, file_path: String, err_object: Object = null, err_method := "") -> void:
	# If err_object and err_method supplied, you WILL get a callback with
	# single err argument (most likely, err = OK). If not, we print a simple
	# "ERROR!..." message if there is a problem.
	var array := [value, file_path]
	var finish_method := ""
	if err_object and err_method:
		array.append(err_object)
		array.append(err_method)
		finish_method = "_store_var_to_file_finish"
	callback(self, "_store_var_to_file", finish_method, array)

func get_var_from_file(file_path: String, callback_object: Object, callback_method: String) -> void:
	# Gets var from file on O/I thread; sends to callback_method on Main thread.
	# Callback will receive 2 args: value, err. If err != OK, value = null.
	var array := [file_path, callback_object, callback_method]
	callback(self, "_get_var_from_file", "_get_var_from_file_finish", array)

# *****************************************************************************
# specific function callbacks

func _store_var_to_file(array: Array) -> void:
	var value = array[0]
	var file_path: String = array[1]
	var user_callback := array.size() > 2
	var file := File.new()
	var err := file.open(file_path, File.WRITE)
	if user_callback:
		array.append(err)
	if err == OK:
		file.store_var(value)
		file.close() # file ready for another call before I/O thread proceeds
		return
	if !user_callback: # no err callback; just do simple error print
		prints("ERROR! Could not open for write:", file_path)

func _store_var_to_file_finish(array: Array) -> void:
	# only here if user wanted err callback
	var err_object: Object = array[2]
	var err_method: String = array[3]
	var err: int = array[4]
	if is_instance_valid(err_object):
		err_object.call(err_method, err)

func _get_var_from_file(array: Array) -> void:
	var file_path: String = array[0]
	var file := File.new()
	var err := file.open(file_path, File.READ)
	array.append(err)
	if err == OK:
		array.append(file.get_var())
		file.close()

func _get_var_from_file_finish(array: Array) -> void:
	var callback_object: Object = array[1]
	var callback_method: String = array[2]
	var err: int = array[3]
	var value
	if err == OK:
		value = array[4]
	if is_instance_valid(callback_object):
		callback_object.call(callback_method, value, err)

# *****************************************************************************
# Init & private

func _project_init() -> void:
	_state_manager = Global.program.StateManager
	if !_use_threads:
		return
	Global.connect("about_to_stop_before_quit", self, "_block_quit_until_finished")
	_thread = Thread.new()
	_mutex = Mutex.new()
	_semaphore = Semaphore.new()
	_thread.start(self, "_run_thread", 0)

func _block_quit_until_finished() -> void:
	# Block the quit until we finish the thread; otherwise, we'll have leaks.
	_stop_thread = true
	if _thread.is_active():
		_state_manager.add_blocking_thread(_thread) # block quit
		_semaphore.post()
		_thread.wait_to_finish()
		_state_manager.call_deferred("remove_blocking_thread", _thread)

# I/O processing

func _run_thread(_dummy: int) -> void: # I/O thread
	print("Run I/O thread!")
	while !_stop_thread:
		if _is_work:
			_mutex.lock()
			while _callback_queue:
				_process_stack.append(_callback_queue.pop_back())
			_is_work = false
			_mutex.unlock()
			assert(DPRINT and (_process_stack and print("I/O batch: ", _process_stack.size())) or true)
			while _process_stack:
				var args: Array = _process_stack.pop_back()
				_process_callback(args)
		_semaphore.wait()
	print("Stop I/O thread!")

func _process_callback(args: Array) -> void: # I/O thread, or Main if !_use_threads
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
	_job_count -= 1
	if _job_count == 0:
		assert(DPRINT and print("I/O finished!") or true)
		emit_signal("finished")
