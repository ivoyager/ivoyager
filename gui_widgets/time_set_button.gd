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

# GUI button widget that opens IVTimeSetPopup.
#
# Important! IVTimeSetPopup must be added by project extension file to
# IVProjectBuilder.gui_nodes. Otherwise, it is not present and this button
# won't do anything.


var _time_set_popup: IVTimeSetPopup


func _ready() -> void:
	_time_set_popup = IVGlobal.program.get("TimeSetPopup")
	if !_time_set_popup:
		return
	connect("toggled", self, "_on_toggled")
	_time_set_popup.connect("visibility_changed", self, "_on_visibility_changed")


func _on_toggled(is_pressed) -> void:
	if !_time_set_popup:
		return
	if is_pressed:
		_time_set_popup.popup_centered()
	else:
		_time_set_popup.hide()


func _on_visibility_changed() -> void:
	yield(get_tree(), "idle_frame")
	if !_time_set_popup.visible:
		pressed = false


