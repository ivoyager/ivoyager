# hotkey_dialog.gd
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
class_name IVHotkeyDialog
extends ConfirmationDialog
const SCENE := "res://ivoyager/gui_popups/hotkey_dialog.tscn"

# Used by IVHotkeysPopup.

signal hotkey_confirmed(action, keycode, control, alt, shift, meta)

var _in_use_color: Color = IVGlobal.colors.danger
var _ok_color: Color = IVGlobal.colors.normal
var _input_event_key: InputEventKey
var _action: String
var _index: int
var _layout: Array

@onready var _dialog_label: Label = %DialogLabel
@onready var _key_label: Label = %KeyLabel
@onready var _key_delete: Button = %KeyDelete
@onready var _ok_button: Button = get_ok_button()
@onready var _input_map_manager: IVInputMapManager = IVGlobal.program.InputMapManager


func _ready():
	confirmed.connect(_on_confirmed)
	_key_delete.pressed.connect(_on_key_delete)
	focus_exited.connect(_keep_focus)
	process_mode = PROCESS_MODE_ALWAYS
	transient = false
	always_on_top = true
	_ok_button.disabled = true


func _unhandled_key_input(event: InputEvent) -> void:
	set_input_as_handled() # eat all keys
	if !event.is_pressed():
		return
	if event.is_action_pressed(&"ui_cancel"):
		return
	if event.is_action_pressed(&"ui_accept"):
		return
	var key_event := event as InputEventKey
	var scancode_w_mods: int = key_event.get_keycode_with_modifiers()
	if !_scancode_is_valid(scancode_w_mods):
		return
	_dialog_label.text = "LABEL_PRESS_A_KEY_TO_CHANGE"
	var key_as_text := OS.get_keycode_string(scancode_w_mods)
	if _scancode_is_reserved(scancode_w_mods):
		_key_label.text = tr("TXT_KEY_RESERVED_CONSTRUCTOR") % key_as_text
		_key_label.set("theme_override_colors/font_color", _in_use_color)
		_input_event_key = null
		_ok_button.disabled = true
		_key_delete.hide()
	elif _scancode_is_present_action(scancode_w_mods):
		_key_label.text = key_as_text
		_key_label.set("theme_override_colors/font_color", _ok_color)
		_input_event_key = null
		_ok_button.disabled = true
		_key_delete.show()
	elif _scancode_is_available(scancode_w_mods):
		_key_label.text = key_as_text
		_key_label.set("theme_override_colors/font_color", _ok_color)
		_input_event_key = key_event
		_ok_button.disabled = false
		_key_delete.show()
	else:
		var other_action_text := _get_scancode_action_text(scancode_w_mods)
		
		_key_label.text = tr("TXT_KEY_USED_BY_CONSTRUCTOR") % [key_as_text, other_action_text]
		_key_label.set("theme_override_colors/font_color", _in_use_color)
		_input_event_key = null
		_ok_button.disabled = true
		_key_delete.hide()


func open(action: String, index: int, action_label_str: String, key_as_text: String, layout: Array
		) -> void:
	_action = action
	_index = index
	_layout = layout
	_input_event_key = null
	if key_as_text:
		_dialog_label.text = "LABEL_PRESS_A_KEY_TO_CHANGE"
		_key_delete.show()
	else:
		_dialog_label.text = "LABEL_PRESS_A_KEY_TO_ADD"
		_key_delete.hide()
	title = action_label_str
	_ok_button.disabled = true
	_key_label.text = key_as_text
	_key_label.set("theme_override_colors/font_color", _ok_color)
	popup_centered()
	_keep_focus()


func _on_key_delete():
	_dialog_label.text = "LABEL_PRESS_A_KEY_TO_ADD"
	_key_label.text = ""
	_key_delete.hide()
	_input_event_key = null
	_ok_button.disabled = false


func _on_confirmed() -> void:
	if !_input_event_key: # delete existing hotkey
		hotkey_confirmed.emit(_action, _index, -1, false, false, false, false)
		return
	var keycode := _input_event_key.keycode
	assert(keycode == _input_map_manager.strip_scancode_mods(keycode))
	var control := _input_event_key.ctrl_pressed
	var alt := _input_event_key.alt_pressed
	var shift := _input_event_key.shift_pressed
	var meta := _input_event_key.meta_pressed
	hotkey_confirmed.emit(_action, _index, keycode, control, alt, shift, meta)


func _scancode_is_valid(keycode: int) -> bool:
	keycode = _input_map_manager.strip_scancode_mods(keycode)
	return ![KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META].has(keycode)


func _scancode_is_reserved(keycode: int) -> bool:
	keycode = _input_map_manager.strip_scancode_mods(keycode)
	return _input_map_manager.reserved_scancodes.has(keycode)


func _scancode_is_present_action(scancode_w_mods: int) -> bool:
	var actions_by_scancode_w_mods: Dictionary = _input_map_manager.actions_by_scancode_w_mods
	if !actions_by_scancode_w_mods.has(scancode_w_mods):
		return false
	var scancode_action: String = actions_by_scancode_w_mods[scancode_w_mods]
	return scancode_action == _action


func _scancode_is_available(scancode_w_mods: int) -> bool:
	var actions_by_scancode_w_mods: Dictionary = _input_map_manager.actions_by_scancode_w_mods
	if !actions_by_scancode_w_mods.has(scancode_w_mods):
		return true
	var scancode_action: String = actions_by_scancode_w_mods[scancode_w_mods]
	# prohibit only if it is in layout (user can overwrite hidden actions)
	for column_array in _layout:
		for item in column_array:
			var dict: Dictionary = item
			if dict.has(scancode_action):
				return false
	return true


func _get_scancode_action_text(scancode_w_mods: int) -> String:
	var actions_by_scancode_w_mods: Dictionary = _input_map_manager.actions_by_scancode_w_mods
	if !actions_by_scancode_w_mods.has(scancode_w_mods):
		return "unknown"
	var scancode_action: String = actions_by_scancode_w_mods[scancode_w_mods]
	for column_array in _layout:
		for item in column_array:
			var dict: Dictionary = item
			if dict.has(scancode_action):
				var header := tr(dict.header)
				var item_name := tr(dict[scancode_action])
				return header + " / " + item_name
	return "unknown"


func _keep_focus() -> void:
	await get_tree().process_frame
	if !has_focus():
		grab_focus()

