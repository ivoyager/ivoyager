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
extends PopupPanel
const SCENE := "res://ivoyager/gui_popups/main_menu_popup.tscn"


var center := true # if false, set $PanelContainer margins
var stop_sim := true

#var _state: Dictionary = IVGlobal.state
var _allow_close := false

@onready var _state_manager: IVStateManager = IVGlobal.program.StateManager


func _project_init():
	IVGlobal.open_main_menu_requested.connect(open)
	IVGlobal.close_main_menu_requested.connect(close)
	IVGlobal.close_all_admin_popups_requested.connect(close)
	popup_hide.connect(_on_popup_hide)


func _ready() -> void:
	theme = IVGlobal.themes.main_menu


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		set_input_as_handled()
		_allow_close = true


func open() -> void:
	if stop_sim:
		_state_manager.require_stop(self)
	if center:
		popup_centered()
	else:
		popup()


func close() -> void:
	_allow_close = true
	hide()


func _on_popup_hide() -> void:
	if !_allow_close:
		show.call_deferred()
		return
	_allow_close = false
	if stop_sim:
		_state_manager.allow_run(self)

