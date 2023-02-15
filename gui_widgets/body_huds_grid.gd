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
#
# The widget can be modified by settings public vars below before the _ready()
# virtual call. To do so, the parent control can connect to 'child_entered_tree'
# signal in its _enter_tree() method.
#
# See widget IVAllHUDsGrids for setting up multiple grids and aligning their
# columns.

const BodyFlags: Dictionary = IVEnums.BodyFlags

var has_headers := true
var column0_en_width := 20 # 'EN QUAD' padding; applied only if above is true

var ckbx_rows := [
	["LABEL_PLANETARY_MASS_OBJECTS", 0], # 0 causes all flags below to be set
	["   " + tr("LABEL_PLANETS"), BodyFlags.IS_TRUE_PLANET],
	["   " + tr("LABEL_DWARF_PLANETS"), BodyFlags.IS_DWARF_PLANET],
	["   " + tr("LABEL_MOONS"), BodyFlags.IS_PLANETARY_MASS_MOON],
]

var skip_ckbx_indexes := [] # child indexes; allow for column headers


var _headers := ["LABEL_NAMES", "LABEL_SYMBOLS", "LABEL_ORBITS"]
var _all_flags := 0 # auto-generated
var _names_ckbxs := []
var _symbols_ckbxs := []
var _orbits_ckbxs := []

onready var _huds_visibility: IVHUDsVisibility = IVGlobal.program.HUDsVisibility
onready var _n_rows := ckbx_rows.size()


func _ready() -> void:
	_huds_visibility.connect("body_huds_visibility_changed", self, "_update_ckbxs")
	
	if has_headers:
		var spacer := Label.new()
		var spacer_text := ""
		for i in column0_en_width:
			spacer_text += "\u2000" # EN QUAD
		spacer.text = spacer_text
		add_child(spacer)
		for header_text in _headers:
			var header := Label.new()
			header.align = Label.ALIGN_CENTER
			header.text = header_text
			add_child(header)
	else:
		# This is needed because ckbx.grow_horizontal = GROW_DIRECTION_BOTH
		# doesn't work in the top row if rect_min_size.x is set as of Godot
		# 3.5.2.rc2. Is this a Godot bug?
		# Spacers here can have their rect_min_size.x set to set column widths.
		for i in 4:
			add_child(Control.new())
	
	for i in _n_rows:
		var flags: int = ckbx_rows[i][1]
		_all_flags |= flags
	
	for i in _n_rows:
		var label_text: String = ckbx_rows[i][0]
		var flags: int = ckbx_rows[i][1]
		if !flags:
			ckbx_rows[i][1] = _all_flags
			flags = _all_flags
			
		var label := Label.new()
		label.text = label_text
		add_child(label)
	
		if !skip_ckbx_indexes.has(get_child_count()):
			var ckbx := CheckBox.new()
			ckbx.connect("pressed", self, "_show_hide_names", [ckbx, flags])
			ckbx.size_flags_horizontal = SIZE_SHRINK_CENTER
			_names_ckbxs.append(ckbx)
			add_child(ckbx)
		else:
			_names_ckbxs.append(null)
			add_child(Control.new())
			
		if !skip_ckbx_indexes.has(get_child_count()):
			var ckbx := CheckBox.new()
			ckbx.connect("pressed", self, "_show_hide_symbols", [ckbx, flags])
			ckbx.size_flags_horizontal = SIZE_SHRINK_CENTER
			_symbols_ckbxs.append(ckbx)
			add_child(ckbx)
		else:
			_symbols_ckbxs.append(null)
			add_child(Control.new())
		
		if !skip_ckbx_indexes.has(get_child_count()):
			var ckbx := CheckBox.new()
			ckbx.connect("pressed", self, "_show_hide_orbits", [ckbx, flags])
			ckbx.size_flags_horizontal = SIZE_SHRINK_CENTER
			_orbits_ckbxs.append(ckbx)
			add_child(ckbx)
		else:
			_orbits_ckbxs.append(null)
			add_child(Control.new())


func _show_hide_names(ckbx: CheckBox, flags: int) -> void:
	_huds_visibility.set_name_visibility(flags, ckbx.pressed)


func _show_hide_symbols(ckbx: CheckBox, flags: int) -> void:
	_huds_visibility.set_symbol_visibility(flags, ckbx.pressed)


func _show_hide_orbits(ckbx: CheckBox, flags: int) -> void:
	_huds_visibility.set_orbit_visibility(flags, ckbx.pressed)


func _update_ckbxs() -> void:
	for i in _n_rows:
		var flags: int = ckbx_rows[i][1]
		if _names_ckbxs[i] is CheckBox:
			_names_ckbxs[i].pressed = _huds_visibility.is_name_visible(flags, true)
		if _symbols_ckbxs[i] is CheckBox:
			_symbols_ckbxs[i].pressed = _huds_visibility.is_symbol_visible(flags, true)
		if _orbits_ckbxs[i] is CheckBox:
			_orbits_ckbxs[i].pressed = _huds_visibility.is_orbit_visible(flags, true)

