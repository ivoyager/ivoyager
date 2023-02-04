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
class_name IVAsteroidsGrid
extends GridContainer

# GUI widget. Trojan orbits are currently not viewable so disabled.

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
var _orbits_chkbxs := []

var _suppress_update := false

onready var _huds_visibility: IVHUDsVisibility = IVGlobal.program.HUDsVisibility
onready var _n_rows := chkbx_rows.size()


func _ready() -> void:
	var spacer_text := ""
	for i in spacer_size:
		spacer_text += "\u2000" # EN QUAD
	$Spacer.text = spacer_text
	_huds_visibility.connect("sbg_points_visibility_changed", self, "_update_points_ckbxs")
	_huds_visibility.connect("sbg_orbits_visibility_changed", self, "_update_orbits_ckbxs")
	for i in _n_rows:
		var label_text: String = chkbx_rows[i][0]
		var groups: Array = chkbx_rows[i][1]
		var label := Label.new()
		label.text = label_text
		add_child(label)
		var points_chkbx := CheckBox.new()
		points_chkbx.connect("pressed", self, "_show_hide_points", [points_chkbx, groups])
		points_chkbx.align = Button.ALIGN_CENTER
		points_chkbx.size_flags_horizontal = SIZE_SHRINK_CENTER
		_points_chkbxs.append(points_chkbx)
		add_child(points_chkbx)
		if groups == ["JT4", "JT5"]:
			var spacer := Control.new()
			_orbits_chkbxs.append(null)
			add_child(spacer)
		else:
			var orbits_chkbx := CheckBox.new()
			orbits_chkbx.connect("pressed", self, "_show_hide_orbits", [orbits_chkbx, groups])
			orbits_chkbx.align = Button.ALIGN_CENTER
			orbits_chkbx.size_flags_horizontal = SIZE_SHRINK_CENTER
			_orbits_chkbxs.append(orbits_chkbx)
			add_child(orbits_chkbx)


func _show_hide_points(ckbx: CheckBox, groups: Array) -> void:
	_suppress_update = true
	var pressed := ckbx.pressed
	for group in groups:
		_huds_visibility.change_sbg_points_visibility(group, pressed)
	_suppress_update = false
	_update_points_ckbxs()


func _show_hide_orbits(ckbx: CheckBox, groups: Array) -> void:
	_suppress_update = true
	var pressed := ckbx.pressed
	for group in groups:
		if group == "JT4" or group == "JT5":
			continue
		_huds_visibility.change_sbg_orbits_visibility(group, pressed)
	_suppress_update = false
	_update_orbits_ckbxs()


func _update_points_ckbxs() -> void:
	if _suppress_update:
		return
	for i in _n_rows:
		var groups: Array = chkbx_rows[i][1]
		var is_points_visible := true
		for group in groups:
			if !_huds_visibility.is_sbg_points_visible(group):
				is_points_visible = false
				break
		_points_chkbxs[i].pressed = is_points_visible


func _update_orbits_ckbxs() -> void:
	if _suppress_update:
		return
	for i in _n_rows:
		var groups: Array = chkbx_rows[i][1]
		if groups == ["JT4", "JT5"]:
			continue
		var is_orbits_visible := true
		for group in groups:
			if group == "JT4" or group == "JT5":
				continue
			if !_huds_visibility.is_sbg_orbits_visible(group):
				is_orbits_visible = false
				break
		_orbits_chkbxs[i].pressed = is_orbits_visible


