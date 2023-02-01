# sssbs_ckbxs.gd
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
class_name IVSSSBsCkbxs
extends VBoxContainer

# GUI widget. Small Solar System Bodies.
#
# Comets check box is present but hidden (until they are implemented). 


onready var chkbxs := [
	[$HBox1/AllAsteroids, ["NE", "MC", "MB", "JT4", "JT5", "CE", "TN"]],
	[$HBox2/NE, ["NE"]],
	[$HBox3/MC, ["MC"]],
	[$HBox2/MB, ["MB"]],
	[$HBox3/JT, ["JT4", "JT5"]],
	[$HBox2/CE, ["CE"]],
	[$HBox3/TN, ["TN"]],
]

onready var _huds_visibility: IVHUDsVisibility = IVGlobal.program.HUDsVisibility


func _ready() -> void:
	_huds_visibility.connect("point_groups_visibility_changed", self, "_update_ckbxs")
	for i in chkbxs.size():
		var chkbx: CheckBox = chkbxs[i][0]
		var groups: Array = chkbxs[i][1]
		chkbx.connect("pressed", self, "_show_hide_points", [chkbx, groups])


func _show_hide_points(ckbx: CheckBox, groups: Array) -> void:
	var pressed := ckbx.pressed
	for group in groups:
		_huds_visibility.change_point_group_visibility(group, pressed)


func _update_ckbxs() -> void:
	for i in chkbxs.size():
		var chkbx: CheckBox = chkbxs[i][0]
		var groups: Array = chkbxs[i][1]
		var is_visible := true
		for group in groups:
			if !_huds_visibility.is_point_group_visible(group):
				is_visible = false
				break
		chkbx.pressed = is_visible

