# system_builder.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
# Copyright (c) 2017-2020 Charlie Whitfield
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
var _table_data: Dictionary = Global.table_data
var _table_fields: Dictionary = Global.table_fields
var _table_data_types: Dictionary = Global.table_data_types
var _tree: SceneTree = Global.get_tree()
var _root: Viewport = _tree.get_root()
var _universe: Spatial
var _main_prog_bar: MainProgBar
var _body_builder: BodyBuilder
var _minor_bodies_builder: MinorBodiesBuilder
var _registrar: Registrar
var _table_helper: TableHelper
#var _WorldEnvironment_: Script
var _Camera_: Script
var _progress_bodies := 0
var _thread: Thread
var _camera: Camera
#var _starfield: WorldEnvironment


func project_init():
	_universe = Global.program.universe
	_main_prog_bar = Global.program.get("MainProgBar") # safe if doesn't exist
	_body_builder = Global.program.BodyBuilder
	_minor_bodies_builder = Global.program.MinorBodiesBuilder
	_registrar = Global.program.Registrar
	_table_helper = Global.program.TableHelper
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
	_registrar.do_selection_counts_after_system_build()
	if add_camera:
		_camera = SaverLoader.make_object_or_scene(_Camera_)
	call_deferred("_finish_build")

func _finish_build() -> void:
	if _use_thread:
		_thread.wait_to_finish()
	yield(_tree, "idle_frame")
	for body in _registrar.top_bodies:
		_universe.add_child(body)
	if add_camera:
		var start_body: Body = _registrar.bodies_by_name[Global.start_body_name]
		start_body.add_child(_camera)
	_thread = null
	if _main_prog_bar:
		_main_prog_bar.stop()
	emit_signal("finished")

func _add_bodies(table_name: String) -> void:
	var data: Array = _table_data[table_name]
	var n_rows := data.size()
	var row := 0
	while row < n_rows:
		var parent := _table_helper.get_body(table_name, "parent", row) # null for Sun
		var body := _body_builder.build(table_name, row, parent)
		if parent:
			parent.add_child(body)
			parent.satellites.append(body)
#		_do_counts(body, selection_item)
		_progress_bodies += 1
		# warning-ignore:integer_division
		progress = 100 * _progress_bodies / progress_bodies_denominator
		row += 1

#func _do_counts(body: Body, selection_item: SelectionItem) -> void:
#		if body.is_star:
#			body.n_planets = 0
#			body.n_dwarf_planets = 0
#			body.n_moons = 0
#			body.n_asteroids = 0
#			body.n_comets = 0
#
#		elif body.is_planet:
#			body.n_moons = 0
##			var parent_star := _registrar.get_parent_by_system_type(body, Global.SYSTEM_STAR)
##			if body.is_dwarf_planet:
##				parent_star.n_dwarf_planets += 1
##
##			else:
##				parent_star.n_planets += 1
#
#		elif body.is_moon:
#			pass
##			var parent_star := _registrar.get_parent_by_system_type(body, Global.SYSTEM_STAR)
##			parent_star.n_moons += 1
##			var parent_planet := _registrar.get_parent_by_system_type(body, Global.SYSTEM_PLANET)
##			parent_planet.n_moons += 1



