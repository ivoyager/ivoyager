# sssbs_ckbxs.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2022 Charlie Whitfield
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
# GUI widget. Small Solar System Bodies. This one is hard-coded for our
# specific Solar System composition.
#
# Comets check box is present but hidden (until they are implemented). 

extends VBoxContainer

onready var _points_manager: IVPointsManager = IVGlobal.program.PointsManager
onready var _buttons := {
	all_asteroids = $HBox1/AllAsteroids,
	NE = $HBox2/NE,
	MC = $HBox3/MC,
	MB = $HBox2/MB,
	JT = $HBox3/JT, # this button controls both JT4 AND JT5 groups
	CE = $HBox2/CE,
	TN = $HBox3/TN,
}

func _ready() -> void:
	_points_manager.connect("show_points_changed", self, "_on_show_points_changed")
	for key in _buttons:
		var button: Button = _buttons[key]
		button.connect("pressed", self, "_on_pressed", [key, button])

func _on_pressed(group_or_category: String, button: Button) -> void:
	if group_or_category == "JT":
		_points_manager.show_points("JT4", button.pressed)
		_points_manager.show_points("JT5", button.pressed)
	else:
		_points_manager.show_points(group_or_category, button.pressed)

func _on_show_points_changed(group_or_category: String, is_show: bool) -> void:
	if group_or_category == "JT4" or group_or_category == "JT5":
		_buttons.JT.pressed = is_show
	else:
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
