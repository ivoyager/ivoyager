# view_manager.gd
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
class_name IVViewManager
extends Node

# Manages IVView instances that are persisted via gamesave or cache.

const files := preload("res://ivoyager/static/files.gd")

const PERSIST_MODE := IVEnums.PERSIST_PROPERTIES_ONLY
const PERSIST_PROPERTIES := [
	&"_gamesave_views",
]

var file_path := IVGlobal.cache_dir.path_join("views.ivbinary")

var _gamesave_views := {}
var _cached_views := {}
var _View_: Script
var _io_manager: IVIOManager
var _missing_or_bad_cache_file := true


func _project_init() -> void:
	_View_ = IVGlobal.script_classes._View_
	_io_manager = IVGlobal.program.IOManager
	files.make_dir_if_doesnt_exist(IVGlobal.cache_dir)
	_read_cache()
	if _missing_or_bad_cache_file:
		_write_cache()


# public

func save_view(view_name: String, group_name: String, is_cached: bool, flags: int,
		allow_threaded_cache_write := true) -> void:
	var key := view_name + "." + group_name
	var view := get_view_object(view_name, group_name, is_cached)
	if view:
		view.reset()
	else:
		@warning_ignore("unsafe_method_access") # possible replacement class
		view = _View_.new()
	view.save_state(flags)
	if is_cached:
		_cached_views[key] = view
		_write_cache(allow_threaded_cache_write)
	else:
		_gamesave_views[key] = view


func set_view(view_name: String, group_name: String, is_cached: bool,
		is_camera_instant_move := false) -> void:
	var key := view_name + "." + group_name
	var view: IVView
	if is_cached:
		view = _cached_views.get(key)
	else:
		view = _gamesave_views.get(key)
	if !view:
		return
	view.set_state(is_camera_instant_move)


func save_view_object(view: IVView, view_name: String, group_name: String, is_cached: bool,
		allow_threaded_cache_write := true) -> void:
	var key := view_name + "." + group_name
	if is_cached:
		_cached_views[key] = view
		_write_cache(allow_threaded_cache_write)
	else:
		_gamesave_views[key] = view


func get_view_object(view_name: String, group_name: String, is_cached: bool) -> IVView:
	var key := view_name + "." + group_name
	if is_cached:
		return _cached_views.get(key)
	return _gamesave_views.get(key)


func has_view(view_name: String, group_name: String, is_cached: bool) -> bool:
	var key := view_name + "." + group_name
	if is_cached:
		return _cached_views.has(key)
	return _gamesave_views.has(key)


func remove_view(view_name: String, group_name: String, is_cached: bool) -> void:
	var key := view_name + "." + group_name
	if is_cached:
		_cached_views.erase(key)
		_write_cache()
	else:
		_gamesave_views.erase(key)
	

func get_view_names_in_group(group_name: String, is_cached: bool) -> Array[String]:
	var group: Array[String] = []
	var suffix := "." + group_name
	var dict := _cached_views if is_cached else _gamesave_views
	for key in dict:
		@warning_ignore("unsafe_cast")
		var key_str := key as String
		if key_str.ends_with(suffix):
			group.append(key_str.trim_suffix(suffix))
	return group


# private

func _read_cache() -> void:
	# Populate _cached_views once at project init on main thread.
	var file := FileAccess.open(file_path, FileAccess.READ)
	if !file:
		prints("Creating new cache file", file_path)
		return
	var file_var = file.get_var() # untyped for safety
	file.close()
	if typeof(file_var) != TYPE_DICTIONARY:
		prints("Overwriting obsolete cache file", file_path)
		return
	@warning_ignore("unsafe_cast")
	var dict := file_var as Dictionary
	var bad_cache_data := false
	for key in dict:
		var data: Array = dict[key]
		@warning_ignore("unsafe_method_access") # possible replacement class
		var view: IVView = _View_.new()
		if !view.set_data_from_cache(data): # may be prior version
			bad_cache_data = true
			continue
		_cached_views[key] = view
	if !bad_cache_data:
		_missing_or_bad_cache_file = false


func _write_cache(allow_threaded_cache_write := true) -> void:
	# Unless this is app exit, no one is waiting for this and we can do the
	# file write on i/o thread.
	var dict := {}
	for key in _cached_views:
		var view: IVView = _cached_views[key]
		var data := view.get_data_for_cache()
		dict[key] = data
	if allow_threaded_cache_write:
		_io_manager.callback(self, "_write_cache_maybe_on_io_thread", "", [dict])
	else:
		_write_cache_maybe_on_io_thread([dict])
	

func _write_cache_maybe_on_io_thread(data: Array) -> void:
	var dict: Dictionary = data[0]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if !file:
		print("ERROR! Could not open ", file_path, " for write!")
		return
	file.store_var(dict)
	file.close()

