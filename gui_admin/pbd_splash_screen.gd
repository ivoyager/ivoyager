# pbd_splash_screen.gd
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

extends Control
class_name PBDSplashScreen
const SCENE := "res://ivoyager/gui_admin/pbd_splash_screen.tscn"

var _settings: Dictionary = Global.settings
var _settings_manager: SettingsManager
var _main_menu: MainMenu
var _copyright: Label
var _pbd_caption: Label

func project_init():
	connect("ready", self, "_on_ready")
	_settings_manager = Global.objects.SettingsManager
	_main_menu = Global.objects.MainMenu
	theme = Global.themes.splash_screen

func _on_ready():
	Global.connect("project_builder_finished", self, "_on_project_builder_finished")
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator")
	Global.connect("simulator_exited", self, "show")
	_copyright = $Copyright
	_pbd_caption = $PBDCaption
	_pbd_caption.connect("mouse_entered", self, "_pbd_mouse_entered")
	_pbd_caption.connect("mouse_exited", self, "_pbd_mouse_exited")
	_pbd_caption.connect("gui_input", self, "_pbd_caption_input")
	_pbd_caption.set("custom_colors/font_color", Color.lightskyblue)
	_pbd_caption.text = "LABEL_PBD_LONG" if _settings.pbd_splash_caption_open else "LABEL_PBD_SHORT"
	if Global.skip_splash_screen:
		hide()

func _on_project_builder_finished() -> void:
	_copyright.margin_left = _main_menu.margin_left
	_copyright.margin_top = _main_menu.rect_position.y + _main_menu.rect_size.y + 40
	_copyright.show()

func _on_about_to_start_simulator(_is_new_game: bool) -> void:
	hide()

func _pbd_mouse_entered() -> void:
	_pbd_caption.set("custom_colors/font_color", Color.white)
	
func _pbd_mouse_exited() -> void:
	_pbd_caption.set("custom_colors/font_color", Color.lightskyblue)

func _pbd_caption_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		var is_open: bool = !_settings.pbd_splash_caption_open
		_settings_manager.change_current("pbd_splash_caption_open", is_open)
		_pbd_caption.text = "LABEL_PBD_LONG" if is_open else "LABEL_PBD_SHORT"
