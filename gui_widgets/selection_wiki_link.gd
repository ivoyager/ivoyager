# selection_wiki_link.gd
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
# Note: RichTextLabel seems unable to set its own size. You have to set this
# node's rect_min_size for it to show (as of Godot 3.2.1).
# Note 2: Set IVGlobal.enable_wiki = true

extends RichTextLabel

var use_selection_as_text := true # otherwise, "Wikipedia"
var fallback_text := "LABEL_WIKIPEDIA"

var _selection_manager: SelectionManager
var _wiki_titles: Dictionary = IVGlobal.wiki_titles
var _wiki_locale: String = IVGlobal.wiki

func _ready():
	IVGlobal.connect("about_to_start_simulator", self, "_on_about_to_start_simulator")
	connect("meta_clicked", self, "_on_wiki_clicked")
	size_flags_horizontal = SIZE_EXPAND_FILL

func _on_about_to_start_simulator(_is_new_game: bool) -> void:
	_selection_manager = GUIUtils.get_selection_manager(self)
	if use_selection_as_text:
		_selection_manager.connect("selection_changed", self, "_on_selection_changed")
		_on_selection_changed()
	else:
		bbcode_text = "[url]" + tr(fallback_text) + "[/url]"

func _on_selection_changed() -> void:
	var object_name: String = _selection_manager.get_name()
	bbcode_text = "[url]" + tr(object_name) + "[/url]"

func _on_wiki_clicked(_meta: String) -> void:
	var object_name: String = _selection_manager.get_name()
	if !_wiki_titles.has(object_name):
		return
	var wiki_title: String = _wiki_titles[object_name]
	IVGlobal.emit_signal("open_wiki_requested", wiki_title)
