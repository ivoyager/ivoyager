# system_builder.gd
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
# Builds the star system(s) from data tables & binaries.

class_name SystemBuilder

# project vars
var add_camera := true
var progress_multiplier := 0.9

 # read-only for MainProgBar
var progress := 0

# private
var _main_prog_bar: MainProgBar
var _table_reader: TableReader
var _body_builder: BodyBuilder
var _progress_count := 0
var _progress_denominator := 1


func build_system_tree() -> void:
	if !Global.state.is_splash_screen:
		return
	var state_manager: StateManager = Global.program.StateManager
	state_manager.require_stop(state_manager, Enums.NetworkStopSync.BUILD_SYSTEM, true)
	Global.emit_signal("about_to_build_system_tree")
	if _main_prog_bar:
		_main_prog_bar.start(self)
	var io_manager: IOManager = Global.program.IOManager
	io_manager.callback(self, "build_on_io_callback", "io_finish")

# *****************************************************************************
# IOManager callbacks

func build_on_io_callback(array: Array) -> void: # I/O thread!
	array.append(OS.get_system_time_msecs())
	_count_for_progress_bar()
	_add_bodies("stars")
	_add_bodies("planets")
	_add_bodies("moons")
	var minor_bodies_builder: MinorBodiesBuilder = Global.program.MinorBodiesBuilder
	minor_bodies_builder.build()
	if add_camera:
		var camera_script: Script = Global.script_classes._Camera_
		var camera: Camera = camera_script.new()
		array.append(camera) 

func io_finish(array: Array) -> void: # Main thread
	var body_registry: BodyRegistry = Global.program.BodyRegistry
	var universe: Spatial = Global.program.Universe
	for body in body_registry.top_bodies:
		universe.add_child(body)
	if add_camera:
		var camera: Camera = array[1]
		camera.add_to_tree() # FIXME: Camera shouldn't add itself
	if _main_prog_bar:
		_main_prog_bar.stop()
	_progress_count = 0
	var start_time: int = array[0]
	var time := OS.get_system_time_msecs() - start_time
	print("System tree built in %s msec" % time)
	Global.emit_signal("system_tree_built_or_loaded", true)

# *****************************************************************************
# Init & private

func project_init():
	_main_prog_bar = Global.program.get("MainProgBar") # safe if doesn't exist
	_body_builder = Global.program.BodyBuilder
	_table_reader = Global.program.TableReader
	Global.connect("state_manager_inited", self, "_on_state_manager_inited")

func _on_state_manager_inited() -> void:
	if Global.skip_splash_screen:
		build_system_tree()

func _count_for_progress_bar() -> void: # I/O thread!
	_progress_denominator = _table_reader.get_n_rows("stars")
	_progress_denominator += _table_reader.get_n_rows("planets")
	_progress_denominator += _table_reader.get_n_rows("moons")
	_progress_denominator = int(_progress_denominator / progress_multiplier)

func _add_bodies(table_name: String) -> void: # I/O thread!
	var n_rows := _table_reader.get_n_rows(table_name)
	var row := 0
	while row < n_rows:
		var parent := _table_reader.get_body(table_name, "parent", row) # null for Sun
		var body := _body_builder.build_from_table(table_name, row, parent)
		if parent:
			parent.add_child(body)
			parent.satellites.append(body)
		_progress_count += 1
		# warning-ignore:integer_division
		progress = 100 * _progress_count / _progress_denominator
		row += 1
