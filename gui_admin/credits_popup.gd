# credits_popup.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2022 Charlie Whitfield
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
class_name IVCreditsPopup
extends PopupPanel
const SCENE := "res://ivoyager/gui_admin/credits_popup.tscn"

# WIP - I'm not super happy with the credits appearance right now. Needs work!
# This was narrowly coded to parse ivoyager/CREDITS.md or file with identical
# markup. Someone can generalize if they want.

# project vars - modify on project_objects_instantiated signal
var stop_sim := true
var file_path := "res://ivoyager/CREDITS.md" # change to "res://CREDITS.md"

var _blocking_popups: Array = IVGlobal.blocking_popups
var _state_manager: IVStateManager

func _project_init() -> void:
	_state_manager = IVGlobal.program.StateManager


func _ready() -> void:
	theme = IVGlobal.themes.main
	set_process_input(false)
	IVGlobal.connect("close_all_admin_popups_requested", self, "hide")
	connect("popup_hide", self, "_on_hide")
	find_node("Close").connect("pressed", self, "hide")
	find_node("MDFileLabel").read_file("res://ivoyager/CREDITS.md")
	_blocking_popups.append(self)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		hide()


func open() -> void:
	if _is_blocking_popup():
		return
	set_process_input(true)
	if stop_sim:
		_state_manager.require_stop(self)
	popup_centered_minsize()


func _on_hide() -> void:
	set_process_input(false)
	if stop_sim:
		_state_manager.allow_run(self)


func _is_blocking_popup() -> bool:
	for popup in _blocking_popups:
		if popup.visible:
			return true
	return false
