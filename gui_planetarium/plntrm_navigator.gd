# plntrm_navigator.gd
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

extends Control

func _ready() -> void:
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator", [], CONNECT_ONESHOT)
	get_parent().register_mouse_trigger_guis($SystemNavigator, [self])
	$SystemNavigator.horizontal_expansion = 590.0
	hide()

func _on_about_to_start_simulator(_is_new_game: bool) -> void:
	$SystemNavigator.set_anchors_and_margins_preset(PRESET_BOTTOM_LEFT, PRESET_MODE_MINSIZE)
	$SystemNavigator.rect_position.x -= 54
	$SystemNavigator.rect_position.y -= 20
	show()
