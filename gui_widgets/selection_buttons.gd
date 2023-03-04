# selection_buttons.gd
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
class_name IVSelectionButtons
extends HBoxContainer

# GUI widget.

var _selection_manager: IVSelectionManager

onready var _back: Button = $Back
onready var _forward: Button = $Forward
onready var _up: Button = $Up


func _ready() -> void:
	IVGlobal.connect("about_to_start_simulator", self, "_connect_selection_manager")
	IVGlobal.connect("update_gui_requested", self, "_update_buttons")
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_clear")
	_connect_selection_manager()


func _connect_selection_manager(_dummy := false) -> void:
	if _selection_manager:
		return
	_selection_manager = IVWidgets.get_selection_manager(self)
	if !_selection_manager:
		return
	_selection_manager.connect("selection_changed", self, "_update_buttons")
	_back.connect("pressed", _selection_manager, "back")
	_forward.connect("pressed", _selection_manager, "forward")
	_up.connect("pressed", _selection_manager, "up")
	_update_buttons()


func _update_buttons(_dummy := false) -> void:
	_back.disabled = !_selection_manager.can_go_back()
	_forward.disabled = !_selection_manager.can_go_forward()
	_up.disabled = !_selection_manager.can_go_up()


func _clear() -> void:
	_selection_manager = null
