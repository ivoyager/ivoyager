# selection_image.gd
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
extends TextureRect

# GUI widget. An ancestor Control must have member "selection_manager".

var _hint_extension := "\n\n" + tr("HINT_SELECTION_IMAGE")
var _selection_manager: IVSelectionManager


func _ready() -> void:
	IVGlobal.connect("about_to_start_simulator", self, "_connect_selection_manager")
	IVGlobal.connect("update_gui_requested", self, "_update_image")
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_clear")
	set_default_cursor_shape(CURSOR_POINTING_HAND)
	_connect_selection_manager()


func _clear() -> void:
	_selection_manager = null


func _connect_selection_manager(_dummy := false) -> void:
	if _selection_manager:
		return
	_selection_manager = IVWidgets.get_selection_manager(self)
	if !_selection_manager:
		return
	_selection_manager.connect("selection_changed", self, "_update_image")
	_update_image()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		# image click centers and "levels" the target body
		IVGlobal.emit_signal("move_camera_to_selection_requested", _selection_manager.selection,
				-1, Vector3.ZERO, Vector3.ZERO, -1)


func _update_image() -> void:
	if !_selection_manager.has_selection():
		return
	hint_tooltip = tr(_selection_manager.get_body_name()) + _hint_extension
	var texture_2d := _selection_manager.get_texture_2d()
	if texture_2d:
		texture = texture_2d
