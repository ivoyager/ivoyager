# orbits_names_symbols_ckbxs.gd
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
extends HBoxContainer

# GUI widget. 

onready var _huds_manager: IVHUDsManager = IVGlobal.program.HUDsManager
onready var _orbits_button: CheckBox = $Orbits
onready var _names_button: CheckBox = $Names
onready var _symbols_button: CheckBox = $Symbols


func _ready() -> void:
	_orbits_button.connect("pressed", self, "_show_hide_orbits")
	_names_button.connect("pressed", self, "_show_hide_names")
	_symbols_button.connect("pressed", self, "_show_hide_symbols")
	_huds_manager.connect("visibility_changed", self, "_update_ckbxs")


func _show_hide_orbits() -> void:
	_huds_manager.set_all_orbits_visibility(_orbits_button.pressed)


func _show_hide_names() -> void:
	_huds_manager.set_all_names_visibility(_names_button.pressed)


func _show_hide_symbols() -> void:
	_huds_manager.set_all_symbols_visibility(_symbols_button.pressed)


func _update_ckbxs() -> void:
	_orbits_button.pressed = _huds_manager.is_all_orbits_visible()
	_names_button.pressed = _huds_manager.is_all_names_visible()
	_symbols_button.pressed = _huds_manager.is_all_symbols_visible()
