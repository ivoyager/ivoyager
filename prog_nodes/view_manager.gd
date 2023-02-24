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

# Manages IVView instances that can be persisted via gamesave or cache.

enum {
	CAMERA_STATE = 1,
	HUDS_STATE = 1 << 1,
	TIME_STATE = 1 << 2,
	# below used in set_view()
	CAMERA_STATE_IF_SAVED = 1 << 3,
	HUDS_STATE_IF_SAVED = 1 << 4,
	TIME_STATE_IF_SAVED = 1 << 5,
	INSTANT_CAMERA_MOVE = 1 << 6,
}


const DPRINT := true

const files := preload("res://ivoyager/static/files.gd")
const FILE_EXTENSION := "ivbinary"

const PERSIST_MODE := IVEnums.PERSIST_PROPERTIES_ONLY
const PERSIST_PROPERTIES := [
	"_gamesave_views",
]

var _gamesave_views := {}
var _cached_views := {}

var _View_: Script
var _cache_dir: String = IVGlobal.cache_dir + "/views"



func _project_init() -> void:
	_View_ = IVGlobal.script_classes._View_
	files.make_dir_if_doesnt_exist(_cache_dir)
	_read_cache()


# public

func save_view(view_name: String, set_name: String, is_cached: bool, flags: int) -> void:
	
	var key := view_name + "." + set_name
	var view := get_view_object(view_name, set_name, is_cached)
	if view:
		view.reset()
	else:
		view = _View_.new()
	if flags & CAMERA_STATE:
		view.save_camera_state()
	if flags & HUDS_STATE:
		view.save_huds_state()
	if flags & TIME_STATE:
		view.save_time_state()
	if is_cached:
		_cached_views[key] = view
		_write_cache(key, view)
	else:
		_gamesave_views[key] = view


func set_view(view_name: String, set_name: String, is_cached: bool, flags: int) -> void:
	var key := view_name + "." + set_name
	var view: IVView
	if is_cached:
		view = _cached_views.get(key)
	else:
		view = _gamesave_views.get(key)
	if !view:
		return
	if flags & CAMERA_STATE or flags & CAMERA_STATE_IF_SAVED:
		view.set_camera_state(bool(flags & INSTANT_CAMERA_MOVE))
	if flags & HUDS_STATE or flags & HUDS_STATE_IF_SAVED:
		view.set_huds_state()
	if flags & TIME_STATE or flags & TIME_STATE_IF_SAVED:
		view.set_time_state()


func save_view_object(view: IVView, view_name: String, set_name: String, is_cached: bool) -> void:
	var key := view_name + "." + set_name
	if is_cached:
		_cached_views[key] = view
		_write_cache(key, view)
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


func get_view_names_in_set(set_name: String, is_cached: bool) -> Array:
	var set := []
	var suffix := "." + set_name
	var dict := _cached_views if is_cached else _gamesave_views
	for key in dict:
		if key.ends_with(suffix):
			set.append(key.trim_suffix(suffix))
	return set


# private

func _write_cache(key: String, view: IVView) -> void:
	var file := _get_file(key + "." + FILE_EXTENSION, File.WRITE)
	if !file:
		return
	var data := view.get_cache_data()
	file.store_var(data)


func _read_cache() -> void:
	# Populates _cached_views; only once at project init!
	var file_names := files.get_dir_files(_cache_dir, FILE_EXTENSION)
	for file_name in file_names:
		var file := _get_file(file_name, File.READ)
		if !file:
			continue
		var data = file.get_var() # View will test type, version & integrity
		var view: IVView = _View_.new()
		if !view.set_cache_data(data):
			continue
		var key: String = file_name.get_basename()
		_cached_views[key] = view


func _get_file(file_name: String, flags: int) -> File:
	var file_path := _cache_dir.plus_file(file_name)
	var file := File.new()
	if file.open(file_path, flags) != OK:
		if flags == File.WRITE:
			print("ERROR! Could not open ", file_path, " for write!")
		else:
			print("Could not open ", file_path, " for read (expected if no changes)")
		return null
	return file


