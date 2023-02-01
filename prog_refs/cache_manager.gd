# cache_manager.gd
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
class_name IVCacheManager

# Abstract base class for managing user cached items. Subclasses include
# IVSettingsManager & IVInputMapManager.

# project vars - set in subclass _init(); project can modify at init
var cache_file_name := "generic_item.vbinary" # change in subclass
var defaults: Dictionary # subclass defines in _init()
var current: Dictionary # subclass makes or references an existing dict

# subclass setting
var _is_references := false # set if cache items are arrays or dicts

# private
var _io_manager: IVIOManager
var _file_path: String
var _cached := {} # exact replica of disk cache notwithstanding I/O delay


# *****************************************************************************

func _init() -> void:
	_on_init()


func _on_init() -> void: # subclass can override
	pass


func _project_init() -> void:
	_io_manager = IVGlobal.program.IOManager
	var cache_dir: String = IVGlobal.cache_dir
	_file_path = cache_dir.plus_file(cache_file_name)
	var dir = Directory.new()
	if dir.open(cache_dir) != OK:
		dir.make_dir(cache_dir)
	for item_name in defaults:
		var default = defaults[item_name] # unknown type
		current[item_name] = default.duplicate(true) if _is_references else default
	_read_cache()


# *****************************************************************************

func change_current(item_name: String, value, suppress_caching := false) -> void:
	# If suppress_caching = true, then be sure to call cache_now() later.
	_about_to_change_current(item_name)
	current[item_name] = value.duplicate(true) if _is_references else value
	_on_change_current(item_name)
	if !suppress_caching:
		cache_now()


func cache_now() -> void:
	_write_cache()


func is_default(item_name: String) -> bool:
	return _is_equal(current[item_name], defaults[item_name])


func is_all_defaults() -> bool:
	for item_name in defaults:
		if !_is_equal(current[item_name], defaults[item_name]):
			return false
	return true


func get_cached_value(item_name: String, cached_values: Dictionary): # unknown type
	# If cache doesn't have it, we treat default as cached
	if cached_values.has(item_name):
		return cached_values[item_name]
	return defaults[item_name]


func is_cached(item_name: String, cached_values: Dictionary) -> bool:
	if cached_values.has(item_name):
		return _is_equal(current[item_name], cached_values[item_name])
	return _is_equal(current[item_name], defaults[item_name])


func get_cached_values() -> Dictionary:
	return _cached


func restore_default(item_name: String, suppress_caching := false) -> void:
	if !is_default(item_name):
		change_current(item_name, defaults[item_name], suppress_caching)


func restore_all_defaults(suppress_caching := false) -> void:
	for item_name in defaults:
		change_current(item_name, defaults[item_name], true)
	if !suppress_caching:
		cache_now()


func is_cache_current() -> bool:
	var cached_values := get_cached_values()
	for item_name in defaults:
		if !is_cached(item_name, cached_values):
			return false
	return true


func restore_from_cache() -> void:
	var cached_values := get_cached_values()
	for item_name in defaults:
		if !is_cached(item_name, cached_values):
			var cached_value = get_cached_value(item_name, cached_values)
			change_current(item_name, cached_value, true)


# *****************************************************************************

func _about_to_change_current(_item_name: String) -> void:
	# subclass logic
	pass


func _on_change_current(_item_name: String) -> void:
	# subclass logic
	pass


func _is_equal(value1, value2) -> bool:
	return value1 == value2 # or supply subclass logic


func _write_cache() -> void:
	_cached.clear()
	for item_name in defaults:
		if !_is_equal(current[item_name], defaults[item_name]): # cache non-default values
			_cached[item_name] = current[item_name] # reference ok
	_io_manager.store_var_to_file(_cached.duplicate(true), _file_path)


func _read_cache() -> void:
	# This happens on _project_init() only. We want this on Main thread so that
	# it does block until completed.
	var file := File.new()
	if file.open(_file_path, File.READ) != OK:
		prints("Did not find cache file:", _file_path)
		return
	_cached = file.get_var()
	for item_name in _cached:
		if current.has(item_name): # possibly old verson obsoleted item_name
			current[item_name] = _cached[item_name] # reference ok
