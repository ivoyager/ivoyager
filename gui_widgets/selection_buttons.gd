# selection_buttons.gd
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
#
# UI widget. On _ready(), searches up tree for first ancestor with "selection_manager"
# member.

extends HBoxContainer
class_name SelectionButtons
const SCENE := "res://ivoyager/gui_widgets/selection_buttons.tscn"

var _selection_manager: SelectionManager
onready var _back: Button = $Back
onready var _forward: Button = $Forward
onready var _up: Button = $Up

func _ready():
	var ancestor: Node = get_parent()
	while not "selection_manager" in ancestor:
		ancestor = ancestor.get_parent()
	_selection_manager = ancestor.selection_manager
	_selection_manager.connect("selection_changed", self, "_update_buttons")
	_back.connect("pressed", _selection_manager, "back")
	_forward.connect("pressed", _selection_manager, "forward")
	_up.connect("pressed", _selection_manager, "up")
	_update_buttons()

func _update_buttons() -> void:
	_back.disabled = !_selection_manager.can_go_back()
	_forward.disabled = !_selection_manager.can_go_forward()
	_up.disabled = !_selection_manager.can_go_up()
	