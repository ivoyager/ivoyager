# options_popup.gd
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
class_name IVOptionsPopup
extends IVCachedItemsPopup

# Parent class provides public methods for adding, removing and moving
# subpanels and individual items within the panel.

const DPRINT := true

var setting_enums := {
	gui_size = IVEnums.GUISize,
	starmap = IVEnums.StarmapSize,
}
var format_overrides := {
	camera_transfer_time = {max_value = 10.0},
	viewport_names_size = {min_value = 4.0, max_value = 50.0},
	viewport_symbols_size = {min_value = 4.0, max_value = 50.0},
	point_size = {min_value = 3, max_value = 20},
}

var _settings: Dictionary = IVGlobal.settings
var _hotkeys_button: Button

@onready var _settings_manager: IVSettingsManager = IVGlobal.program.SettingsManager


func _on_init():
	# Edit layout directly or use parent class functions at project init.
	
	var column1: Array[Dictionary] = [ # each dict is a subpanel
		{
			header = "LABEL_SAVE_LOAD",
			save_base_name = "LABEL_BASE_NAME",
			append_date_to_save = "LABEL_APPEND_DATE",
			pause_on_load = "LABEL_PAUSE_ON_LOAD",
		},
		{
			header = "LABEL_CAMERA",
			camera_transfer_time = "LABEL_TRANSFER_TIME",
			camera_mouse_in_out_rate = "LABEL_MOUSE_RATE_IN_OUT",
			camera_mouse_move_rate = "LABEL_MOUSE_RATE_TANGENTIAL",
			camera_mouse_pitch_yaw_rate = "LABEL_MOUSE_RATE_PITCH_YAW",
			camera_mouse_roll_rate = "LABEL_MOUSE_RATE_ROLL",
			camera_key_in_out_rate = "LABEL_KEY_RATE_IN_OUT",
			camera_key_move_rate = "LABEL_KEY_RATE_TANGENTIAL",
			camera_key_pitch_yaw_rate = "LABEL_KEY_RATE_PITCH_YAW",
			camera_key_roll_rate = "LABEL_KEY_RATE_ROLL",
		},
	]
	
	var column2: Array[Dictionary] = [
		{
			header = "LABEL_GUI_AND_HUD",
			gui_size = "LABEL_GUI_SIZE",
			viewport_names_size = "LABEL_NAMES_SIZE",
			viewport_symbols_size = "LABEL_SYMBOLS_SIZE",
			point_size = "LABEL_POINT_SIZE",
			hide_hud_when_close = "LABEL_HIDE_HUDS_WHEN_CLOSE",
		},
		{
			header = "LABEL_GRAPHICS_PERFORMANCE",
			starmap = "LABEL_STARMAP",
		},
	]
	
	layout = [column1, column2]


func _project_init() -> void:
	super._project_init()
	IVGlobal.options_requested.connect(_open)
	IVGlobal.setting_changed.connect(_settings_listener)
	if !IVGlobal.enable_save_load:
		remove_subpanel("LABEL_SAVE_LOAD")


func _on_ready() -> void:
	super._on_ready()
	_header_label.text = "LABEL_OPTIONS"
	_hotkeys_button = Button.new()
	_hotkeys_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_hotkeys_button.text = "BUTTON_HOTKEYS"
	_hotkeys_button.pressed.connect(_open_hotkeys)
	_header_right.add_child(_hotkeys_button)


func _build_item(setting: String, setting_label_str: String) -> HBoxContainer:
	var setting_hbox := HBoxContainer.new()
	var setting_label := Label.new()
	setting_hbox.add_child(setting_label)
	setting_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setting_label.text = setting_label_str
	var default_button := Button.new()
	default_button.text = "!"
	default_button.disabled = _settings_manager.is_default(setting)
	default_button.pressed.connect(_restore_default.bind(setting))
	var value = _settings[setting]
	var default_value = _settings_manager.defaults[setting]
	var type := typeof(default_value)
	match type:
		TYPE_BOOL:
			# CheckBox
			var checkbox := CheckBox.new()
			setting_hbox.add_child(checkbox)
			checkbox.size_flags_horizontal = Control.SIZE_SHRINK_END
			_set_overrides(checkbox, setting)
			checkbox.button_pressed = value
			checkbox.toggled.connect(_on_change.bind(setting, default_button))
		TYPE_INT, TYPE_FLOAT:
			var is_int := type == TYPE_INT
			if is_int and setting_enums.has(setting):
				# OptionButton
				var setting_enum: Dictionary = setting_enums[setting]
				var keys: Array = setting_enum.keys()
				var option_button := OptionButton.new()
				setting_hbox.add_child(option_button)
				for key in keys:
					option_button.add_item(key)
				_set_overrides(option_button, setting)
				option_button.selected = value
				option_button.item_selected.connect(_on_change.bind(setting, default_button))
			else: # non-option int or float
				# SpinBox
				var spin_box := SpinBox.new()
				setting_hbox.add_child(spin_box)
				
				# FIXME34
#				spin_box.horizontal_alignment # missing?
##				spin_box.align = LineEdit.HORIZONTAL_ALIGNMENT_CENTER # ALIGN_RIGHT is buggy w/ big fonts

				spin_box.step = 1.0 if is_int else 0.1
				spin_box.rounded = is_int
				spin_box.min_value = 0.0
				spin_box.max_value = 100.0
				_set_overrides(spin_box, setting)
				spin_box.value = value
				spin_box.value_changed.connect(_on_change.bind(setting, default_button, is_int))
				var line_edit := spin_box.get_line_edit()
				line_edit.context_menu_enabled = false
#				line_edit.update() # TEST34: Do we need to do something?
		TYPE_STRING:
			# LineEdit
			var line_edit := LineEdit.new()
			setting_hbox.add_child(line_edit)
			line_edit.size_flags_horizontal = BoxContainer.SIZE_SHRINK_END
			line_edit.custom_minimum_size.x = 100.0
			_set_overrides(line_edit, setting)
			line_edit.text = value
			line_edit.text_changed.connect(_on_change.bind(setting, default_button))
		TYPE_COLOR:
			# ColorPickerButton
			var color_picker_button := ColorPickerButton.new()
			setting_hbox.add_child(color_picker_button)
			color_picker_button.custom_minimum_size.x = 60.0
			color_picker_button.edit_alpha = false
			_set_overrides(color_picker_button, setting)
			color_picker_button.color = value
			color_picker_button.color_changed.connect(_on_change.bind(setting, default_button))
		_:
			print("ERROR: Unknown Option type!")
	setting_hbox.add_child(default_button)
	return setting_hbox


func _set_overrides(control: Control, setting: String) -> void:
	if format_overrides.has(setting):
		var overrides: Dictionary = format_overrides[setting]
		for override in overrides:
			control.set(override, overrides[override])


func _on_content_built() -> void:
	_restore_defaults.disabled = _settings_manager.is_all_defaults()
	var is_cache_current := _settings_manager.is_cache_current()
	_confirm_changes.disabled = is_cache_current
	_hotkeys_button.disabled = !is_cache_current


func _restore_default(setting: String) -> void:
	_settings_manager.restore_default(setting, true)
	_build_content.call_deferred()


func _cancel_changes() -> void:
	_settings_manager.restore_from_cache()
	_allow_close = true
	hide()


func _on_change(value, setting: String, default_button: Button, convert_to_int := false) -> void:
	if convert_to_int:
		value = int(value)
	assert(!DPRINT or IVDebug.dprint("Set " + setting + " = " + str(value)))
	_settings_manager.change_current(setting, value, true)
	default_button.disabled = _settings_manager.is_default(setting)
	_restore_defaults.disabled = _settings_manager.is_all_defaults()
	var is_cache_current := _settings_manager.is_cache_current()
	_confirm_changes.disabled = is_cache_current
	_hotkeys_button.disabled = !is_cache_current


func _on_restore_defaults() -> void:
	_settings_manager.restore_all_defaults(true)
	_build_content.call_deferred()


func _on_confirm_changes() -> void:
	_settings_manager.cache_now()
	_allow_close = true
	hide()


func _on_cancel() -> void:
	if _settings_manager.is_cache_current():
		_allow_close = true
		hide()
		return
	IVGlobal.confirmation_requested.emit("LABEL_Q_CANCEL_OPTIONS_CHANGES", _cancel_changes, true,
			"LABEL_PLEASE_CONFIRM", "BUTTON_CANCEL_CHANGES", "BUTTON_BACK")


func _open_hotkeys() -> void:
	if !_settings_manager.is_cache_current(): # safety test (should be disabled)
		return
	_allow_close = true
	hide()
	IVGlobal.hotkeys_requested.emit()


func _settings_listener(setting: String, _value) -> void:
	if setting == "gui_size":
		await get_tree().process_frame
		#child_controls_changed() # Godot ISSUE4.2.dev2: does not resize
		size = Vector2i.ZERO # hack fix above

