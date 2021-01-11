# asteroid_group_buttons.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
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
# GUI widget. Unlike almost all other GUI, this one is hard-coded for our
# specific Solar System composition. TODO: Make this "procedural" from new
# data columns in asteroid_groups.csv (this will be needed if anyone develops
# a procedural generator for alien star/planetary systems).
#
# TODO 4.0: Remove button/label hack for multiline button text (if Godot #2967
# fixed).

extends HBoxContainer

onready var _points_manager: PointsManager = Global.program.PointsManager
onready var _buttons := {
	all_asteroids = $AllAsteroids,
	NE = $NearEarth,
	MC = $MarsCros,
	MB = $MainBelt,
	JT4 = $Trojans/L4,
	JT5 = $Trojans/L5,
	CE = $Centaurs,
	TN = $TransNeptune,
}

func _ready() -> void:
	_points_manager.connect("show_points_changed", self, "_on_show_points_changed")
	for key in _buttons:
		var button: Button = _buttons[key]
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.connect("pressed", self, "_on_pressed", [key, button])

func _on_pressed(group_or_category: String, button: Button) -> void:
	_points_manager.show_points(group_or_category, button.pressed)

func _on_show_points_changed(group_or_category: String, is_show: bool) -> void:
	_buttons[group_or_category].pressed = is_show
	if group_or_category == "all_asteroids":
		return
	if !is_show:
		_buttons.all_asteroids.pressed = false
	else:
		for key in _buttons:
			if key != "all_asteroids" and !_buttons[key].pressed:
				_buttons.all_asteroids.pressed = false
				return
		_buttons.all_asteroids.pressed = true
