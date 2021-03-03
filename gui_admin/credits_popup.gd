# credits_popup.gd
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
# WIP - I'm not super happy with the credits appearance right now. Needs work!
# This was narrowly coded to parse ivoyager/CREDITS.md or file with identical
# markup. Someone can generalize if they want.

extends PopupPanel
class_name CreditsPopup
const SCENE := "res://ivoyager/gui_admin/credits_popup.tscn"


# project vars - modify on project_objects_instantiated signal
var stop_sim := true
var file_path := "res://ivoyager/CREDITS.md" # change to "res://CREDITS.md"

var _state_manager: StateManager


func open() -> void:
	set_process_unhandled_key_input(true)
	if stop_sim:
		_state_manager.require_stop(self)
	popup_centered_minsize()

# *****************************************************************************

func _project_init() -> void:
	_state_manager = Global.program.StateManager

func _ready() -> void:
	theme = Global.themes.main
	set_process_unhandled_key_input(false)
	Global.connect("credits_requested", self, "open")
	
	Global.connect("close_all_admin_popups_requested", self, "hide")
	connect("popup_hide", self, "_on_hide")
	find_node("Close").connect("pressed", self, "hide")
	find_node("MDFileLabel").read_file("res://ivoyager/CREDITS.md")

func _on_hide() -> void:
	set_process_unhandled_key_input(false)
	if stop_sim:
		_state_manager.allow_run(self)

func _unhandled_key_input(event: InputEventKey) -> void:
	_on_unhandled_key_input(event)
	
func _on_unhandled_key_input(event: InputEventKey) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		hide()
