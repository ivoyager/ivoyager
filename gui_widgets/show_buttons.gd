# show_buttons.gd
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
# GUI widget.

extends VBoxContainer

onready var _tree_manager: TreeManager = Global.program.TreeManager
onready var _orbits_button: Button = $HBox/Orbits
onready var _symbols_button: Button = $HBox/Symbols
onready var _names_button: Button = $HBox/Names

func _ready() -> void:
	_orbits_button.connect("pressed", self, "_show_hide_orbits")
	_symbols_button.connect("pressed", self, "_show_hide_symbols")
	_names_button.connect("pressed", self, "_show_hide_names")
	_tree_manager.connect("show_orbits_changed", self, "_update_show_orbits")
	_tree_manager.connect("show_symbols_changed", self, "_update_show_symbols")
	_tree_manager.connect("show_names_changed", self, "_update_show_names")

func _show_hide_orbits() -> void:
	_tree_manager.set_show_orbits(_orbits_button.pressed)

func _show_hide_names() -> void:
	_tree_manager.set_show_names(_names_button.pressed)

func _show_hide_symbols() -> void:
	_tree_manager.set_show_symbols(_symbols_button.pressed)

func _update_show_orbits(is_show: bool) -> void:
	_orbits_button.pressed = is_show

func _update_show_symbols(is_show: bool) -> void:
	_symbols_button.pressed = is_show

func _update_show_names(is_show: bool) -> void:
	_names_button.pressed = is_show
