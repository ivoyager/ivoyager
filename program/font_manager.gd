# font_manager.gd
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
class_name IVFontManager
extends RefCounted

# Maintains IVGlobal.fonts.

# project vars - modify on signal project_objects_instantiated
var fixed_sizes := {
	two_pt = 2, # hack to allow small button height (e.g., in SystemNavigator)
	medium = 22,
	large = 28,
}
var gui_main_sizes: Array[int] = [12, 16, 20] # GUI_SMALL, GUI_MEDIUM, GUI_LARGE
var gui_medium_sizes: Array[int] = [15, 20, 25]
var gui_large_sizes: Array[int] = [18, 24, 31] 

# private
var _fonts: Dictionary = IVGlobal.fonts
var _settings: Dictionary = IVGlobal.settings
var _primary_font: FontFile


func _project_init() -> void:
	IVGlobal.setting_changed.connect(_settings_listener)
	_primary_font = IVGlobal.assets[&"primary_font"]
	for key in fixed_sizes:
		_fonts[key] = _primary_font.duplicate()
		_fonts[key].fixed_size = fixed_sizes[key]
	_fonts[&"gui_main"] = _primary_font.duplicate()
	_fonts[&"gui_medium"] = _primary_font.duplicate()
	_fonts[&"gui_large"] = _primary_font.duplicate()
	_fonts[&"hud_names"] = _primary_font.duplicate()
	_fonts[&"hud_symbols"] = _primary_font.duplicate()
	_fonts[&"gui_main"].fixed_size = gui_main_sizes[_settings[&"gui_size"]]
	_fonts[&"gui_medium"].fixed_size = gui_medium_sizes[_settings[&"gui_size"]]
	_fonts[&"gui_large"].fixed_size = gui_large_sizes[_settings[&"gui_size"]]
	_fonts[&"hud_names"].fixed_size = _settings[&"viewport_names_size"]
	_fonts[&"hud_symbols"].fixed_size = _settings[&"viewport_symbols_size"]


func _settings_listener(setting: StringName, value: Variant) -> void:
	match setting:
		&"viewport_names_size":
			_fonts[&"hud_names"].fixed_size = value
		&"viewport_symbols_size":
			_fonts[&"hud_symbols"].fixed_size = value
		&"gui_size":
			_fonts[&"gui_main"].fixed_size = gui_main_sizes[value]
			_fonts[&"gui_medium"].fixed_size = gui_medium_sizes[value]
			_fonts[&"gui_large"].fixed_size = gui_large_sizes[value]

