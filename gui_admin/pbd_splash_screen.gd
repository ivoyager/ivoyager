# pbd_splash_screen.gd
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

extends Control
class_name PBDSplashScreen
const SCENE := "res://ivoyager/gui_admin/pbd_splash_screen.tscn"

var _settings: Dictionary = Global.settings
var _settings_manager: SettingsManager
var _main_menu: MainMenu
var _copyright: Label
var _version: Label
var _pbd_caption: Label

func project_init():
	connect("ready", self, "_on_ready")
	_settings_manager = Global.objects.SettingsManager
	_main_menu = Global.objects.get("MainMenu")
	theme = Global.themes.splash_screen

func _on_ready():
	Global.connect("project_builder_finished", self, "_on_project_builder_finished", [], CONNECT_ONESHOT)
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator")
	Global.connect("simulator_exited", self, "show")
	_copyright = $Copyright
	_version = $Version
	_pbd_caption = $PBDCaption
	_pbd_caption.connect("mouse_entered", self, "_pbd_mouse_entered")
	_pbd_caption.connect("mouse_exited", self, "_pbd_mouse_exited")
	_pbd_caption.connect("gui_input", self, "_pbd_caption_input")
	_pbd_caption.set("custom_colors/font_color", Color.lightskyblue)
	_pbd_caption.text = "TXT_PBD_LONG" if _settings.pbd_splash_caption_open else "TXT_PBD_SHORT"
	if Global.skip_splash_screen:
		hide()

func _on_project_builder_finished() -> void:
	_copyright.margin_left = _main_menu.margin_left if _main_menu else 35.0
	_copyright.margin_top = _main_menu.rect_position.y + _main_menu.rect_size.y + 40.0 if _main_menu else 100.0
	_copyright.show()
	_version.text = Global.ivoyager_version
	_version.margin_left = _main_menu.margin_left if _main_menu else 35.0
	_version.show()

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
		_pbd_caption.text = "TXT_PBD_LONG" if is_open else "TXT_PBD_SHORT"
