# sbg_huds.gd
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
class_name IVSBGHUDs
extends GridContainer

# GUI widget. Requires IVSBGHUDsState.
#
# Class properties must be set before _ready(). See widget IVAllHUDs for complex
# row construction, setting up multiple grids, and aligning their columns.
#
# To display correctly, ColorPickerButton needs a StyleBoxTexture with no
# margins.

const NULL_COLOR := Color.BLACK


var enable_wiki: bool = IVGlobal.enable_wiki

var has_headers := true
var column_master: Control # if set, column widths follow master children
var column0_en_width := 0 # 'EN QUAD' size if column_master == null
var columns_en_width := 0 # as above for data columns
var indent := "  "

var rows: Array[Array] = [
	# [row_name, sbg_aliases, is_indent]
	["LABEL_JUPITER_TROJANS", ["JT4", "JT5"] as Array[String], false], # example row
]

var headers: Array[String] = ["LABEL_POINTS", "LABEL_ORBITS"]
var header_hints: Array[String] = ["HINT_POINTS_CKBX_COLOR", "HINT_ORBITS_CKBX_COLOR"]


var _wiki_titles: Dictionary = IVTableData.wiki_lookup
var _points_ckbxs: Array[CheckBox] = []
var _orbits_ckbxs: Array[CheckBox] = []
var _points_color_pkrs: Array[ColorPickerButton] = []
var _orbits_color_pkrs: Array[ColorPickerButton] = []
var _suppress_update := false

@onready var _sbg_huds_state: IVSBGHUDsState = IVGlobal.program.SBGHUDsState
@onready var _n_rows := rows.size()


func _ready() -> void:
	
	print(_wiki_titles)
	
	
	IVGlobal.setting_changed.connect(_settings_listener)
	_sbg_huds_state.points_visibility_changed.connect(_update_points_ckbxs)
	_sbg_huds_state.orbits_visibility_changed.connect(_update_orbits_ckbxs)
	_sbg_huds_state.points_color_changed.connect(_update_points_color_buttons)
	_sbg_huds_state.orbits_color_changed.connect(_update_orbits_color_buttons)
	
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
			header.mouse_filter = Control.MOUSE_FILTER_PASS
			add_child(header)
	
	# grid content
	for i in _n_rows:
		var row_name: String = rows[i][0]
		var groups: Array[String] = rows[i][1]
		var is_indent: bool = rows[i][2]
		# row label
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
			label.text = indent + tr(row_name) if is_indent else row_name
			add_child(label)
		# points
		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(hbox)
		var ckbx := _make_checkbox()
		ckbx.pressed.connect(_show_hide_points.bind(ckbx, groups))
		_points_ckbxs.append(ckbx)
		hbox.add_child(ckbx)
		var points_default_color := _sbg_huds_state.get_consensus_points_color(groups, true)
		var color_button := _make_color_picker_button(points_default_color)
		color_button.color_changed.connect(_change_points_color.bind(groups))
		_points_color_pkrs.append(color_button)
		hbox.add_child(color_button)
		# orbits
		hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = SIZE_SHRINK_CENTER
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(hbox)
		ckbx = _make_checkbox()
		ckbx.pressed.connect(_show_hide_orbits.bind(ckbx, groups))
		_orbits_ckbxs.append(ckbx)
		hbox.add_child(ckbx)
		var orbits_default_color := _sbg_huds_state.get_consensus_orbits_color(groups, true)
		color_button = _make_color_picker_button(orbits_default_color)
		color_button.color_changed.connect(_change_orbits_color.bind(groups))
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
	button.set("theme_override_fonts/font", IVGlobal.fonts.two_pt) # allow short button hack
	button.edit_alpha = false
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	var color_picker := button.get_picker()
	color_picker.add_preset(default_color)
	return button


func _show_hide_points(ckbx: CheckBox, groups: Array[String]) -> void:
	_suppress_update = true
	var pressed := ckbx.button_pressed
	for group in groups:
		_sbg_huds_state.change_points_visibility(group, pressed)
	_suppress_update = false
	_update_points_ckbxs()


func _show_hide_orbits(ckbx: CheckBox, groups: Array[String]) -> void:
	_suppress_update = true
	var pressed := ckbx.button_pressed
	for group in groups:
		_sbg_huds_state.change_orbits_visibility(group, pressed)
	_suppress_update = false
	_update_orbits_ckbxs()


func _change_points_color(color: Color, groups: Array[String]) -> void:
	if color == NULL_COLOR:
		return
	_suppress_update = true
	for group in groups:
		_sbg_huds_state.set_points_color(group, color)
	_suppress_update = false
	_update_points_color_buttons()


func _change_orbits_color(color: Color, groups: Array[String]) -> void:
	if color == NULL_COLOR:
		return
	_suppress_update = true
	for group in groups:
		_sbg_huds_state.set_orbits_color(group, color)
	_suppress_update = false
	_update_orbits_color_buttons()


func _update_points_ckbxs() -> void:
	if _suppress_update:
		return
	for i in _n_rows:
		var groups: Array[String] = rows[i][1]
		var is_points_visible := true
		for group in groups:
			if !_sbg_huds_state.is_points_visible(group):
				is_points_visible = false
				break
		_points_ckbxs[i].button_pressed = is_points_visible


func _update_orbits_ckbxs() -> void:
	if _suppress_update:
		return
	for i in _n_rows:
		var groups: Array[String] = rows[i][1]
		var is_orbits_visible := true
		for group in groups:
			if !_sbg_huds_state.is_orbits_visible(group):
				is_orbits_visible = false
				break
		_orbits_ckbxs[i].button_pressed = is_orbits_visible


func _update_points_color_buttons() -> void:
	if _suppress_update:
		return
	for i in _n_rows:
		var groups: Array[String] = rows[i][1]
		var color := _sbg_huds_state.get_consensus_points_color(groups)
		_points_color_pkrs[i].color = color


func _update_orbits_color_buttons() -> void:
	if _suppress_update:
		return
	for i in _n_rows:
		var groups: Array[String] = rows[i][1]
		var color := _sbg_huds_state.get_consensus_orbits_color(groups)
		_orbits_color_pkrs[i].color = color


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
	var font: FontFile = get_theme_font("normal", "Label")
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


func _on_meta_clicked(_meta: String, row_name: String) -> void:
	var wiki_title: String = _wiki_titles[row_name]
	IVGlobal.open_wiki_requested.emit(wiki_title)


func _settings_listener(setting: String, _value) -> void:
	if setting == "gui_size":
		if !column_master:
			_resize_columns_to_en_width(1)

