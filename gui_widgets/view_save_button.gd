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

# GUI button widget that opens its own IVViewSavePopup.
#
# See IVViewCollection for widget containing this button and resultant saved
# view buttons.

signal view_saved(view_name)

var _view_save_popup: IVViewSavePopup
var _view_saver: IVViewSaver


func _ready() -> void:
	var top_gui: Control = IVGlobal.program.TopGUI
	_view_save_popup = IVFiles.make_object_or_scene(IVViewSavePopup)
	_view_saver = _view_save_popup.find_node("ViewSaver")
	_view_saver.connect("view_saved", self, "_on_view_saved")
	top_gui.add_child(_view_save_popup)
	connect("toggled", self, "_on_toggled")
	_view_save_popup.connect("visibility_changed", self, "_on_visibility_changed")


func init(default_view_name := "LABEL_CUSTOM1", set_name := "", is_cached := true,
		show_flags := IVView.ALL, init_flags := IVView.ALL, reserved_names := []) -> void:
	# Called by IVViewCollection in standard setup.
	# Make 'set_name' unique to not share views with other GUI instances. 
	_view_saver.init(default_view_name, set_name, is_cached, show_flags, init_flags, reserved_names)


func _on_view_saved(view_name: String) -> void:
	_view_save_popup.hide()
	emit_signal("view_saved", view_name)


func _on_toggled(is_pressed) -> void:
	if !_view_save_popup:
		return
	if is_pressed:
		_view_save_popup.popup()
		var position := rect_global_position + rect_size / 2.0 - _view_save_popup.rect_size
		if position.x < 0.0:
			position.x = 0.0
		if position.y < 0.0:
			position.y = 0.0
		_view_save_popup.rect_position = position
	else:
		_view_save_popup.hide()


func _on_visibility_changed() -> void:
	yield(get_tree(), "idle_frame")
	if !_view_save_popup.visible:
		pressed = false


