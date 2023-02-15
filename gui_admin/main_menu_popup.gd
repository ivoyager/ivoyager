# main_menu_popup.gd
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
class_name IVMainMenuPopup
extends Popup
const SCENE := "res://ivoyager/gui_admin/main_menu_popup.tscn"

# Unlike all other popups, this one is always listening for "ui_cancel". Other
# popups listen only when open and process before IVMainMenuPopup (due to order
# in IVProjectBuilder).

var center := true # if false, set $PanelContainer margins
var stop_sim := true

var _state: Dictionary = IVGlobal.state

onready var _state_manager: IVStateManager = IVGlobal.program.StateManager


func _project_init():
	connect("popup_hide", self, "_on_popup_hide")
	IVGlobal.connect("open_main_menu_requested", self, "_open")
	IVGlobal.connect("close_main_menu_requested", self, "hide")
	IVGlobal.connect("close_all_admin_popups_requested", self, "hide")


func _ready() -> void:
	theme = IVGlobal.themes.main_menu
	if center:
		$PanelContainer.set_anchors_and_margins_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
		$PanelContainer.grow_horizontal = GROW_DIRECTION_BOTH
		$PanelContainer.grow_vertical = GROW_DIRECTION_BOTH


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


func _open() -> void:
	if stop_sim:
		_state_manager.require_stop(self)
	popup()


func _on_popup_hide() -> void:
	if stop_sim:
		_state_manager.allow_run(self)
