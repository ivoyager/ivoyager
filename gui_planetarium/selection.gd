# selection.gd
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

extends HBoxContainer

var _selection_manager: SelectionManager
var _wiki_titles: Dictionary

func _ready() -> void:
	Global.connect("system_tree_ready", self, "_on_system_tree_ready")
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator")
	$Controls/Recenter.connect("pressed", Global, "emit_signal",
		["move_camera_to_selection_requested", null, -1, Vector3.ZERO])
	$Controls/Zoom.connect("pressed", Global, "emit_signal",
		["move_camera_to_selection_requested", null, VoyagerCamera.VIEWPOINT_ZOOM, Vector3.ZERO])
	$Controls/FortyFive.connect("pressed", Global, "emit_signal",
		["move_camera_to_selection_requested", null, VoyagerCamera.VIEWPOINT_45, Vector3.ZERO])
	$Controls/Top.connect("pressed", Global, "emit_signal",
		["move_camera_to_selection_requested", null, VoyagerCamera.VIEWPOINT_TOP, Vector3.ZERO])
	$Links.connect("meta_clicked", self, "_on_meta_clicked")

func _on_system_tree_ready(_is_new_game: bool) -> void:
	_wiki_titles = Global.table_data.wiki_titles
	_selection_manager = get_parent().selection_manager

func _on_about_to_start_simulator(_is_new_game: bool) -> void:
	get_parent().register_mouse_trigger_guis(self, [$Controls, $Links])

func _on_meta_clicked(meta: String) -> void:
	if meta == "Wikipedia":
		var object_key: String = _selection_manager.get_name()
		if _wiki_titles.has(object_key):
			var url := "https://en.wikipedia.org/wiki/" + tr(_wiki_titles[object_key])
			OS.shell_open(url)
