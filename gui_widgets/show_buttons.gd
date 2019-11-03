# show_buttons.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2019 Charlie Whitfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# *****************************************************************************
#
# UI widget.

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



