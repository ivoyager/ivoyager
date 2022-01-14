# view_cacher.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2022 Charlie Whitfield
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
class_name IVViewCacher
extends Timer

# Not added in core ivoyager! Add to IVProjectBuilder.prog_nodes in your
# extension file if you want camera view to be cached and restored on start.
# Used by Planetarium.
#
# You only need to set cache_interval for HTML5 export. Otherwise, _cache_view()
# will be called on quit.


var cache_interval := 0.0 # s; set >0.0 to enable Timer
var cache_file_name := "view.vbinary"

var _cache_dir: String = IVGlobal.cache_dir
var _camera: IVCamera


func _project_init() -> void:
	var dir = Directory.new()
	if dir.open(_cache_dir) != OK:
		dir.make_dir(_cache_dir)
	if cache_interval > 0.0:
		wait_time = cache_interval
	else:
		paused = true # start() order won't do anything


func _ready() -> void:
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_clear")
	IVGlobal.connect("camera_ready", self, "_set_camera")
	IVGlobal.connect("system_tree_ready", self, "_set_view")
	IVGlobal.connect("simulator_started", self, "start") # start if not paused
	IVGlobal.connect("about_to_quit", self, "_cache_view") # app quit button
	connect("timeout", self, "_cache_view")


func _notification(what: int) -> void:
	# This should work for all desktop exports; does NOT work for HTML5 export.
	if what == NOTIFICATION_WM_QUIT_REQUEST:
		_cache_view()


func _clear() -> void:
	_camera = null
	stop()


func _set_camera(camera: IVCamera) -> void:
	_camera = camera


func _set_view(_is_new_game: bool) -> void:
	if !_camera:
		return
	var file := _get_file(File.READ)
	if !file:
		return
	var view_dict: Dictionary = file.get_var()
	var view: IVView = dict2inst(view_dict)
	_camera.set_start_view(view)


func _cache_view() -> void:
	if !_camera:
		return
	var file := _get_file(File.WRITE)
	if !file:
		return
	var view := _camera.create_view()
	var view_dict := inst2dict(view)
	file.store_var(view_dict)


func _get_file(flags: int) -> File:
	var file_path := _cache_dir.plus_file(cache_file_name)
	var file := File.new()
	if file.open(file_path, flags) != OK:
		if flags == File.WRITE:
			print("ERROR! Could not open ", file_path, " for write!")
		else:
			print("Could not open ", file_path, " for read (expected if no changes)")
		return null
	return file
