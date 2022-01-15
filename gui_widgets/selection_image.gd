# selection_image.gd
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
extends TextureRect

# GUI widget. An ancestor Control must have member "selection_manager".

var _hint_extension := "\n\n" + tr("HINT_SELECTION_IMAGE")
var _selection_manager: IVSelectionManager


func _ready() -> void:
	IVGlobal.connect("about_to_start_simulator", self, "_on_about_to_start_simulator")
	IVGlobal.connect("update_gui_requested", self, "_update_image")
	set_default_cursor_shape(CURSOR_POINTING_HAND)


func _on_about_to_start_simulator(_is_loaded_game: bool) -> void:
	_selection_manager = IVGUIUtils.get_selection_manager(self)
	_selection_manager.connect("selection_changed", self, "_update_image")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		# image click centers and "levels" the target body
		IVGlobal.emit_signal("move_camera_to_selection_requested", _selection_manager.selection_item,
				-1, Vector3.ZERO, Vector3.ZERO, -1)


func _update_image() -> void:
	hint_tooltip = tr(_selection_manager.get_name()) + _hint_extension
	var texture_2d := _selection_manager.get_texture_2d()
	if texture_2d:
		texture = texture_2d
