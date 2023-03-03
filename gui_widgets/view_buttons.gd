# view_buttons.gd
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
class_name IVViewButtons
extends HBoxContainer

# GUI button widget for 'default' views created by IVViewDefaults. Buttons can
# be pre-added to this conainer in scene construction (name must be a valid key
# in IVViewDefaults.views) or can be added later by calling add_button().


var _view_defaults: IVViewDefaults = IVGlobal.program.ViewDefaults


func _ready() -> void:
	for child in get_children():
		_connect_button(child)


func add_button(view_name: String, button_text: String) -> void:
	var button := Button.new()
	button.name = view_name
	button.text = button_text
	_connect_button(button)
	add_child(button)


func _connect_button(button: Button) -> void:
	if !_view_defaults.has_view(button.name):
		return
	button.connect("pressed", _view_defaults, "set_view", [button.name])
