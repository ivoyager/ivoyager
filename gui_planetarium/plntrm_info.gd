# planetarium_gui.gd
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
var col2_width := 100

onready var mouse_trigger: Control = self
onready var mouse_visible := []

onready var time_items := [$TimeBox]
onready var selection_items := [$SelectionBox/SelectionLabel]
onready var range_items := [$RangeLabel]
onready var info_items := [$SelectionData]
onready var control_items := [$TimeBox/TimeControl, $SelectionBox/ViewButtons,
	$Wikipedia, $LocksBox1, $LocksBox2, $LocksBox3]

func _ready():
#	Global.connect("system_tree_ready", self, "_on_system_tree_ready")
	$TimeBox/TimeControl/GameSpeed.hide()
	$TimeBox/TimeControl/Pause.hide()
#	$SelectionBox/SelectionLabel.rect_min_size.x = col1_width
	$SelectionData.col1_width = col1_width
	$SelectionData.col2_width = col2_width
	# visibility control
	$LocksBox1/LkTimeCkBx.pressed = true
	$LocksBox1/LkSelectionCkBx.pressed = true
	$LocksBox2/LkRangeCkBx.pressed = true
	$LocksBox2/LkInfoCkBx.pressed = true
	$LocksBox1/LkTimeCkBx.connect("toggled", self, "_lock_toggled", [time_items])
	$LocksBox1/LkSelectionCkBx.connect("toggled", self, "_lock_toggled", [selection_items])
	$LocksBox2/LkRangeCkBx.connect("toggled", self, "_lock_toggled", [range_items])
	$LocksBox2/LkInfoCkBx.connect("toggled", self, "_lock_toggled", [info_items])
	$LocksBox3/LkControlsCkBx.connect("toggled", self, "_lock_toggled", [control_items])
	_lock_toggled(false, control_items)

func _lock_toggled(pressed: bool, guis: Array) -> void:
	if pressed:
		for gui in guis:
			mouse_visible.erase(gui)
	else:
		for gui in guis:
			if !mouse_visible.has(gui):
				mouse_visible.append(gui)

