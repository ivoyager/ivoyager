# selection_buttons.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2020 Charlie Whitfield
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
# GUI widget.

extends HBoxContainer

var _selection_manager: SelectionManager
onready var _back: Button = $Back
onready var _forward: Button = $Forward
onready var _up: Button = $Up

func _ready():
	Global.connect("system_tree_ready", self, "_on_system_tree_ready", [], CONNECT_ONESHOT)

func _on_system_tree_ready(_is_loaded_game: bool) -> void:
	_selection_manager = GUIHelper.get_selection_manager(self)
	_selection_manager.connect("selection_changed", self, "_update_buttons")
	_back.connect("pressed", _selection_manager, "back")
	_forward.connect("pressed", _selection_manager, "forward")
	_up.connect("pressed", _selection_manager, "up")
	_update_buttons()

func _update_buttons() -> void:
	_back.disabled = !_selection_manager.can_go_back()
	_forward.disabled = !_selection_manager.can_go_forward()
	_up.disabled = !_selection_manager.can_go_up()
	