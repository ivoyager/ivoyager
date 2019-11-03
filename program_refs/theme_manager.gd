# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2019 Charlie Whitfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# *****************************************************************************
#
# Maintains Global.themes.

extends Reference
class_name ThemeManager


var _themes: Dictionary = Global.themes
var _fonts: Dictionary = Global.fonts
var _settings: Dictionary = Global.settings

func project_init() -> void:
#	Global.connect("project_builder_finished", self, "_on_project_builder_finished")
	var global_theme := Theme.new()
	global_theme.default_font = _fonts.gui_main
	_themes.global = global_theme
	Global.objects.GUITop.theme = global_theme # all other Controls set their own
	var main_menu_theme := Theme.new()
	main_menu_theme.default_font = _fonts.large
	_themes.main_menu = main_menu_theme
	var splash_screen_theme := Theme.new()
	splash_screen_theme.default_font = _fonts.medium
	_themes.splash_screen = splash_screen_theme
	var in_game_theme := Theme.new()
	_themes.in_game = in_game_theme

#func _on_project_builder_finished() -> void:
#	var main_theme: Theme = _themes.main
#	main_theme.default_font = _fonts.small
#	var main_menu_theme: Theme = _themes.main_menu
#	main_menu_theme.default_font = _fonts.large
	
	
	
	