# system_builder.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# "I, Voyager" is a registered trademark of Charlie Whitfield
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
# Builds the star system(s) from data tables & binaries.

extends Reference
class_name SystemBuilder

signal finished()

# project vars
var add_camera := true
var progress_bodies_denominator := 267 # set to something greater than expected

var progress := 0 # for MainProgBar
var _use_thread: bool = Global.use_threads
var _tree: SceneTree = Global.get_tree()
var _root: Viewport = _tree.get_root()
var _universe: Spatial
var _main_prog_bar: MainProgBar
var _body_builder: BodyBuilder
var _minor_bodies_builder: MinorBodiesBuilder
var _body_registry: BodyRegistry
var _table_reader: TableReader
var _Camera_: Script
var _progress_bodies := 0
var _thread: Thread
var _camera: Camera


func project_init():
	_universe = Global.program.universe
	_main_prog_bar = Global.program.get("MainProgBar") # safe if doesn't exist
	_body_builder = Global.program.BodyBuilder
	_minor_bodies_builder = Global.program.MinorBodiesBuilder
	_body_registry = Global.program.BodyRegistry
	_table_reader = Global.program.TableReader
	if add_camera:
		_Camera_ = Global.script_classes._Camera_

func build() -> void:
	print("Building solar system...")
	if _main_prog_bar:
		_main_prog_bar.start(self)
	if _use_thread:
		_thread = Thread.new()
		_thread.start(self, "_build_on_thread", 0)
	else:
		_build_on_thread(0)

func _build_on_thread(_dummy: int) -> void:
	_add_bodies("stars")
	_add_bodies("planets")
	_add_bodies("moons")
	_minor_bodies_builder.build()
	if add_camera:
		_camera = SaverLoader.make_object_or_scene(_Camera_)
	call_deferred("_finish_build")

func _finish_build() -> void:
	if _use_thread:
		_thread.wait_to_finish()
	yield(_tree, "idle_frame")
	for body in _body_registry.top_bodies:
		_universe.add_child(body)
	if add_camera:
		_camera.add_to_tree()
	_thread = null
	if _main_prog_bar:
		_main_prog_bar.stop()
	emit_signal("finished")

func _add_bodies(table_name: String) -> void:
	var n_rows := _table_reader.get_n_table_rows(table_name)
	var row := 0
	while row < n_rows:
		var parent := _table_reader.get_body(table_name, "parent", row) # null for Sun
		var body := _body_builder.build_from_table(table_name, row, parent)
		if parent:
			parent.add_child(body)
			parent.satellites.append(body)
		_progress_bodies += 1
		# warning-ignore:integer_division
		progress = 100 * _progress_bodies / progress_bodies_denominator
		row += 1

