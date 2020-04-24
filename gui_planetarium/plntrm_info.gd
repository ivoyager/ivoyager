# plntrm_info.gd
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

var col1_width := 180
var col2_width := 150

onready var mouse_trigger: Control = self
onready var mouse_visible := [$Scroll/VBox/Locks1, $Scroll/VBox/Locks2, $Scroll/VBox/Locks3,
	$Scroll/VBox/Wikipedia]

onready var time_items := [$TimeBox/DateTime]
onready var selection_items := [$SelectionBox/SelectionLabel]
onready var range_items := [$RangeLabel]
onready var info_items := [$Scroll/VBox/SelectionData]
onready var control_items := [$TimeBox/TimeControl, $SelectionBox/ViewButtons]

var _settings: Dictionary = Global.settings
onready var _settings_manager: SettingsManager = Global.program.SettingsManager

func _ready():
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator", [],
			CONNECT_ONESHOT)
	var time_control: Control = $TimeBox/TimeControl
	time_control.include_game_speed_label = false
	time_control.include_pause_button = false
	var view_buttons: Control = $SelectionBox/ViewButtons
	view_buttons.use_small_txt = true
	view_buttons.include_recenter = true
	$Scroll/VBox/SelectionData.labels_width = col1_width
	$Scroll/VBox/SelectionData.values_width = col2_width
	if !Global.enable_wiki:
		$Scroll/VBox/Wikipedia.queue_free()
	# visibility control
	$Scroll/VBox/Locks1/LkTimeCkBx.pressed = _settings.lock_time
	$Scroll/VBox/Locks1/LkSelectionCkBx.pressed = _settings.lock_selection
	$Scroll/VBox/Locks2/LkRangeCkBx.pressed = _settings.lock_range
	$Scroll/VBox/Locks2/LkInfoCkBx.pressed = _settings.lock_info
	$Scroll/VBox/Locks3/LkControlsCkBx.pressed = _settings.lock_controls
	_lock_toggled(_settings.lock_time, time_items)
	_lock_toggled(_settings.lock_selection, selection_items)
	_lock_toggled(_settings.lock_range, range_items)
	_lock_toggled(_settings.lock_info, info_items)
	_lock_toggled(_settings.lock_controls, control_items)
	$Scroll/VBox/Locks1/LkTimeCkBx.connect("toggled", self, "_lock_toggled",
			[time_items, "lock_time"])
	$Scroll/VBox/Locks1/LkSelectionCkBx.connect("toggled", self, "_lock_toggled",
			[selection_items, "lock_selection"])
	$Scroll/VBox/Locks2/LkRangeCkBx.connect("toggled", self, "_lock_toggled",
			[range_items, "lock_range"])
	$Scroll/VBox/Locks2/LkInfoCkBx.connect("toggled", self, "_lock_toggled",
			[info_items, "lock_info"])
	$Scroll/VBox/Locks3/LkControlsCkBx.connect("toggled", self, "_lock_toggled",
			[control_items, "lock_controls"])

func _on_about_to_start_simulator(_is_new_game: bool) -> void:
	# These are hidden during build but shown at start (until user moves mouse)
	$TimeBox/TimeControl.show()
	$SelectionBox/ViewButtons.show()
	$Scroll/VBox/Wikipedia.show()
	$Scroll/VBox/Locks1.show()
	$Scroll/VBox/Locks2.show()
	$Scroll/VBox/Locks3.show()

func _lock_toggled(pressed: bool, guis: Array, setting_name := "") -> void:
	if pressed:
		for gui in guis:
			mouse_visible.erase(gui)
	else:
		for gui in guis:
			if !mouse_visible.has(gui):
				mouse_visible.append(gui)
	if setting_name:
		_settings_manager.change_current(setting_name, pressed)
