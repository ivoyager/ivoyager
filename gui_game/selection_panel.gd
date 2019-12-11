# selection_panel.gd
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

extends DraggablePanel
class_name SelectionPanel
const SCENE := "res://ivoyager/gui_game/selection_panel.tscn"

var _selection_name: Label
var _selection_image: TextureRect

func _on_ready() -> void:
	._on_ready()
	_selection_name = $ImageBox/NameBox/ObjName
	_selection_image = $ImageBox/ObjImage
	Global.connect("gui_refresh_requested", self, "_update_selection")
	_selection_image.connect("gui_input", self, "_on_selection_image_gui_input")
	get_parent().selection_manager.connect("selection_changed", self, "_update_selection")

func _prepare_for_deletion() -> void:
	._prepare_for_deletion()
	Global.disconnect("gui_refresh_requested", self, "_update_selection")
	get_parent().selection_manager.disconnect("selection_changed", self, "_update_selection")

func _update_selection() -> void:
	var selection_manager: SelectionManager = get_parent().selection_manager
	_selection_name.text = selection_manager.get_name()
	_selection_image.texture = selection_manager.get_texture_2d()

func _on_selection_image_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		var selection_manager: SelectionManager = get_parent().selection_manager
		Global.emit_signal("move_camera_to_selection_requested", selection_manager.selection_item, -1, Vector3.ZERO)
