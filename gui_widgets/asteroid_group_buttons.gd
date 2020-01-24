# asteroid_group_buttons.gd
# This file is part of I, Voyager
# https://ivoyager.dev
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
# TODO: make this fully procedural from asteroid_group_data.csv. It needs to
# have settable horizontal size so it can be matched to SystemNavigator.

extends HBoxContainer

var _points_manager: PointsManager
var _asteroid_buttons := {}

func _ready() -> void:
	_points_manager = Global.objects.PointsManager
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
