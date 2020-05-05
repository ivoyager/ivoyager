# font_manager.gd
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
# Maintains Global.fonts.

extends Reference
class_name FontManager

# project vars - modify on "project_objects_instantiated" signal
var fixed_sizes := {
	two_pt = 2, # hack to allow small button height (e.g., in SystemNavigator)
	medium = 22,
	large = 28,
	}
var gui_main_sizes := [14, 16, 20] # Settings.UISizes
var gui_medium_sizes := [18, 20, 24]
var gui_large_sizes := [22, 24, 28] 

# private
var _fonts: Dictionary = Global.fonts
var _settings: Dictionary = Global.settings
var _primary_font_data: DynamicFontData

func project_init() -> void:
	Global.connect("project_builder_finished", self, "_on_project_builder_finished",
			[], CONNECT_ONESHOT)
	Global.connect("setting_changed", self, "_settings_listener")
	_primary_font_data = Global.assets.primary_font_data
	for key in fixed_sizes:
		_fonts[key] = DynamicFont.new()
		_fonts[key].font_data = _primary_font_data
		_fonts[key].size = fixed_sizes[key]
	_fonts.gui_main = DynamicFont.new()
	_fonts.gui_medium = DynamicFont.new()
	_fonts.gui_large = DynamicFont.new()
	_fonts.hud_labels = DynamicFont.new()
	_fonts.gui_main.font_data = _primary_font_data
	_fonts.gui_medium.font_data = _primary_font_data
	_fonts.gui_large.font_data = _primary_font_data
	_fonts.hud_labels.font_data = _primary_font_data

func _on_project_builder_finished() -> void:
	_fonts.gui_main.size = gui_main_sizes[_settings.gui_size]
	_fonts.gui_medium.size = gui_medium_sizes[_settings.gui_size]
	_fonts.gui_large.size = gui_large_sizes[_settings.gui_size]
	_fonts.hud_labels.size = _settings.viewport_label_size

func _settings_listener(setting: String, value) -> void:
	match setting:
		"viewport_label_size":
			_fonts.hud_labels.size = value
		"gui_size":
			_fonts.gui_main.size = gui_main_sizes[value]
			_fonts.gui_medium.size = gui_medium_sizes[value]
			_fonts.gui_large.size = gui_large_sizes[value]

