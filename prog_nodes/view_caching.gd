# view_caching.gd
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
# [Not added in core ivoyager!] Add to ProjectBuilder.program_nodes in your
# extension file if you want camera view to be cached and restored on start.
# Used by Planetarium.
#
# You only need to set cache_interval if Global.disable_quit = true. Otherwise,
# cache happens on quit and we don't use the Timer function.

extends Timer
class_name ViewCaching

var cache_interval := 0.0 # s; enable (set >0.0) if Global.disable_quit
var cache_file_name := "view.vbinary"

var _cache_dir: String = Global.cache_dir
var _camera: VygrCamera

func _project_init() -> void:
	var dir = Directory.new()
	if dir.open(_cache_dir) != OK:
		dir.make_dir(_cache_dir)
	if cache_interval > 0.0:
		wait_time = cache_interval
	else:
		paused = true # start() order won't do anything

func _ready():
	Global.connect("about_to_free_procedural_nodes", self, "_clear")
	Global.connect("camera_ready", self, "_set_camera")
	Global.connect("system_tree_ready", self, "_on_system_tree_ready")
	Global.connect("simulator_started", self, "start")
	Global.connect("about_to_quit", self, "_cache_now")
	connect("timeout", self, "_cache_now")

func _clear() -> void:
	_camera = null
	stop()

func _set_camera(camera: VygrCamera) -> void:
	_camera = camera

func _on_system_tree_ready(_is_new_game: bool) -> void:
	var file := _get_file(File.READ)
	if !file:
		return
	var view_dict: Dictionary = file.get_var()
	var view: View = dict2inst(view_dict)
	_camera.set_start_view(view)

func _cache_now() -> void:
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
