# gui_navigation.gd
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

extends VBoxContainer

onready var _tree_manager: TreeManager = Global.objects.TreeManager
onready var _points_manager: PointsManager = Global.objects.PointsManager
onready var _hypertext: RichTextLabel = $Hypertext
onready var _asteroids_checkbox: CheckBox = $Asteroids/CheckBox
onready var _orbits_checkbox: CheckBox = $Orbits/CheckBox
onready var _labels_checkbox: CheckBox = $Labels/CheckBox
onready var _icons_checkbox: CheckBox = $Icons/CheckBox
onready var _viewport := get_viewport()
var _is_mouse_button_pressed := false

func _ready() -> void:
	_hypertext.connect("meta_clicked", self, "_on_meta_clicked")
	_asteroids_checkbox.connect("toggled", self, "_toggle_asteroids")
	_orbits_checkbox.connect("toggled", _tree_manager, "set_show_orbits")
	_labels_checkbox.connect("toggled", _tree_manager, "set_show_labels")
	_icons_checkbox.connect("toggled", _tree_manager, "set_show_icons")
	_tree_manager.connect("show_orbits_changed", self, "_update_show_orbits")
	_tree_manager.connect("show_labels_changed", self, "_update_show_labels")
	_tree_manager.connect("show_icons_changed", self, "_update_show_icons")
	set_anchors_and_margins_preset(PRESET_BOTTOM_RIGHT, PRESET_MODE_MINSIZE)
	margin_right = -10
	margin_bottom = -10
	hide()

func _on_meta_clicked(meta: String) -> void:
	if meta == "Options":
		Global.emit_signal("options_requested")
	elif meta == "Hotkeys":
		Global.emit_signal("hotkeys_requested")

func _toggle_asteroids(pressed: bool) -> void:
	_points_manager.show_points("all_asteroids", pressed)

func _update_show_orbits(is_show: bool) -> void:
	_orbits_checkbox.pressed = is_show

func _update_show_labels(is_show: bool) -> void:
	_labels_checkbox.pressed = is_show

func _update_show_icons(is_show: bool) -> void:
	_icons_checkbox.pressed = is_show

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _is_mouse_button_pressed:
			return
		var mouse_pos := _viewport.get_mouse_position()
		var show_options := mouse_pos.x > rect_position.x and mouse_pos.y > rect_position.y
		if show_options != visible:
			visible = show_options
			mouse_filter = MOUSE_FILTER_PASS if show_options else MOUSE_FILTER_IGNORE
	elif event is InputEventMouseButton:
		_is_mouse_button_pressed = event.pressed
