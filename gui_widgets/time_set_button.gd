# time_set_button.gd
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
class_name IVTimeSetButton
extends Button

# GUI button widget that opens its own IVTimeSetPopup.

var _time_set_popup: IVTimeSetPopup


func _ready() -> void:
	var top_gui: Control = IVGlobal.program.TopGUI
	_time_set_popup = IVFiles.make_object_or_scene(IVTimeSetPopup)
	top_gui.add_child(_time_set_popup)
	toggled.connect(_on_toggled)
	_time_set_popup.visibility_changed.connect(_on_visibility_changed)


func _on_toggled(toggle_pressed) -> void:
	if toggle_pressed:
		_time_set_popup.popup()
		await get_tree().process_frame # popup may not know its correct size yet
		var popup_position := global_position - Vector2(_time_set_popup.size)
		popup_position.x += size.x / 2.0
		if popup_position.x < 0.0:
			popup_position.x = 0.0
		if popup_position.y < 0.0:
			popup_position.y = 0.0
		_time_set_popup.position = popup_position
	else:
		_time_set_popup.hide()


func _on_visibility_changed() -> void:
	await get_tree().process_frame
	if !_time_set_popup.visible:
		button_pressed = false

