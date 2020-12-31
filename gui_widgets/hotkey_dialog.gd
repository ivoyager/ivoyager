# hotkey_dialog.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
# Copyright (c) 2017-2020 Charlie Whitfield
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
# GUI widget.

extends ConfirmationDialog
class_name HotkeyDialog
const SCENE := "res://ivoyager/gui_widgets/hotkey_dialog.tscn"

signal hotkey_confirmed(action, scancode, control, alt, shift, meta)

var _action: String
var _index: int
var _layout: Array
var _input_event_key: InputEventKey
var _in_use_color: Color = Global.colors.danger
var _ok_color: Color = Global.colors.normal
onready var _key_label: Label = $HBox/KeyLabel
onready var _delete: Button = $HBox/Delete
onready var _ok_button: Button = get_ok()
onready var _tree := get_tree()
onready var _input_handler: InputHandler = Global.program.InputHandler
onready var _input_map_manager: InputMapManager = Global.program.InputMapManager

func open(action: String, index: int, action_label_str: String, key_as_text: String, layout: Array) -> void:
	_action = action
	_index = index
	_layout = layout
	_input_event_key = null
	_delete.visible = bool(key_as_text)
	window_title = action_label_str
	_ok_button.disabled = true
	_key_label.text = key_as_text
	_key_label.set("custom_colors/font_color", _ok_color)
	set_process_input(true)
	_input_handler.suppress(self)
	popup_centered()

func _ready():
	connect("confirmed", self, "_on_confirmed")
	connect("popup_hide", self, "_on_popup_hide")
	_delete.connect("pressed", self, "_on_delete")
	set_process_input(false)
	_ok_button.disabled = true

func _on_delete():
	_key_label.text = ""
	_delete.hide()
	_input_event_key = null
	_ok_button.disabled = false

func _on_confirmed() -> void:
#	print("confirmed")
	if !_input_event_key: # delete existing hotkey
		emit_signal("hotkey_confirmed", _action, _index, -1, false, false, false, false)
		return
	var scancode := _input_event_key.scancode
	assert(scancode == _input_map_manager.strip_scancode_mods(scancode))
	var control := _input_event_key.control
	var alt := _input_event_key.alt
	var shift := _input_event_key.shift
	var meta := _input_event_key.meta
	emit_signal("hotkey_confirmed", _action, _index, scancode, control, alt, shift, meta)

func _on_popup_hide() -> void:
#	print("hide")
	set_process_input(false)
	_input_handler.unsuppress(self)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	_tree.set_input_as_handled() # eat all keys
	if event.is_action_pressed("ui_cancel"):
		hide()
		return
	if event.is_action_pressed("ui_accept"):
		if !_ok_button.disabled:
			hide()
			_on_confirmed()
		return
	if !event.is_pressed():
		return
	var scancode_w_mods: int = event.get_scancode_with_modifiers()
	if !_scancode_is_valid(scancode_w_mods):
		return
	var key_as_text := OS.get_scancode_string(scancode_w_mods)
	if _scancode_is_reserved(scancode_w_mods):
		_key_label.text = key_as_text + "\n(Reserved)"
		_key_label.set("custom_colors/font_color", _in_use_color)
		_input_event_key = null
		_ok_button.disabled = true
		_delete.hide()
	elif _scancode_is_present_action(scancode_w_mods):
		_key_label.text = key_as_text
		_key_label.set("custom_colors/font_color", _ok_color)
		_input_event_key = null
		_ok_button.disabled = true
		_delete.show()
	elif _scancode_is_available(scancode_w_mods):
		_key_label.text = key_as_text
		_key_label.set("custom_colors/font_color", _ok_color)
		_input_event_key = event
		_ok_button.disabled = false
		_delete.show()
	else:
		var other_action_text := _get_scancode_action_text(scancode_w_mods)
		_key_label.text = key_as_text + "\n(Used by " + other_action_text + ")"
		_key_label.set("custom_colors/font_color", _in_use_color)
		_input_event_key = null
		_ok_button.disabled = true
		_delete.hide()

func _scancode_is_valid(scancode: int) -> bool:
	scancode = _input_map_manager.strip_scancode_mods(scancode)
	return ![KEY_SHIFT, KEY_CONTROL, KEY_ALT, KEY_META].has(scancode)

func _scancode_is_reserved(scancode: int) -> bool:
	scancode = _input_map_manager.strip_scancode_mods(scancode)
	return _input_map_manager.reserved_scancodes.has(scancode)

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
		for dict in column_array:
			if dict.has(scancode_action):
				return false
	return true

func _get_scancode_action_text(scancode_w_mods: int) -> String:
	var actions_by_scancode_w_mods: Dictionary = _input_map_manager.actions_by_scancode_w_mods
	if !actions_by_scancode_w_mods.has(scancode_w_mods):
		return "unknown"
	var scancode_action: String = actions_by_scancode_w_mods[scancode_w_mods]
	for column_array in _layout:
		for dict in column_array:
			if dict.has(scancode_action):
				var header := tr(dict.header)
				var item_name := tr(dict[scancode_action])
				return header + " / " + item_name
	return "unknown"
	
