# show_buttons.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2019 Charlie Whitfield
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
class_name ShowButtons

onready var _tree_manager: TreeManager = Global.objects.TreeManager
onready var _orbits_button: Button = $HBox1/Orbits
onready var _icons_button: Button = $HBox1/Icons
onready var _labels_button: Button = $HBox1/Labels
onready var _minor_moons_button: Button = $HBox2/MinorMoons
onready var _asteroids_button: Button = $HBox2/Asteroids
onready var _comets_button: Button = $HBox2/Comets

func _ready() -> void:
	_orbits_button.connect("toggled", _tree_manager, "set_show_orbits")
	_icons_button.connect("toggled", _tree_manager, "set_show_icons")
	_labels_button.connect("toggled", _tree_manager, "set_show_labels")
	_tree_manager.connect("show_orbits_changed", self, "_update_show_orbits")
	_tree_manager.connect("show_icons_changed", self, "_update_show_icons")
	_tree_manager.connect("show_labels_changed", self, "_update_show_labels")
	_orbits_button.text = "LABEL_ORBITS"
	_icons_button.text = "LABEL_ICONS"
	_labels_button.text = "LABEL_LABELS"
	_minor_moons_button.text = "LABEL_MINOR_MOONS"
	_asteroids_button.text = "LABEL_ASTEROIDS"
	_comets_button.text = "LABEL_COMETS"

func _update_show_orbits(is_show: bool) -> void:
	_orbits_button.pressed = is_show
	
func _update_show_icons(is_show: bool) -> void:
	_icons_button.pressed = is_show
	
func _update_show_labels(is_show: bool) -> void:
	_labels_button.pressed = is_show



