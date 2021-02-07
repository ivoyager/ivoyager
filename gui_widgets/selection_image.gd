# selection_image.gd
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
# GUI widget. An ancestor Control must have member "selection_manager".

extends TextureRect

var _selection_manager: SelectionManager
var _hint_extension := "\n\n" + tr("HINT_SELECTION_IMAGE")

func _ready() -> void:
	Global.connect("system_tree_ready", self, "_on_system_tree_ready")

func _on_system_tree_ready(_is_loaded_game: bool) -> void:
	_selection_manager = GUIUtils.get_selection_manager(self)
	_selection_manager.connect("selection_changed", self, "_on_selection_changed")
	_on_selection_changed()

func _on_selection_changed() -> void:
	hint_tooltip = tr(_selection_manager.get_name()) + _hint_extension
	var texture_2d := _selection_manager.get_texture_2d()
	if texture_2d:
		texture = texture_2d

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		# image click centers and "levels" the target body
		Global.emit_signal("move_camera_to_selection_requested", _selection_manager.selection_item,
				-1, Vector3.ZERO, Vector3.ZERO, -1)
