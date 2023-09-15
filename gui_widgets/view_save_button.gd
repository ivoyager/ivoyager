# view_save_button.gd
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
class_name IVViewSaveButton
extends Button

# GUI button widget that opens its own IVViewSavePopup. Requires IVViewSavePopup
# and IVViewSaver.
#
# Can be placed inside an IVViewSaveFlow.

signal view_saved(view_name)

var _view_save_popup: IVViewSavePopup
var _view_saver: IVViewSaver


func _ready() -> void:
	var top_gui: Control = IVGlobal.program.TopGUI
	_view_save_popup = IVFiles.make_object_or_scene(IVViewSavePopup)
	_view_saver = _view_save_popup.find_child(&"ViewSaver")
	_view_saver.view_saved.connect(_on_view_saved)
	top_gui.add_child(_view_save_popup)
	toggled.connect(_on_toggled)
	_view_save_popup.visibility_changed.connect(_on_visibility_changed)


func init(default_view_name := &"LABEL_CUSTOM1", group_name := &"", is_cached := true,
		show_flags := IVView.ALL, init_flags := IVView.ALL, reserved_names: Array[StringName]= []
		) -> void:
	# Called by IVViewCollection in standard setup.
	# Make 'group_name' unique to not share views with other GUI instances. 
	_view_saver.init(default_view_name, group_name, is_cached, show_flags, init_flags,
			reserved_names)


func get_view_save_popup() -> IVViewSavePopup:
	return _view_save_popup


func get_view_saver() -> IVViewSaver:
	return _view_saver


func _on_view_saved(view_name: String) -> void:
	_view_save_popup.hide()
	view_saved.emit(view_name)


func _on_toggled(toggle_pressed) -> void:
	if !_view_save_popup:
		return
	if toggle_pressed:
		_view_save_popup.popup()
		await get_tree().process_frame # popup may not know its correct size yet
		var popup_position := global_position - Vector2(_view_save_popup.size)
		popup_position.x += size.x / 2.0
		if popup_position.x < 0.0:
			popup_position.x = 0.0
		if popup_position.y < 0.0:
			popup_position.y = 0.0
		_view_save_popup.position = popup_position
	else:
		_view_save_popup.hide()


func _on_visibility_changed() -> void:
	await get_tree().process_frame
	if !_view_save_popup.visible:
		button_pressed = false

