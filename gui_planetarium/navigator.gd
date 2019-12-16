# navigator.gd
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

const NAV_OFFSET := Vector2(-30.0, -10.0)
onready var _system_navigator: HBoxContainer = $SystemNavigator
onready var _viewport := get_viewport()

func _ready() -> void:
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator")
	_system_navigator.rect_min_size = Vector2(0.0, 185.0)
	_system_navigator.rect_position += NAV_OFFSET
	_system_navigator.size_proportions_exponent = 0.5
	_system_navigator.horizontal_expansion = 550.0
	_system_navigator.min_width = 10.0

func _on_about_to_start_simulator(_is_new_game: bool) -> void:
	get_parent().register_mouse_trigger_guis(self, [self])
	set_anchors_and_margins_preset(PRESET_BOTTOM_LEFT, PRESET_MODE_MINSIZE)
