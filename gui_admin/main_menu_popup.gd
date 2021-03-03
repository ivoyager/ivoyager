# main_menu_popup.gd
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
# Unlike all other popups, this one is always listening for "ui_cancel". Other
# popups listen only when open and process before MainMenuPopup (due to order
# in ProjectBuilder).

extends Popup
class_name MainMenuPopup
const SCENE := "res://ivoyager/gui_admin/main_menu_popup.tscn"

var center := false # set for centered; otherwise, set $MainMenu margins
var stop_sim := true

var _state: Dictionary = Global.state
onready var _state_manager: StateManager = Global.program.StateManager

func _project_init():
	connect("popup_hide", self, "_on_popup_hide")
	Global.connect("open_main_menu_requested", self, "_open")
	Global.connect("close_main_menu_requested", self, "hide")
	Global.connect("close_all_admin_popups_requested", self, "hide")
	var main_menu_manager: MainMenuManager = Global.program.MainMenuManager
	main_menu_manager.make_button("BUTTON_RESUME", 100, false, true, self, "hide")

func _ready() -> void:
	theme = Global.themes.main_menu
	if center:
		$MainMenu.set_anchors_and_margins_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
		$MainMenu.grow_horizontal = GROW_DIRECTION_BOTH
		$MainMenu.grow_vertical = GROW_DIRECTION_BOTH

func _open() -> void:
	if stop_sim:
		_state_manager.require_stop(self)
	popup()

func _on_popup_hide() -> void:
	if stop_sim:
		_state_manager.allow_run(self)

func _unhandled_key_input(event: InputEventKey) -> void:
	if !_state.is_system_built:
		# bypass; the splash screen should have its own MainMenu widget!
		return
	if event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		if is_visible_in_tree():
			hide()
		else:
			_open()
