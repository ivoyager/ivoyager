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
	"_gamesave_views",
]

var file_path := IVGlobal.cache_dir.plus_file("views.ivbinary")

var _gamesave_views := {}
var _cached_views := {}

var _View_: Script
var _io_manager: IVIOManager


func _project_init() -> void:
	_View_ = IVGlobal.script_classes._View_
	_io_manager = IVGlobal.program.IOManager
	files.make_dir_if_doesnt_exist(IVGlobal.cache_dir)
	_read_cache()


# public

func save_view(view_name: String, set_name: String, is_cached: bool, flags: int) -> void:
	var key := view_name + "." + set_name
	var view := get_view_object(view_name, set_name, is_cached)
	if view:
		view.reset()
	else:
		view = _View_.new()
	view.save_state(flags)
	if is_cached:
		_cached_views[key] = view
		_write_cache()
	else:
		_gamesave_views[key] = view


func set_view(view_name: String, set_name: String, is_cached: bool,
		is_camera_instant_move := false) -> void:
	var key := view_name + "." + set_name
	var view: IVView
	if is_cached:
		view = _cached_views.get(key)
	else:
		view = _gamesave_views.get(key)
	if !view:
		return
	view.set_state(is_camera_instant_move)


func save_view_object(view: IVView, view_name: String, set_name: String, is_cached: bool) -> void:
	var key := view_name + "." + set_name
	if is_cached:
		_cached_views[key] = view
		_write_cache()
	else:
		_gamesave_views[key] = view


func get_view_object(view_name: String, set_name: String, is_cached: bool) -> IVView:
	var key := view_name + "." + set_name
	if is_cached:
		return _cached_views.get(key)
	return _gamesave_views.get(key)


func has_view(view_name: String, set_name: String, is_cached: bool) -> bool:
	var key := view_name + "." + set_name
	if is_cached:
		return _cached_views.has(key)
	return _gamesave_views.has(key)


func remove_view(view_name: String, set_name: String, is_cached: bool) -> void:
	var key := view_name + "." + set_name
	if is_cached:
		_cached_views.erase(key)
		_write_cache()
	else:
		_gamesave_views.erase(key)
	

func get_view_names_in_set(set_name: String, is_cached: bool) -> Array:
	var set := []
	var suffix := "." + set_name
	var dict := _cached_views if is_cached else _gamesave_views
	for key in dict:
		if key.ends_with(suffix):
			set.append(key.trim_suffix(suffix))
	return set


# private

func _read_cache() -> void:
	# Populate _cached_views once at project init (on main thread).
	var file := File.new()
	if file.open(file_path, File.READ) != OK:
		print("Did not find cache file ", file_path, " (expected if no changes)")
		return
	var dict: Dictionary = file.get_var()
	file.close()
	var bad_cache_data := false
	for key in dict:
		var data: Array = dict[key]
		var view: IVView = _View_.new()
		if !view.set_data_from_cache(data): # may be prior version
			bad_cache_data = true
			continue
		_cached_views[key] = view
	if bad_cache_data:
		_write_cache() # removes all prior-version views


func _write_cache() -> void:
	var dict := {}
	for key in _cached_views:
		var view: IVView = _cached_views[key]
		var data := view.get_data_for_cache()
		dict[key] = data
	_io_manager.callback(self, "_write_cache_on_io_thread", "", [dict])
	

func _write_cache_on_io_thread(thread_data: Array) -> void:
	# No one is waiting for this, so do the file write on i/o thread.
	var dict: Dictionary = thread_data[0]
	var file := File.new()
	if file.open(file_path, File.WRITE) != OK:
		print("ERROR! Could not open ", file_path, " for write!")
		return
	file.store_var(dict)
	file.close()

