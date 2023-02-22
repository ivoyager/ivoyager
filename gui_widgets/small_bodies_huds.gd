# small_boides_huds.gd
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
class_name IVSmallBodiesHUDs
extends GridContainer

# GUI widget.
#
# Class properties must be set before _ready(). Use parent _enter_tree() and
# 'child_entered_tree' signal to do so.
#
# See widget IVAllHUDsGrids for setting up multiple grids and aligning their
# columns.

var NULL_COLOR := Color.black


var has_headers := true
var column0_en_width := 0
var column_master: Control # if set, column widths follow master children 

var rows := [
	["LABEL_ASTEROIDS", ["NE", "MC", "IMB", "MMB", "OMB", "HI", "JT4", "JT5", "CE", "TN"]],
	["   " + tr("LABEL_NEAR_EARTH"), ["NE"]],
	["   " + tr("LABEL_MARS_CROSSERS"), ["MC"]],
	["   " + tr("LABEL_MAIN_BELT_INNER"), ["IMB"]],
	["   " + tr("LABEL_MAIN_BELT_MIDDLE"), ["MMB"]],
	["   " + tr("LABEL_MAIN_BELT_OUTER"), ["OMB"]],
	["   " + tr("LABEL_HILDAS"), ["HI"]],
	["   " + tr("LABEL_JUPITER_TROJANS"), ["JT4", "JT5"]],
	["   " + tr("LABEL_CENTAURS"), ["CE"]],
	["   " + tr("LABEL_TRANS_NEPTUNIAN"), ["TN"]],
]

var headers := ["LABEL_POINTS", "LABEL_ORBITS"]

var _points_chkbxs := []
var _orbits_chkbxs := []
var _points_color_pkrs := []
var _orbits_color_pkrs := []

var _suppress_update := false
var _is_color_change := false

onready var _huds_visibility: IVHUDsVisibility = IVGlobal.program.HUDsVisibility
onready var _settings_manager: IVSettingsManager = IVGlobal.program.SettingsManager
onready var _small_bodies_points_colors: Dictionary = IVGlobal.settings.small_bodies_points_colors
onready var _small_bodies_orbits_colors: Dictionary = IVGlobal.settings.small_bodies_orbits_colors
onready var _n_rows := rows.size()


func _ready() -> void:
	IVGlobal.connect("setting_changed", self, "_settings_listener")
	IVGlobal.connect("update_gui_requested", self, "_update_points_color_buttons")
	IVGlobal.connect("update_gui_requested", self, "_update_orbits_color_buttons")
	_huds_visibility.connect("sbg_points_visibility_changed", self, "_update_points_ckbxs")
	_huds_visibility.connect("sbg_orbits_visibility_changed", self, "_update_orbits_ckbxs")
	
	# headers
	if has_headers:
		var spacer := Label.new()
		var spacer_text := ""
		for i in column0_en_width:
			spacer_text += "\u2000" # EN QUAD
		spacer.text = spacer_text
		add_child(spacer)
		for header_text in headers:
			var header := Label.new()
			header.align = Label.ALIGN_CENTER
			header.text = header_text
			add_child(header)
	
	# grid content
	var points_default_color: Color = IVGlobal.settings.small_bodies_points_default_color
	var orbits_default_color: Color = IVGlobal.settings.small_bodies_orbits_default_color
	for i in _n_rows:
		var label_text: String = rows[i][0]
		var groups: Array = rows[i][1]
		var label := Label.new()
		label.text = label_text
		add_child(label)
		# points
		var hbox := HBoxContainer.new()
#		hbox.size_flags_horizontal = SIZE_SHRINK_CENTER
		hbox.alignment = BoxContainer.ALIGN_CENTER
		add_child(hbox)
		var chkbx := _make_checkbox()
		chkbx.connect("pressed", self, "_show_hide_points", [chkbx, groups])
		_points_chkbxs.append(chkbx)
		hbox.add_child(chkbx)
		var color_button := _make_color_picker_button(points_default_color)
		color_button.connect("color_changed", self, "_change_points_color", [groups])
		_points_color_pkrs.append(color_button)
		hbox.add_child(color_button)
		# orbits
		hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = SIZE_SHRINK_CENTER
		hbox.alignment = BoxContainer.ALIGN_CENTER
		add_child(hbox)
		chkbx = _make_checkbox()
		chkbx.connect("pressed", self, "_show_hide_orbits", [chkbx, groups])
		_orbits_chkbxs.append(chkbx)
		hbox.add_child(chkbx)
		color_button = _make_color_picker_button(orbits_default_color)
		color_button.connect("color_changed", self, "_change_orbits_color", [groups])
		_orbits_color_pkrs.append(color_button)
		hbox.add_child(color_button)
	
	# column width control
	if !column_master:
		return
	column_master.connect("resized", self, "_resize_columns")
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame") # needs 2 frame delay as of 3.5.2
	yield(get_tree(), "idle_frame") # added extra for safety
	_resize_columns()


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
	var picker_popup := button.get_popup()
	picker_popup.connect("popup_hide", self, "_on_color_picker_hide")
	return button


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
		_huds_visibility.change_sbg_orbits_visibility(group, pressed)
	_suppress_update = false
	_update_orbits_ckbxs()


func _change_points_color(color: Color, groups: Array) -> void:
	if color == NULL_COLOR:
		return
	_suppress_update = true
	for group in groups:
		_set_settings_points_color(group, color)
	_suppress_update = false
	_update_points_color_buttons()


func _change_orbits_color(color: Color, groups: Array) -> void:
	if color == NULL_COLOR:
		return
	_suppress_update = true
	for group in groups:
		_set_settings_orbits_color(group, color)
	_suppress_update = false
	_update_orbits_color_buttons()


func _update_points_ckbxs() -> void:
	if _suppress_update:
		return
	for i in _n_rows:
		var groups: Array = rows[i][1]
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
		var groups: Array = rows[i][1]
		var is_orbits_visible := true
		for group in groups:
			if !_huds_visibility.is_sbg_orbits_visible(group):
				is_orbits_visible = false
				break
		_orbits_chkbxs[i].pressed = is_orbits_visible


func _update_points_color_buttons() -> void:
	if _suppress_update:
		return
	for i in _n_rows:
		var groups: Array = rows[i][1]
		var use_null_color := false
		var button_color := NULL_COLOR
		for group in groups:
			var color := _get_settings_points_color(group)
			if !use_null_color and button_color == NULL_COLOR:
				button_color = color
			elif button_color != color:
				use_null_color = true
				button_color = NULL_COLOR
				break
		_points_color_pkrs[i].color = button_color


func _update_orbits_color_buttons() -> void:
	if _suppress_update:
		return
	for i in _n_rows:
		var groups: Array = rows[i][1]
		var use_null_color := false
		var button_color := NULL_COLOR
		for group in groups:
			var color := _get_settings_orbits_color(group)
			if !use_null_color and button_color == NULL_COLOR:
				button_color = color
			elif button_color != color:
				use_null_color = true
				button_color = NULL_COLOR
				break
		_orbits_color_pkrs[i].color = button_color


func _get_settings_points_color(group: String) -> Color:
	if _small_bodies_points_colors.has(group):
		return _small_bodies_points_colors[group]
	return IVGlobal.settings.small_bodies_points_default_color


func _get_settings_orbits_color(group: String) -> Color:
	if _small_bodies_orbits_colors.has(group):
		return _small_bodies_orbits_colors[group]
	return IVGlobal.settings.small_bodies_orbits_default_color


func _set_settings_points_color(group: String, color: Color) -> void:
	if color.is_equal_approx(_get_settings_points_color(group)):
		return
	if color == IVGlobal.settings.small_bodies_points_default_color:
		_small_bodies_points_colors.erase(group)
	else:
		_small_bodies_points_colors[group] = color
	IVGlobal.emit_signal("setting_changed", "small_bodies_points_colors",
			_small_bodies_points_colors)
	_is_color_change = true


func _set_settings_orbits_color(group: String, color: Color) -> void:
	if color.is_equal_approx(_get_settings_orbits_color(group)):
		return
	if color == IVGlobal.settings.small_bodies_orbits_default_color:
		_small_bodies_orbits_colors.erase(group)
	else:
		_small_bodies_orbits_colors[group] = color
	IVGlobal.emit_signal("setting_changed", "small_bodies_orbits_colors",
			_small_bodies_orbits_colors)
	_is_color_change = true


func _on_color_picker_hide() -> void:
	if !_is_color_change:
		return
	_is_color_change = false
	_settings_manager.cache_now()


func _resize_columns() -> void:
	var n_master_children := column_master.get_child_count()
	for i in columns:
		if i == n_master_children:
			break
		get_child(i).rect_min_size.x = column_master.get_child(i).rect_size.x


func _hack_fix_toggle_off(is_pressed: bool, button: ColorPickerButton) -> void:
	# Hack fix to let button toggle off, as it should...
	# Requres action_mode = ACTION_MODE_BUTTON_PRESS
	if !is_pressed:
		yield(get_tree(), "idle_frame")
		button.get_popup().hide()


func _settings_listener(setting: String, _value) -> void:
	if setting == "small_bodies_points_colors":
		_update_points_color_buttons()
		
