# selection_image.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
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
# GUI widget. An ancestor Control must have member selection_manager.

extends TextureRect

var image_sizes := [200, 280, 360]

var _selection_manager: SelectionManager

func _ready() -> void:
	Global.connect("system_tree_ready", self, "_on_system_tree_ready")
	Global.connect("setting_changed", self, "_settings_listener")

func _on_system_tree_ready(_is_loaded_game: bool) -> void:
	_selection_manager = GUIUtils.get_selection_manager(self)
	_selection_manager.connect("selection_changed", self, "_on_selection_changed")
	var gui_size: int = Global.settings.gui_size
	_resize(image_sizes[gui_size])
	_on_selection_changed()

func _on_selection_changed() -> void:
	var texture_2d := _selection_manager.get_texture_2d()
	if texture_2d:
		texture = texture_2d

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		Global.emit_signal("move_camera_to_selection_requested", _selection_manager.selection_item,
				-1, Vector3.ZERO, Vector3.ZERO, -1)

func _resize(size: int) -> void:
	rect_min_size = Vector2(size, size)

func _settings_listener(setting: String, value) -> void:
	match setting:
		"gui_size":
			_resize(image_sizes[value])
