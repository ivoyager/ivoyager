# options_popup.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2019 Charlie Whitfield
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
#
# Parent class provides public methods for adding, removing and moving
# subpanels and individual items within the panel.

extends CachedItemsPopup
class_name OptionsPopup

const DPRINT := true

var setting_enums := {
	gui_size = SettingsManager.GUISizes
}

var format_overrides := {
	camera_transition_time = {max_value = 10.0},
	viewport_label_size = {min_value = 4.0, max_value = 36.0},
	viewport_icon_size = {min_value = 40.0, max_value = 300.0, step = 10.0},
}

var _settings: Dictionary = Global.settings
onready var _settings_manager: SettingsManager = Global.objects.SettingsManager


func _on_init():
	# Edit layout directly or use parent class functions at project init.
	layout = [
		[ # column 1; each dict is a subpanel
			{
				header = "LABEL_SAVE_LOAD",
				save_base_name = "LABEL_BASE_NAME",
				append_date_to_save = "LABEL_APPEND_DATE",
				loaded_game_is_paused = "LABEL_ALWAYS_PAUSE_ON_LOAD",
			},
			{
				header = "LABEL_CAMERA",
				camera_transition_time = "LABEL_TRANSITION_TIME",
				camera_mouse_in_out_rate = "LABEL_MOUSE_RATE_IN_OUT",
				camera_mouse_move_rate = "LABEL_MOUSE_RATE_TANGENTIAL",
				camera_mouse_pitch_yaw_rate = "LABEL_MOUSE_RATE_PITCH_YAW",
				camera_mouse_roll_rate = "LABEL_MOUSE_RATE_ROLL",
				camera_key_in_out_rate = "LABEL_KEY_RATE_IN_OUT",
				camera_key_move_rate = "LABEL_KEY_RATE_TANGENTIAL",
				camera_key_pitch_yaw_rate = "LABEL_KEY_RATE_PITCH_YAW",
				camera_key_roll_rate = "LABEL_KEY_RATE_ROLL",
			}
		],
		[ # column 2
			{
				header = "LABEL_ORBIT_POINT_COLORS",
				planet_orbit_color = "LABEL_PLANET_ORBITS",
				dwarf_planet_orbit_color = "LABEL_DWARF_PLANET_ORBITS",
				moon_orbit_color = "LABEL_MAJOR_MOON_ORBITS",
				minor_moon_orbit_color = "LABEL_MINOR_MOON_ORBITS",
				asteroid_point_color = "LABEL_ASTEROID_POINTS",
			},
			{
				header = "LABEL_GUI_AND_HUD",
				gui_size = "LABEL_GUI_SIZE",
				viewport_label_size = "LABEL_LABEL_SIZE",
				viewport_icon_size = "LABEL_ICON_SIZE",
				hide_hud_when_close = "LABEL_HIDE_HUDS_WHEN_CLOSE",
			},
		]
	]

func project_init() -> void:
	.project_init()
	var main_menu: MainMenu = Global.objects.get("MainMenu")
	if main_menu:
		main_menu.make_button("BUTTON_OPTIONS", 500, true, true, self, "_open")
	Global.connect("options_requested", self, "_open")
	Global.connect("setting_changed", self, "_settings_listener")
	if !Global.enable_save_load:
		remove_subpanel("LABEL_SAVE_LOAD")

func _on_ready() -> void:
	._on_ready()
	_header.text = "LABEL_OPTIONS"
	_aux_button.show()
	_aux_button.text = "BUTTON_HOTKEYS"
	_aux_button.connect("pressed", self, "_open_hotkeys")
	_spacer.show()

func _open() -> void:
	._open()
	_spacer.rect_min_size.x = _aux_button.rect_size.x

func _build_item(setting: String, setting_label_str: String) -> HBoxContainer:
	var setting_hbox := HBoxContainer.new()
	var setting_label := Label.new()
	setting_hbox.add_child(setting_label)
	setting_label.size_flags_horizontal = BoxContainer.SIZE_EXPAND_FILL
	setting_label.text = setting_label_str
	var default_button := Button.new()
	default_button.text = "!"
	default_button.disabled = _settings_manager.is_default(setting)
	default_button.connect("pressed", self, "_restore_default", [setting])
	var value = _settings[setting]
	var default_value = _settings_manager.defaults[setting]
	var type := typeof(default_value)
	match type:
		TYPE_BOOL:
			var checkbox := CheckBox.new()
			setting_hbox.add_child(checkbox)
			checkbox.size_flags_horizontal = BoxContainer.SIZE_SHRINK_END
			_set_overrides(checkbox, setting)
			checkbox.pressed = value
			checkbox.connect("toggled", self, "_on_change", [setting, default_button])
		TYPE_INT: # handle enums here
			if not setting_enums.has(setting):
				continue
			var setting_enum: Dictionary = setting_enums[setting]
			var keys: Array = setting_enum.keys()
			var option_button := OptionButton.new()
			setting_hbox.add_child(option_button)
			for key in keys:
				option_button.add_item(key)
			_set_overrides(option_button, setting)
			option_button.selected = value
			option_button.connect("item_selected", self, "_on_change", [setting, default_button])
		TYPE_INT, TYPE_REAL:
			var is_int := type == TYPE_INT
			var spin_box := SpinBox.new()
			setting_hbox.add_child(spin_box)
			spin_box.align = LineEdit.ALIGN_CENTER # ALIGN_RIGHT is buggy w/ big fonts
			spin_box.step = 1.0 if is_int else 0.1
			spin_box.rounded = is_int
			spin_box.min_value = 0.0
			spin_box.max_value = 100.0
			_set_overrides(spin_box, setting)
			spin_box.value = value
			spin_box.connect("value_changed", self, "_on_change", [setting, default_button, is_int])
			var line_edit := spin_box.get_line_edit()
			line_edit.context_menu_enabled = false
			line_edit.update()
		TYPE_STRING:
			var line_edit := LineEdit.new()
			setting_hbox.add_child(line_edit)
			line_edit.size_flags_horizontal = BoxContainer.SIZE_SHRINK_END
			line_edit.rect_min_size.x = 100.0
			_set_overrides(line_edit, setting)
			line_edit.text = value
			line_edit.connect("text_changed", self, "_on_change", [setting, default_button])
		TYPE_COLOR:
			var color_picker_button := ColorPickerButton.new()
			setting_hbox.add_child(color_picker_button)
			color_picker_button.rect_min_size.x = 60.0
			_set_overrides(color_picker_button, setting)
			color_picker_button.color = value
			color_picker_button.connect("color_changed", self, "_on_change", [setting, default_button])
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
	_confirm_changes.disabled = _settings_manager.is_cache_current()
	_restore_defaults.disabled = _settings_manager.is_all_defaults()

func _restore_default(setting: String) -> void:
	_settings_manager.restore_default(setting, true)
	call_deferred("_build_content")

func _on_change(value, setting: String, default_button: Button, convert_to_int := false) -> void:
	if convert_to_int:
		value = int(value)
	assert(DPRINT and prints("Set", setting, "=", value) or true)
	_settings_manager.change_current(setting, value, true)
	default_button.disabled = _settings_manager.is_default(setting)
	_confirm_changes.disabled = _settings_manager.is_cache_current()

func _on_restore_defaults() -> void:
	_settings_manager.restore_all_defaults(true)
	call_deferred("_build_content")

func _on_confirm_changes() -> void:
	_settings_manager.cache_now()
	hide()

func _on_cancel_changes() -> void:
	_settings_manager.restore_from_cache()
	hide()

func _open_hotkeys() -> void:
	if !is_connected("popup_hide", Global, "emit_signal"):
		connect("popup_hide", Global, "emit_signal", ["hotkeys_requested"], CONNECT_ONESHOT)
	_on_cancel()

func _settings_listener(setting: String, _value) -> void:
	if setting == "gui_size":
		yield(get_tree(), "idle_frame") # allow font changes
		hide()
		_open()

