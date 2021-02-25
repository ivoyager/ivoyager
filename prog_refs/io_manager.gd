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
# All public functions work if Global.use_threads = false, but without the
# thread.

class_name IOManager

var _use_threads: bool = Global.use_threads
var _state_manager: StateManager
var _thread: Thread
var _mutex: Mutex
var _semaphore: Semaphore
var _call_queue := []
var _io_queue := []
var _is_work := false
var _stop_thread := true

# *****************************************************************************
# Thread-safe public

func load_and_attach(file_path: String, instantiate: bool, is_scene: bool,
		target_object: Object, property := "", as_child := false) -> void:
	assert(property or as_child)
	var args := [file_path, instantiate, is_scene, target_object, property, as_child]
	if !_use_threads:
		_process_call(args)
		return
	_mutex.lock()
	_call_queue.append(args)
	_is_work = true
	_mutex.unlock()
	_semaphore.post()

func set_state_manager_lock(lock: bool) -> void:
	# 
	pass

# *****************************************************************************
# Init & private

func project_init() -> void:
	_state_manager = Global.program.StateManager
	if !_use_threads:
		return
	_state_manager.connect("active_threads_allowed", self, "_on_active_threads_allowed")
	_state_manager.connect("finish_threads_required", self, "_on_finish_threads_required")
	_thread = Thread.new()
	_mutex = Mutex.new()
	_semaphore = Semaphore.new()

func _on_active_threads_allowed() -> void:
	
	# FIXME: How can this work when the sim is stopped ???
	
	_stop_thread = false
	_state_manager.add_active_thread(_thread)
	_thread.start(self, "_run_thread", 0)

func _on_finish_threads_required() -> void:
	_stop_thread = true
	_semaphore.post()
	_thread.wait_to_finish()
	_state_manager.call_deferred("remove_active_thread", _thread)

func _attach(object: Object, args: Array) -> void:
	var target_object: Object = args[3]
	if !is_instance_valid(target_object):
		return
	var property: String = args[4]
	var as_child: bool = args[5]
	if property:
		target_object.set(property, object)
	if !as_child:
		return
	var target_node := target_object as Node
	var node := object as Node
	if node and target_node:
		target_node.add_child(node)


# *****************************************************************************
# I/O thread (if Global.use_threads)

func _run_thread(_dummy: int) -> void:
	while !_stop_thread:
		if _is_work:
			_mutex.lock()
			while _call_queue:
				_io_queue.append(_call_queue.pop_back())
			_is_work = false
			_mutex.unlock()
		while _io_queue:
			var args: Array = _io_queue.pop_back()
			_process_call(args)
		_semaphore.wait()

func _process_call(args: Array) -> void:
	# file_path: String, target_object: Object, property := "", as_child := false
	var file_path: String = args[0]
	var instantiate: bool = args[1]
	var is_scene: bool = args[2]
	var resource: Resource = load(file_path)
	var object: Object
	if instantiate:
		var script := resource as Script
		assert(script)
		if is_scene:
			object = FileUtils.make_object_or_scene(script)
		else:
			object = script.new()
	else:
		object = resource
	call_deferred("_attach", object, args) # on main thread

