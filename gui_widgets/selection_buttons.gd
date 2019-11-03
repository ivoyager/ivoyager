# selection_buttons.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2019 Charlie Whitfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
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
	