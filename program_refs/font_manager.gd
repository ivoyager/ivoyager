# font_manager.gd
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
# Maintains Global.fonts.

extends Reference
class_name FontManager

# project vars - modify on "project_objects_instantiated" signal
var fixed_sizes := {
	two_pt = 2, # hack to allow small button height (e.g., in NavigationPanel)
	medium = 22,
	large = 28,
	}
var gui_main_sizes := [14, 16, 20] # Settings.UISizes
var gui_medium_sizes := [18, 20, 24] # I, Voyager doesn't use; we can change if 
var gui_large_sizes := [22, 24, 28]  # there are more sensible default values. 

# private
var _fonts: Dictionary = Global.fonts
var _settings: Dictionary = Global.settings
var _primary_font_data: DynamicFontData

func project_init() -> void:
	Global.connect("setting_changed", self, "_settings_listener")
	_primary_font_data = Global.assets.primary_font_data
	for key in fixed_sizes:
		var dynamic_font = DynamicFont.new()
		dynamic_font.font_data = _primary_font_data
		dynamic_font.size = fixed_sizes[key]
		_fonts[key] = dynamic_font
	var gui_main_font = DynamicFont.new()
	gui_main_font.font_data = _primary_font_data
	gui_main_font.size = gui_main_sizes[_settings.gui_size]
	_fonts.gui_main = gui_main_font
	var gui_medium_font = DynamicFont.new()
	gui_medium_font.font_data = _primary_font_data
	gui_medium_font.size = gui_medium_sizes[_settings.gui_size]
	_fonts.gui_medium = gui_medium_font
	var gui_large_font = DynamicFont.new()
	gui_large_font.font_data = _primary_font_data
	gui_large_font.size = gui_large_sizes[_settings.gui_size]
	_fonts.gui_large = gui_large_font
	var hud_labels_font = DynamicFont.new()
	hud_labels_font.font_data = _primary_font_data
	hud_labels_font.size = _settings.viewport_label_size
	_fonts.hud_labels = hud_labels_font

func _settings_listener(setting: String, value) -> void:
	match setting:
		"viewport_label_size":
			_fonts.hud_labels.size = value
		"gui_size":
			_fonts.gui_main.size = gui_main_sizes[value]
			_fonts.gui_medium.size = gui_medium_sizes[value]
			_fonts.gui_large.size = gui_large_sizes[value]

