# example_navigation_panel.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield
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
#
# THIS IS AN EXAMPLE GUI SCENE! It may change in the future. You should
# duplicate this scene or build your own GUI scenes outside of the ivoyager
# directory.
#
# A little code is needed here to allow some (but not too much) overlap between
# PlanetMoonButtons and SSSBsCkbxs if the panel is resized dynamically.
# UnderMoonsSpacer keeps the former from squishing into the bottom of the panel.

extends PanelContainer

var _settings: Dictionary = Global.settings
onready var _under_moons_spacer: Control = find_node("UnderMoonsSpacer")
var _under_moons_spacer_sizes := [55.0, 66.0, 77.0]

func _ready() -> void:
	# modify widgets here
	Global.connect("update_gui_needed", self, "_resize")
	Global.connect("setting_changed", self, "_settings_listener")

func _resize() -> void:
	var gui_size: int = _settings.gui_size
	_under_moons_spacer.rect_min_size.y = _under_moons_spacer_sizes[gui_size]

func _settings_listener(setting: String, _value) -> void:
	if setting == "gui_size":
		_resize()
