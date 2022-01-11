# system_builder.gd
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
# Builds the star system(s) from data tables & binaries.

class_name SystemBuilder

# project vars
var add_camera := true

# private
var _table_reader: TableReader
var _body_builder: BodyBuilder


func build_system_tree() -> void:
	if !IVGlobal.state.is_splash_screen:
		return
	var state_manager: StateManager = IVGlobal.program.StateManager
	state_manager.require_stop(state_manager, Enums.NetworkStopSync.BUILD_SYSTEM, true)
	IVGlobal.emit_signal("about_to_build_system_tree")
	_body_builder.init_system_build()
	_add_bodies("stars")
	_add_bodies("planets")
	_add_bodies("moons")
	var minor_bodies_builder: MinorBodiesBuilder = IVGlobal.program.MinorBodiesBuilder
	minor_bodies_builder.build()
	var selection_builder: SelectionBuilder = IVGlobal.program.SelectionBuilder
	selection_builder.build_body_selection_items()
	if add_camera:
		var camera_script: Script = IVGlobal.script_classes._Camera_
		var camera: Camera = camera_script.new()
		camera.add_to_tree()
	IVGlobal.emit_signal("system_tree_built_or_loaded", true)

# *****************************************************************************

func _project_init():
	_table_reader = IVGlobal.program.TableReader
	_body_builder = IVGlobal.program.BodyBuilder
	IVGlobal.connect("state_manager_inited", self, "_on_state_manager_inited", [], CONNECT_ONESHOT)

func _on_state_manager_inited() -> void:
	if IVGlobal.skip_splash_screen:
		build_system_tree()

func _add_bodies(table_name: String) -> void:
	var n_rows := _table_reader.get_n_rows(table_name)
	var row := 0
	while row < n_rows:
		var parent := _table_reader.get_body(table_name, "parent", row) # null for top
		var body := _body_builder.build_from_table(table_name, row, parent)
		body.hide() # Bodies set their own visibility as needed
		if parent:
			parent.add_child(body)
			parent.satellites.append(body)
		else:
			var universe: Spatial = IVGlobal.program.Universe
			universe.add_child(body)
		row += 1
