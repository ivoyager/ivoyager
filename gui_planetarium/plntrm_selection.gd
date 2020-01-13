# plntrm_selection.gd
# This file is part of I, Voyager
# https://ivoyager.dev
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

extends HBoxContainer

var _selection_manager: SelectionManager
var _wiki_titles: Dictionary

func _ready() -> void:
	Global.connect("system_tree_ready", self, "_on_system_tree_ready")
	$Links.connect("meta_clicked", self, "_on_meta_clicked")
	get_parent().register_mouse_trigger_guis(self, [$ViewpointButtons, $Links])

func _on_system_tree_ready(_is_new_game: bool) -> void:
	_wiki_titles = Global.table_data.wiki_titles
	_selection_manager = GUIHelper.get_selection_manager(self)

func _on_meta_clicked(meta: String) -> void:
	if meta == "Wikipedia":
		var object_key: String = _selection_manager.get_name()
		if _wiki_titles.has(object_key):
			var url := "https://en.wikipedia.org/wiki/" + tr(_wiki_titles[object_key])
			OS.shell_open(url)
