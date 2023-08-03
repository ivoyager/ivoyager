# system_builder.gd
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
class_name IVSystemBuilder
extends RefCounted

# Builds the star system(s) from data tables & binaries.

# project vars
var add_small_bodies_groups := false
var add_camera := true

# private
var _table_reader: IVTableReader
var _body_builder: IVBodyBuilder
var _sbg_builder: IVSBGBuilder


func _project_init():
	IVGlobal.state_manager_inited.connect(_on_state_manager_inited, CONNECT_ONE_SHOT)
	_table_reader = IVGlobal.program.TableReader
	_body_builder = IVGlobal.program.BodyBuilder
	_sbg_builder = IVGlobal.program.SBGBuilder


func _on_state_manager_inited() -> void:
	if IVGlobal.skip_splash_screen:
		build_system_tree()


func build_system_tree() -> void:
	if !IVGlobal.state.is_splash_screen:
		return
	var state_manager: IVStateManager = IVGlobal.program.StateManager
	state_manager.require_stop(state_manager, IVEnums.NetworkStopSync.BUILD_SYSTEM, true)
	IVGlobal.about_to_build_system_tree.emit()
	for table_name in IVGlobal.body_tables:
		_add_bodies(table_name)
	if add_small_bodies_groups:
		_sbg_builder.build_sbgs()
	if add_camera:
		_add_camera()
	IVGlobal.system_tree_built_or_loaded.emit(true)


func _add_bodies(table_name: String) -> void:
	var n_rows := _table_reader.get_n_rows(table_name)
	var row := 0
	while row < n_rows:
		var parent: IVBody
		var parent_name := _table_reader.get_string(table_name, "parent", row) # "" top
		if parent_name:
			parent = IVGlobal.bodies[parent_name]
		var body := _body_builder.build_from_table(table_name, row, parent)
		body.hide() # Bodies set their own visibility as needed
		if parent:
			parent.add_child(body)
			parent.satellites.append(body)
		else: # top body
			var universe: Node3D = IVGlobal.program.Universe
			universe.add_child(body)
		row += 1


func _add_camera() -> void:
	var _Camera_: GDScript = IVGlobal.script_classes._Camera_
	var camera: Camera3D = _Camera_.new()
	var start_body: IVBody = IVGlobal.bodies[IVGlobal.home_name]
	start_body.add_child(camera)
