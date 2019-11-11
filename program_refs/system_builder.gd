# system_builder.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2019 Charlie Whitfield
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
#
# Builds the star system(s) from data tables & binaries.

extends Reference
class_name SystemBuilder

signal finished()

# project var
var progress_bodies_denominator := 267 # set to something greater than expected

var progress := 0 # for MainProgBar
var _use_thread: bool = Global.use_threads
var _table_data: Dictionary = Global.table_data
var _enums: Dictionary = Global.enums
var _tree: SceneTree = Global.get_tree()
var _root: Viewport = _tree.get_root()
var _main_prog_bar: MainProgBar
var _body_builder: BodyBuilder
var _registrar: Registrar
var _minor_bodies_builder: MinorBodiesBuilder
var _WorldEnvironment_: Script
var _VoyagerCamera_: Script
var _Body_: Script
var _progress_bodies := 0
var _thread: Thread
var _camera: VoyagerCamera
var _starfield: WorldEnvironment


func build() -> void:
	print("Building solar system...")
	_main_prog_bar.start(self)
	if _use_thread:
		_thread = Thread.new()
		_thread.start(self, "_build_on_thread", 0)
	else:
		_build_on_thread(0)


func project_init():
	_main_prog_bar = Global.objects.MainProgBar
	_body_builder = Global.objects.BodyBuilder
	_registrar = Global.objects.Registrar
	_minor_bodies_builder = Global.objects.MinorBodiesBuilder
	_WorldEnvironment_ = Global.script_classes._WorldEnvironment_
	_VoyagerCamera_ = Global.script_classes._VoyagerCamera_
	_Body_ = Global.script_classes._Body_

func _build_on_thread(_dummy: int) -> void:
	_add_bodies(_table_data.star_data, _enums.DATA_TABLE_STAR)
	_add_bodies(_table_data.planet_data, _enums.DATA_TABLE_PLANET)
	_add_bodies(_table_data.moon_data, _enums.DATA_TABLE_MOON)
	_minor_bodies_builder.build()
	_registrar.do_selection_counts_after_system_build()
	_starfield = SaverLoader.make_object_or_scene(_WorldEnvironment_)
	_camera = SaverLoader.make_object_or_scene(_VoyagerCamera_)
	call_deferred("_finish_build")

func _finish_build() -> void:
	if _use_thread:
		_thread.wait_to_finish()
	yield(_tree, "idle_frame")
	var top_body: Body = _registrar.top_body
	top_body.add_child(_starfield)
	_root.add_child(top_body)
	_tree.set_current_scene(top_body)
	var start_body: Body = _registrar.bodies_by_name[Global.start_body_name]
	start_body.add_child(_camera)
	top_body.pause_mode = Node.PAUSE_MODE_PROCESS
	_thread = null
	_main_prog_bar.stop()
	emit_signal("finished")

func _add_bodies(data_table: Array, data_table_type: int) -> void:
	for data in data_table:
		var body: Body = SaverLoader.make_object_or_scene(_Body_)
		var parent: Body
		if data.parent != "is_top":
			parent = _registrar.bodies_by_name[data.parent]
		_body_builder.build(body, data_table_type, data, parent)
		if parent:
			parent.add_child(body)
			parent.satellites.append(body)
#		_do_counts(body, selection_item)
		_progress_bodies += 1
		# warning-ignore:integer_division
		progress = 100 * _progress_bodies / progress_bodies_denominator

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



