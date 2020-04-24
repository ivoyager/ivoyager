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

extends VBoxContainer

var left_truncate := 45
var bottom_margin := 10

onready var mouse_trigger: Control = self
onready var mouse_visible: Array
onready var lock_mechanism := [$LockBox/LockLabel, $LockBox/LockCkBx]
onready var all_gui := [self]

var _settings: Dictionary = Global.settings
onready var _settings_manager: SettingsManager = Global.program.SettingsManager

func _ready() -> void:
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator", [],
			CONNECT_ONESHOT)
	$LockBox/LockCkBx.pressed = _settings.lock_navigator
	mouse_visible = lock_mechanism if _settings.lock_navigator else all_gui
	$LockBox/LockCkBx.connect("toggled", self, "_on_lock_toggled")
	$SystemNavigator.horizontal_expansion = 590.0
	hide()

func _on_about_to_start_simulator(_is_new_game: bool) -> void:
	set_anchors_and_margins_preset(PRESET_BOTTOM_LEFT, PRESET_MODE_MINSIZE)
	rect_position.x -= left_truncate
	rect_position.y -= bottom_margin
	$LockBox/Spacer.rect_min_size.x = left_truncate
	show()

func _on_lock_toggled(pressed: bool) -> void:
	mouse_visible = lock_mechanism if pressed else all_gui
	_settings_manager.change_current("lock_navigator", pressed)
