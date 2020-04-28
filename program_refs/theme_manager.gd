# theme_manager.gd
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
# Maintains Global.themes dictionary. This class sets theme for ProjectGUI
# (whatever that is defined as in ProjectBuilder), but all GUIs not under that
# Control must set their own theme from the Global dict.

extends Reference
class_name ThemeManager

var _themes: Dictionary = Global.themes
var _fonts: Dictionary = Global.fonts
var _settings: Dictionary = Global.settings

func project_init() -> void:
	# set global_theme for ProjectGUI
	var global_theme := Theme.new()
	global_theme.default_font = _fonts.gui_main
	_themes.global = global_theme
	Global.program.ProjectGUI.theme = global_theme
	# all non-ProjectGUIs must set their own theme from Global.themes
	var main_menu_theme := Theme.new()
	main_menu_theme.default_font = _fonts.large
	_themes.main_menu = main_menu_theme
	var splash_screen_theme := Theme.new()
	splash_screen_theme.default_font = _fonts.medium
	_themes.splash_screen = splash_screen_theme
	var game_theme := Theme.new()
	_themes.game = game_theme

