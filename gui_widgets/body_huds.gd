# body_huds.gd
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
class_name IVBodyHUDs
extends GridContainer

# GUI widget.
#
# Class properties must be set before _ready(). See widget IVAllHUDs for complex
# row construction, setting up multiple grids, and aligning their columns.
#
# To display correctly, ColorPickerButton needs a StyleBoxTexture with no
# margins.
#
# IMPORTANT! For correct visibility control, BodyFlags used in rows must be a
# subset of IVBodyHUDsState.all_flags.

const NULL_COLOR := Color.black
const BodyFlags: Dictionary = IVEnums.BodyFlags

var has_headers := true
var column_master: Control # if set, column widths follow master children
var column0_en_width := 0 # 'EN QUAD' size if column_master == null
var columns_en_width := 0 # as above for data columns

var rows := [
	["LABEL_PLANETARY_MASS_OBJECTS", 0], # 0 replaced by all flags from following rows
	["   " + tr("LABEL_PLANETS"), BodyFlags.IS_TRUE_PLANET],
	["   " + tr("LABEL_DWARF_PLANETS"), BodyFlags.IS_DWARF_PLANET],
	["   " + tr("LABEL_MOONS"), BodyFlags.IS_PLANETARY_MASS_MOON],
]

var disable_orbits_rows := [] # e.g., no orbit for Sun

var headers := ["LABEL_NAMES_SLASH_SYMBOLS_SHORT", "LABEL_ORBITS"]
var header_hints := ["HINT_NAMES_SYMBOLS_CKBXS", "HINT_ORBITS_CKBX_COLOR"]


var _all_flags := 0 # generated from all rows
var _names_ckbxs := []
var _symbols_ckbxs := []
var _orbits_ckbxs := []
var _orbits_color_pkrs := []

onready var _body_huds_state: IVBodyHUDsState = IVGlobal.program.BodyHUDsState
onready var _n_rows := rows.size()


func _ready() -> void:
	IVGlobal.connect("setting_changed", self, "_settings_listener")
	IVGlobal.connect("update_gui_requested", self, "_update_orbit_color_buttons")
	_body_huds_state.connect("visibility_changed", self, "_update_ckbxs")
	_body_huds_state.connect("color_changed", self, "_update_orbit_color_buttons")

	# headers
	if has_headers:
		add_child(Control.new())
		for i in 2:
			var header := Label.new()
			header.align = Label.ALIGN_CENTER
			header.text = headers[i]
			header.hint_tooltip = header_hints[i]
			header.mouse_filter = Control.MOUSE_FILTER_PASS
			add_child(header)
	
	# set '_all_flags' from all rows
	for i in _n_rows:
		var flags: int = rows[i][1]
		_all_flags |= flags
	
	# grid content
	for i in _n_rows:
		var flags: int = rows[i][1]
		if !flags:
			rows[i][1] = _all_flags
			flags = _all_flags
		
		# row label
		var label_text: String = rows[i][0]
		var label := Label.new()
		label.text = label_text
		add_child(label)
		
		# names/symbols
		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGN_CENTER
		add_child(hbox)
		var ckbx := _make_checkbox()
		ckbx.connect("pressed", self, "_show_hide_names", [ckbx, flags])
		_names_ckbxs.append(ckbx)
		hbox.add_child(ckbx)
		ckbx = _make_checkbox()
		ckbx.connect("pressed", self, "_show_hide_symbols", [ckbx, flags])
		_symbols_ckbxs.append(ckbx)
		hbox.add_child(ckbx)
		
		# orbits
		if disable_orbits_rows.has(i):
			var spacer := Control.new()
			spacer.size_flags_horizontal = SIZE_SHRINK_CENTER
			add_child(spacer)
			_orbits_ckbxs.append(null)
			_orbits_color_pkrs.append(null)
		else:
			hbox = HBoxContainer.new()
			hbox.alignment = BoxContainer.ALIGN_CENTER
			add_child(hbox)
			ckbx = _make_checkbox()
			ckbx.connect("pressed", self, "_show_hide_orbits", [ckbx, flags])
			_orbits_ckbxs.append(ckbx)
			hbox.add_child(ckbx)
			var orbit_default_color: Color = _body_huds_state.get_default_orbit_color(flags)
			var color_button := _make_color_picker_button(orbit_default_color)
			color_button.connect("color_changed", self, "_change_orbit_color", [flags])
			_orbits_color_pkrs.append(color_button)
			hbox.add_child(color_button)
	
	# column sizing
	if IVGlobal.state.is_started_or_about_to_start:
		_resize_columns()
	else:
		IVGlobal.connect("about_to_start_simulator", self, "_resize_columns", [], CONNECT_ONESHOT)


func _make_checkbox() -> CheckBox:
	var ckbx := CheckBox.new()
	ckbx.align = Button.ALIGN_CENTER
	ckbx.size_flags_horizontal = SIZE_SHRINK_CENTER
	return ckbx


func _make_color_picker_button(default_color: Color) -> ColorPickerButton:
	var button := ColorPickerButton.new()
	button.connect("toggled", self, "_hack_fix_toggle_off", [button])
	button.rect_min_size.x = 15
	button.rect_min_size.y = 15
	button.size_flags_vertical = SIZE_SHRINK_CENTER
	button.set("custom_fonts/font", IVGlobal.fonts.two_pt) # allow short button hack
	button.edit_alpha = false
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	var color_picker := button.get_picker()
	color_picker.add_preset(default_color)
	# Note: As of Godot 3.5.2, a ColorPicker that never gets any add_preset()
	# shows all presets set in all ColorPickers (even redundant ones). 
	return button


func _show_hide_names(ckbx: CheckBox, flags: int) -> void:
	_body_huds_state.set_name_visibility(flags, ckbx.pressed)


func _show_hide_symbols(ckbx: CheckBox, flags: int) -> void:
	_body_huds_state.set_symbol_visibility(flags, ckbx.pressed)


func _show_hide_orbits(ckbx: CheckBox, flags: int) -> void:
	_body_huds_state.set_orbit_visibility(flags, ckbx.pressed)


func _update_ckbxs() -> void:
	for i in _n_rows:
		var flags: int = rows[i][1]
		_names_ckbxs[i].pressed = _body_huds_state.is_name_visible(flags, true)
		_symbols_ckbxs[i].pressed = _body_huds_state.is_symbol_visible(flags, true)
		if _orbits_ckbxs[i]:
			_orbits_ckbxs[i].pressed = _body_huds_state.is_orbit_visible(flags, true)


func _change_orbit_color(color: Color, flags: int) -> void:
	if color == NULL_COLOR:
		return
	_body_huds_state.set_orbit_color(flags, color)


func _update_orbit_color_buttons() -> void:
	for i in _n_rows:
		if !_orbits_color_pkrs[i]:
			continue
		var flags: int = rows[i][1]
		_orbits_color_pkrs[i].color = _body_huds_state.get_orbit_color(flags)


func _hack_fix_toggle_off(is_pressed: bool, button: ColorPickerButton) -> void:
	# Hack fix to let button toggle off, as it should...
	# Requres action_mode = ACTION_MODE_BUTTON_PRESS
	if !is_pressed:
		yield(get_tree(), "idle_frame")
		button.get_popup().hide()


func _resize_columns(_dummy := false) -> void:
	if column_master:
		column_master.connect("resized", self, "_resize_columns_to_master")
		_resize_columns_to_master(1)
	else:
		_resize_columns_to_en_width(0)


func _resize_columns_to_master(delay_frames := 0) -> void:
	for i in delay_frames:
		yield(get_tree(), "idle_frame")
	var n_master_children := column_master.get_child_count()
	for i in columns:
		if i == n_master_children:
			break
		var master_column_width: float = column_master.get_child(i).rect_size.x
		get_child(i).rect_min_size.x = master_column_width
		get_child(i).rect_size.x = master_column_width


func _resize_columns_to_en_width(delay_frames := 0) -> void:
	# 1 delay_frames needed for font size change.
	for i in delay_frames:
		yield(get_tree(), "idle_frame")
	var font := get_font("normal", "Label")
	var en_width := font.get_char_size(ord("\u2000")).x
	var min_width_col0 := en_width * column0_en_width
	get_child(0).rect_min_size.x = min_width_col0
	get_child(0).rect_size.x = min_width_col0
	var min_width := en_width * columns_en_width
	for i in range(1, columns):
		get_child(i).rect_min_size.x = min_width
		get_child(i).rect_size.x = min_width


func _settings_listener(setting: String, _value) -> void:
	if setting == "gui_size":
		if !column_master:
			_resize_columns_to_en_width(1)
