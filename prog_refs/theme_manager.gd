# theme_manager.gd
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
# Maintains Global.themes dictionary. All controls are expected to set their
# own theme from this dictionary.

extends Reference
class_name ThemeManager

# project vars
var global_font := "gui_main" # these are defined in FontManager
var main_menu_font := "large"
var splash_screen_font := "medium"

var _themes: Dictionary = Global.themes
var _fonts: Dictionary = Global.fonts

func _project_init() -> void:
	_themes.main = Theme.new()
	_themes.main_menu = Theme.new()
	_themes.splash_screen = Theme.new()
	_themes.main.default_font = _fonts[global_font]
	_themes.main_menu.default_font = _fonts[main_menu_font]
	_themes.splash_screen.default_font = _fonts[splash_screen_font]
