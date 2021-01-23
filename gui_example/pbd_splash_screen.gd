# pbd_splash_screen.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# "I, Voyager" is a registered trademark of Charlie Whitfield
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
# Example splash screen with Pale Blue Dot image and interactive text. You
# probably want to replace this.
#
# TODO: Rebuild this using Containers. (Now that I know how to use them!)

extends Control
class_name PBDSplashScreen
const SCENE := "res://ivoyager/gui_example/pbd_splash_screen.tscn"

var _settings: Dictionary = Global.settings
var _settings_manager: SettingsManager
onready var _pbd_caption: Label = $PBDCaption

func project_init():
	Global.connect("state_manager_inited", self, "_on_state_manager_inited", [], CONNECT_ONESHOT)
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator")
	Global.connect("simulator_exited", self, "show")
	_settings_manager = Global.program.SettingsManager

func _ready():
	theme = Global.themes.splash_screen
	$VersionLabel.set_version_label("", true, true, "\n", "",
			"\n\n(c) 2017-2021\nCharlie Whitfield")
	$MainMenu.is_splash_config = true
	_pbd_caption.connect("mouse_entered", self, "_pbd_mouse_entered")
	_pbd_caption.connect("mouse_exited", self, "_pbd_mouse_exited")
	_pbd_caption.connect("gui_input", self, "_pbd_caption_input")
	_pbd_caption.set("custom_colors/font_color", Color.lightskyblue)
	_pbd_caption.text = "TXT_PBD_LONG" if _settings.pbd_splash_caption_open else "TXT_PBD_SHORT"
	if Global.skip_splash_screen:
		hide()

func _on_state_manager_inited() -> void:
	pass

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
