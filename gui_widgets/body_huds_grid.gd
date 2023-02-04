# body_huds_grid.gd
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
class_name IVBodyHUDsGrid
extends GridContainer

# GUI widget. 

const BodyFlags: Dictionary = IVEnums.BodyFlags
const IS_STAR_OR_TRUE_PLANET := BodyFlags.IS_STAR | BodyFlags.IS_TRUE_PLANET
const IS_DWARF_PLANET := BodyFlags.IS_DWARF_PLANET
const IS_MOON := BodyFlags.IS_MOON
const IS_ASTEROID := BodyFlags.IS_ASTEROID
const IS_SPACECRAFT := BodyFlags.IS_SPACECRAFT


var spacer_size := 18

var all_visible_flags: int = (BodyFlags.IS_STAR | BodyFlags.IS_TRUE_PLANET
		| BodyFlags.IS_DWARF_PLANET | BodyFlags.IS_MOON | BodyFlags.IS_ASTEROID
		| BodyFlags.IS_SPACECRAFT)

var chkbx_rows := [
	["LABEL_ALL", all_visible_flags],
	[" " + tr("LABEL_SUN_AND_PLANETS"), BodyFlags.IS_STAR | BodyFlags.IS_TRUE_PLANET],
	[" " + tr("LABEL_DWARF_PLANETS"), BodyFlags.IS_DWARF_PLANET],
	[" " + tr("LABEL_MOONS"), BodyFlags.IS_MOON],
	[" " + tr("LABEL_ASTEROIDS_VISITED"), BodyFlags.IS_ASTEROID],
	[" " + tr("LABEL_SPACECRAFT"), BodyFlags.IS_SPACECRAFT],
]

var _names_chkbxs := []
var _symbols_chkbxs := []
var _orbits_chkbxs := []


onready var _huds_visibility: IVHUDsVisibility = IVGlobal.program.HUDsVisibility
onready var _n_rows := chkbx_rows.size()


func _ready() -> void:
	var spacer_text := ""
	for i in spacer_size:
		spacer_text += "\u2000" # EN QUAD
	$Spacer.text = spacer_text
	_huds_visibility.connect("body_huds_visibility_changed", self, "_update_ckbxs")
	for i in _n_rows:
		var label_text: String = chkbx_rows[i][0]
		var flags: int = chkbx_rows[i][1]
		var label := Label.new()
		label.text = label_text
		add_child(label)
		var chkbx := CheckBox.new()
		chkbx.connect("pressed", self, "_show_hide_names", [chkbx, flags])
		chkbx.align = Button.ALIGN_CENTER
		chkbx.size_flags_horizontal = SIZE_SHRINK_CENTER
		_names_chkbxs.append(chkbx)
		add_child(chkbx)
		chkbx = CheckBox.new()
		chkbx.connect("pressed", self, "_show_hide_symbols", [chkbx, flags])
		chkbx.align = Button.ALIGN_CENTER
		chkbx.size_flags_horizontal = SIZE_SHRINK_CENTER
		_symbols_chkbxs.append(chkbx)
		add_child(chkbx)
		chkbx = CheckBox.new()
		chkbx.connect("pressed", self, "_show_hide_orbits", [chkbx, flags])
		chkbx.align = Button.ALIGN_CENTER
		chkbx.size_flags_horizontal = SIZE_SHRINK_CENTER
		_orbits_chkbxs.append(chkbx)
		add_child(chkbx)


func _show_hide_names(ckbx: CheckBox, flags: int) -> void:
	_huds_visibility.set_name_visibility(flags, ckbx.pressed)


func _show_hide_symbols(ckbx: CheckBox, flags: int) -> void:
	_huds_visibility.set_symbol_visibility(flags, ckbx.pressed)


func _show_hide_orbits(ckbx: CheckBox, flags: int) -> void:
	_huds_visibility.set_orbit_visibility(flags, ckbx.pressed)


func _update_ckbxs() -> void:
	for i in _n_rows:
		var flags: int = chkbx_rows[i][1]
		_names_chkbxs[i].pressed = _huds_visibility.is_name_visible(flags, true)
		_symbols_chkbxs[i].pressed = _huds_visibility.is_symbol_visible(flags, true)
		_orbits_chkbxs[i].pressed = _huds_visibility.is_orbit_visible(flags, true)

