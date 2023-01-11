# asteroids_grid.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2023 Charlie Whitfield
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
extends GridContainer

# GUI widget.

var spacer_size := 18

var chkbx_rows := [
	["LABEL_ALL_ASTEROIDS", ["NE", "MC", "MB", "JT4", "JT5", "CE", "TN"]],
	[" " + tr("LABEL_NEAR_EARTH"), ["NE"]],
	[" " + tr("LABEL_MARS_CROSSERS"), ["MC"]],
	[" " + tr("LABEL_MAIN_BELT"), ["MB"]],
	[" " + tr("LABEL_JUPITER_TROJANS"), ["JT4", "JT5"]],
	[" " + tr("LABEL_CENTAURS"), ["CE"]],
	[" " + tr("LABEL_TRANS_NEPTUNIAN"), ["TN"]],
]

var _points_chkbxs := []

onready var _points_manager: IVPointsManager = IVGlobal.program.PointsManager
onready var _n_rows := chkbx_rows.size()


func _ready() -> void:
	var spacer_text := ""
	for i in spacer_size:
		spacer_text += "\u2000" # EN QUAD
	$Spacer.text = spacer_text
	_points_manager.connect("visibility_changed", self, "_update_ckbxs")
	for i in _n_rows:
		var label_text: String = chkbx_rows[i][0]
		var groups: Array = chkbx_rows[i][1]
		var label := Label.new()
		label.text = label_text
		add_child(label)
		var chkbx := CheckBox.new()
		chkbx.connect("pressed", self, "_show_hide_points", [chkbx, groups])
		chkbx.align = Button.ALIGN_CENTER
		chkbx.size_flags_horizontal = SIZE_SHRINK_CENTER
		_points_chkbxs.append(chkbx)
		add_child(chkbx)


func _show_hide_points(ckbx: CheckBox, groups: Array) -> void:
	var pressed := ckbx.pressed
	for group in groups:
		_points_manager.show_points(group, pressed)


func _update_ckbxs() -> void:
	for i in _n_rows:
		var groups: Array = chkbx_rows[i][1]
		var is_visible := true
		for group in groups:
			if !_points_manager.is_visible(group):
				is_visible = false
				break
		_points_chkbxs[i].pressed = is_visible

