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

# GUI widget. Requires IVBodyHUDsState.
#
# Class properties must be set before _ready(). See widget IVAllHUDs for complex
# row construction, setting up multiple grids, and aligning their columns.
#
# To display correctly, ColorPickerButton needs a StyleBoxTexture with no
# margins.
#
# IMPORTANT! For correct visibility control, BodyFlags used in rows must be a
# subset of IVBodyHUDsState.all_flags.

const NULL_COLOR := Color.BLACK
const BodyFlags: Dictionary = IVEnums.BodyFlags


var enable_wiki: bool = IVGlobal.enable_wiki

var has_headers := true
var column_master: Control # if set, column widths follow master children
var column0_en_width := 0 # 'EN QUAD' size if column_master == null
var columns_en_width := 0 # as above for data columns
var indent := "  "

var rows: Array[Array] = [
	# [row_name, flags, is_indent]
	[&"LABEL_PLANETARY_MASS_OBJECTS", 0, false], # 0 replaced by all flags from following rows
	[&"LABEL_PLANETS", BodyFlags.IS_TRUE_PLANET, true],
	[&"LABEL_DWARF_PLANETS", BodyFlags.IS_DWARF_PLANET, true],
	[&"LABEL_MOONS_WIKI_PMO", BodyFlags.IS_PLANETARY_MASS_MOON, true],
]

var disable_orbits_rows: Array[int] = [] # e.g., no orbit for Sun

var headers: Array[StringName] = [&"LABEL_NAMES_SLASH_SYMBOLS_SHORT", &"LABEL_ORBITS"]
var header_hints: Array[StringName] = [&"HINT_NAMES_SYMBOLS_CKBXS", &"HINT_ORBITS_CKBX_COLOR"]


var _wiki_titles: Dictionary = IVTableData.wiki_lookup
var _all_flags := 0 # generated from all rows
var _names_ckbxs: Array[CheckBox] = []
var _symbols_ckbxs: Array[CheckBox] = []
var _orbits_ckbxs: Array[CheckBox] = []
var _orbits_color_pkrs: Array[ColorPickerButton] = []

@onready var _body_huds_state: IVBodyHUDsState = IVGlobal.program[&"BodyHUDsState"]
@onready var _n_rows := rows.size()


func _ready() -> void:
	IVGlobal.setting_changed.connect(_settings_listener)
	IVGlobal.update_gui_requested.connect(_update_orbit_color_buttons)
	_body_huds_state.visibility_changed.connect(_update_ckbxs)
	_body_huds_state.color_changed.connect(_update_orbit_color_buttons)

	# headers
	if has_headers:
		var empty_cell := Control.new()
		empty_cell.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(empty_cell)
		for i in 2:
			var header := Label.new()
			header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			header.text = headers[i]
			header.tooltip_text = header_hints[i]
			header.mouse_filter = MOUSE_FILTER_PASS
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
		var row_name: StringName = rows[i][0]
		var is_indent: bool = rows[i][2]
		if enable_wiki and _wiki_titles.has(row_name):
			var rtlabel := RichTextLabel.new()
			rtlabel.meta_clicked.connect(_on_meta_clicked.bind(row_name))
			rtlabel.bbcode_enabled = true
			rtlabel.fit_content = true
			rtlabel.scroll_active = false
			if is_indent:
				rtlabel.text = indent
			rtlabel.text += "[url]" + tr(row_name) + "[/url]"
			add_child(rtlabel)
		else:
			var label := Label.new()
			label.text = indent + tr(row_name) if is_indent else tr(row_name)
			add_child(label)
		
		# names/symbols
		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(hbox)
		var ckbx := _make_checkbox()
		ckbx.pressed.connect(_show_hide_names.bind(ckbx, flags))
		_names_ckbxs.append(ckbx)
		hbox.add_child(ckbx)
		ckbx = _make_checkbox()
		ckbx.pressed.connect(_show_hide_symbols.bind(ckbx, flags))
		_symbols_ckbxs.append(ckbx)
		hbox.add_child(ckbx)
		
		# orbits
		if disable_orbits_rows.has(i):
			var spacer := Control.new()
			spacer.size_flags_horizontal = SIZE_SHRINK_CENTER
			spacer.mouse_filter = MOUSE_FILTER_IGNORE
			add_child(spacer)
			_orbits_ckbxs.append(null)
			_orbits_color_pkrs.append(null)
		else:
			hbox = HBoxContainer.new()
			hbox.alignment = BoxContainer.ALIGNMENT_CENTER
			hbox.mouse_filter = MOUSE_FILTER_IGNORE
			add_child(hbox)
			ckbx = _make_checkbox()
			ckbx.pressed.connect(_show_hide_orbits.bind(ckbx, flags))
			_orbits_ckbxs.append(ckbx)
			hbox.add_child(ckbx)
			var orbit_default_color: Color = _body_huds_state.get_default_orbit_color(flags)
			var color_button := _make_color_picker_button(orbit_default_color)
			color_button.color_changed.connect(_change_orbit_color.bind(flags))
			_orbits_color_pkrs.append(color_button)
			hbox.add_child(color_button)
	
	# column sizing
	if IVGlobal.state.is_started_or_about_to_start:
		_resize_columns()
	else:
		IVGlobal.about_to_start_simulator.connect(_resize_columns, CONNECT_ONE_SHOT)


func _make_checkbox() -> CheckBox:
	var ckbx := CheckBox.new()
	ckbx.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ckbx.size_flags_horizontal = SIZE_SHRINK_CENTER
	return ckbx


func _make_color_picker_button(default_color: Color) -> ColorPickerButton:
	var button := ColorPickerButton.new()
	button.toggled.connect(_hack_fix_toggle_off.bind(button))
	button.custom_minimum_size.x = 15
	button.custom_minimum_size.y = 15
	button.size_flags_vertical = SIZE_SHRINK_CENTER
	button.set(&"theme_override_fonts/font", IVGlobal.fonts.two_pt) # allow short button hack
	button.edit_alpha = false
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	var color_picker := button.get_picker()
	color_picker.add_preset(default_color)
	# Note: As of Godot 3.5.2, a ColorPicker that never gets any add_preset()
	# shows all presets set in all ColorPickers (even redundant ones). 
	return button


func _show_hide_names(ckbx: CheckBox, flags: int) -> void:
	_body_huds_state.set_name_visibility(flags, ckbx.button_pressed)


func _show_hide_symbols(ckbx: CheckBox, flags: int) -> void:
	_body_huds_state.set_symbol_visibility(flags, ckbx.button_pressed)


func _show_hide_orbits(ckbx: CheckBox, flags: int) -> void:
	_body_huds_state.set_orbit_visibility(flags, ckbx.button_pressed)


func _update_ckbxs() -> void:
	for i in _n_rows:
		var flags: int = rows[i][1]
		_names_ckbxs[i].button_pressed = _body_huds_state.is_name_visible(flags, true)
		_symbols_ckbxs[i].button_pressed = _body_huds_state.is_symbol_visible(flags, true)
		if _orbits_ckbxs[i]:
			_orbits_ckbxs[i].button_pressed = _body_huds_state.is_orbit_visible(flags, true)


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
		await get_tree().process_frame
		button.get_popup().hide()


func _resize_columns(_dummy := false) -> void:
	if column_master:
		column_master.resized.connect(_resize_columns_to_master)
		_resize_columns_to_master(1)
	else:
		_resize_columns_to_en_width(0)


func _resize_columns_to_master(delay_frames := 0) -> void:
	for i in delay_frames:
		await get_tree().process_frame
	var n_master_children := column_master.get_child_count()
	for i in columns:
		if i == n_master_children:
			break
		var master_child: Control = column_master.get_child(i)
		var master_column_width: float = master_child.size.x
		var child: Control = get_child(i)
		child.custom_minimum_size.x = master_column_width
		child.size.x = master_column_width


func _resize_columns_to_en_width(delay_frames := 0) -> void:
	# 1 delay_frames needed for font size change.
	for i in delay_frames:
		await get_tree().process_frame
	
	# FIXME34: Must be a better wat to get this
	var font: FontFile = get_theme_font(&"normal", &"Label")
	var font_size := font.fixed_size
	var en_width := font.get_char_size("\u2000".unicode_at(0), font_size).x
	
	var min_width_col0 := en_width * column0_en_width
	var child: Control = get_child(0)
	child.custom_minimum_size.x = min_width_col0
	child.size.x = min_width_col0
	var min_width := en_width * columns_en_width
	for i in range(1, columns):
		child = get_child(i)
		child.custom_minimum_size.x = min_width
		child.size.x = min_width


func _on_meta_clicked(_meta: String, row_name: StringName) -> void:
	var wiki_title: String = _wiki_titles[row_name]
	IVGlobal.open_wiki_requested.emit(wiki_title)


func _settings_listener(setting: StringName, _value: Variant) -> void:
	if setting == &"gui_size":
		if !column_master:
			_resize_columns_to_en_width(1)

