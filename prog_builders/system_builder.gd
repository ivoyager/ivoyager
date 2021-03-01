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

# private
var _table_reader: TableReader
var _body_builder: BodyBuilder


func build_system_tree() -> void:
	if !Global.state.is_splash_screen:
		return
	var state_manager: StateManager = Global.program.StateManager
	state_manager.require_stop(state_manager, Enums.NetworkStopSync.BUILD_SYSTEM, true)
	Global.emit_signal("about_to_build_system_tree")
	_body_builder.init_system_build()
	_add_bodies("stars")
	_add_bodies("planets")
	_add_bodies("moons")
	var minor_bodies_builder: MinorBodiesBuilder = Global.program.MinorBodiesBuilder
	minor_bodies_builder.build()
	if add_camera:
		var camera_script: Script = Global.script_classes._Camera_
		var camera: Camera = camera_script.new()
		camera.add_to_tree()
	print("system_tree_built_or_loaded")
	Global.emit_signal("system_tree_built_or_loaded", true)

# *****************************************************************************

func project_init():
	_body_builder = Global.program.BodyBuilder
	_table_reader = Global.program.TableReader
	Global.connect("state_manager_inited", self, "_on_state_manager_inited", [], CONNECT_ONESHOT)

func _on_state_manager_inited() -> void:
	if Global.skip_splash_screen:
		build_system_tree()

func _add_bodies(table_name: String) -> void:
	var n_rows := _table_reader.get_n_rows(table_name)
	var row := 0
	while row < n_rows:
		var parent := _table_reader.get_body(table_name, "parent", row) # null for top
		var body := _body_builder.build_from_table(table_name, row, parent)
		if parent:
			parent.add_child(body)
			parent.satellites.append(body)
		else:
			var universe: Spatial = Global.program.Universe
			universe.add_child(body)
		row += 1
