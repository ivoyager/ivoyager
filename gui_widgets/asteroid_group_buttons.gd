# asteroid_group_buttons.gd
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
# GUI widget. Unlike almost all other GUI, this one is hard-coded for the
# solar system composition. It would be really hard to do otherwise.

extends HBoxContainer

var horizontal_sizes := [420.0, 560.0, 700.0]
var vertical_sizes := [30.0, 40.0, 50.0]
# spacing are min sizes for buttons & spacers; adjusted to sum to horizontal_size
var spacing := [2.0, 80.0, 2.0, 50.0, 0.0, 40.0, 0.0, 40.0, 0.0, 60.0, 30.0, 70.0, 30.0, 80.0]

var _points_manager: PointsManager
var _asteroid_buttons := {}
var _spacing_controls: Array

func _ready() -> void:
	Global.connect("system_tree_ready", self, "_on_system_tree_ready")
#	Global.connect("about_to_free_procedural_nodes", self, "_clear")
	Global.connect("setting_changed", self, "_settings_listener")
	_points_manager = Global.program.PointsManager
	_asteroid_buttons.all_asteroids = $AllAsteroids
	_asteroid_buttons.NE = $NearEarth
	_asteroid_buttons.MC = $MarsCros
	_asteroid_buttons.MB = $MainBelt
	_asteroid_buttons.JT4 = $Trojans/L4
	_asteroid_buttons.JT5 = $Trojans/L5
	_asteroid_buttons.CE = $Centaurs
	_asteroid_buttons.TN = $TransNeptune
	for key in _asteroid_buttons:
		var button: Button = _asteroid_buttons[key]
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.connect("pressed", self, "_on_pressed", [key, button])
	_points_manager.connect("show_points_changed", self, "_on_show_points_changed")
	_spacing_controls = [
		$Spacer1,
		$AllAsteroids,
		$Spacer2,
		$NearEarth,
		$Spacer3,
		$MarsCros,
		$Spacer4,
		$MainBelt,
		$Spacer5,
		$Trojans,
		$Spacer6,
		$Centaurs,
		$Spacer7,
		$TransNeptune,
	]

func _on_system_tree_ready(_is_loaded_game: bool) -> void:
	var gui_size: int = Global.settings.gui_size
	_resize(gui_size)

func _settings_listener(setting: String, value) -> void:
	match setting:
		"gui_size":
			if Global.state.is_system_built:
				_resize(value)

func _resize(gui_size: int) -> void:
	rect_min_size.y = vertical_sizes[gui_size]
	var spacing_sum := 0.0
	for x_size in spacing:
		spacing_sum += x_size
	var scale: float = horizontal_sizes[gui_size] / spacing_sum
	for i in range(_spacing_controls.size()):
		var spacing_control: Control = _spacing_controls[i]
		var min_x: float = round(spacing[i] * scale)
		spacing_control.rect_min_size.x = min_x

func _on_pressed(group_or_category: String, button: Button) -> void:
	_points_manager.show_points(group_or_category, button.pressed)

func _on_show_points_changed(group_or_category: String, is_show: bool) -> void:
	_asteroid_buttons[group_or_category].pressed = is_show
	if group_or_category == "all_asteroids":
		return
	if !is_show:
		_asteroid_buttons.all_asteroids.pressed = false
	else:
		for key in _asteroid_buttons:
			if key != "all_asteroids" and !_asteroid_buttons[key].pressed:
				_asteroid_buttons.all_asteroids.pressed = false
				return
		_asteroid_buttons.all_asteroids.pressed = true
