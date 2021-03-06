# hotkeys_popup.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield
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
# Parent class provides public methods for adding, removing and moving
# subpanels and individual items within the panel.

extends CachedItemsPopup
class_name HotkeysPopup

const DPRINT := true

var key_box_min_size_x := 300

onready var _input_map_manager: InputMapManager = Global.program.InputMapManager
onready var _actions: Dictionary = _input_map_manager.current
var _hotkey_dialog: ConfirmationDialog = \
		preload("res://ivoyager/gui_admin/hotkey_dialog.tscn").instance()


func open() -> void:
	._open()

# *****************************************************************************

func _on_init():
	# Edit layout directly or use CachedItemsPopup functions at project init.
	layout = [
		[ # column 1; each dict is a subpanel
			{
				header = "LABEL_ADMIN",
				toggle_fullscreen = "LABEL_TOGGLE_FULLSCREEN",
				toggle_options = "LABEL_OPTIONS",
				toggle_hotkeys = "LABEL_HOTKEYS",
				load_game = "LABEL_LOAD_FILE",
				quick_load = "LABEL_QUICK_LOAD",
				save_as = "LABEL_SAVE_AS",
				quick_save = "LABEL_QUICK_SAVE",
				quit = "LABEL_QUIT",
				save_quit = "LABEL_SAVE_AND_QUIT",
			},
			{
				header = "LABEL_GUI",
				toggle_orbits = "LABEL_SHOW_HIDE_ORBITS",
				toggle_names = "LABEL_SHOW_HIDE_NAMES",
				toggle_symbols = "LABEL_SHOW_HIDE_SYMBOLS",
				toggle_all_gui = "LABEL_SHOW_HIDE_ALL_GUI",
				
				# Below two should be added by extension add_item(), if used.
				# See Planetarim project (planetarium/planetarium.gd).
#				cycle_next_panel = "LABEL_CYCLE_NEXT_PANEL",
#				cycle_prev_panel = "LABEL_CYCLE_LAST_PANEL",
				
				# Below UI controls have some engine hardcoding as of
				# Godot 3.2.2, so can't be user defined.
#				ui_up = "LABEL_GUI_UP",
#				ui_down = "LABEL_GUI_DOWN",
#				ui_left = "LABEL_GUI_LEFT",
#				ui_right = "LABEL_GUI_RIGHT",
			},
			{
				header = "LABEL_TIME",
				incr_speed = "LABEL_SPEED_UP",
				decr_speed = "LABEL_SLOW_DOWN",
				toggle_pause = "LABEL_PAUSE",
				reverse_time = "LABEL_REVERSE_TIME",
			},
		],
		[ # column 2
			{
				header = "LABEL_SELECTION",
				select_up = "LABEL_UP",
				select_down = "LABEL_DOWN",
				select_left = "LABEL_LAST",
				select_right = "LABEL_NEXT",
				select_forward = "LABEL_FORWARD",
				select_back = "LABEL_BACK",
				next_star = "LABEL_SELECT_SUN",
				next_planet = "LABEL_NEXT_PLANET",
				previous_planet = "LABEL_LAST_PLANET",
				next_nav_moon = "LABEL_NEXT_NAV_MOON",
				previous_nav_moon = "LABEL_LAST_NAV_MOON",
				next_moon = "LABEL_NEXT_ANY_MOON",
				previous_moon = "LABEL_LAST_ANY_MOON",
				# Below waiting for new code features
#				next_system = "Select System",
#				next_asteroid = "Next Asteroid",
#				previous_asteroid = "Last Asteroid",
#				next_comet = "Next Comet",
#				previous_comet = "Last Comet",
#				next_spacecraft = "Next Spacecraft",
#				previous_spacecraft = "Last Spacecraft",
			},
		],
		[ # column 3
			{
				header = "LABEL_CAMERA",
				camera_zoom_view = "LABEL_ZOOM_VIEW",
				camera_45_view = "LABEL_45_VIEW",
				camera_top_view = "LABEL_TOP_VIEW",
				camera_up = "LABEL_MOVE_UP",
				camera_down = "LABEL_MOVE_DOWN",
				camera_left = "LABEL_MOVE_LEFT",
				camera_right = "LABEL_MOVE_RIGHT",
				camera_in = "LABEL_MOVE_IN",
				camera_out = "LABEL_MOVE_OUT",
				recenter = "LABEL_RECENTER",
				pitch_up = "LABEL_PITCH_UP",
				pitch_down = "LABEL_PITCH_DOWN",
				yaw_left = "LABEL_YAW_LEFT",
				yaw_right = "LABEL_YAW_RIGHT",
				roll_left = "LABEL_ROLL_LEFT",
				roll_right = "LABEL_ROLL_RIGHT",
			},
			{
				header = "LABEL_DEVELOPER",
				emit_debug_signal = "LABEL_EMIT_DEBUG_SIGNAL",
			}
		],
	]

func _project_init() -> void:
	._project_init()
	Global.connect("hotkeys_requested", self, "open")
	if Global.disable_pause:
		remove_item("toggle_pause")
	if !Global.allow_time_reversal:
		remove_item("reverse_time")
	if !Global.allow_dev_tools:
		remove_subpanel("LABEL_DEVELOPER")
	if !Global.enable_save_load:
		remove_item("load_game")
		remove_item("quick_load")
		remove_item("save_as")
		remove_item("quick_save")
		remove_item("save_quit")
	if Global.disable_quit:
		remove_item("quit")

func _on_ready():
	._on_ready()
	_header_label.text = "LABEL_HOTKEYS"
	# Options button
	var options_button := Button.new()
	options_button.size_flags_horizontal = SIZE_SHRINK_END
	options_button.text = "BUTTON_OPTIONS"
	options_button.connect("pressed", self, "_open_options")
	_header_right.add_child(options_button)
	# Mouse-only GUI Nav checkbox
	var checkbox_res := preload("res://ivoyager/gui_widgets/mouse_only_gui_nav.tscn")
	var checkbox: CheckBox = checkbox_res.instance()
	_header_left.add_child(checkbox)
	# comment text below header
	var note_label := Label.new()
	note_label.autowrap = true
	note_label.anchor_left = 0
	note_label.anchor_right = 1
	note_label.text = "TXT_GUI_HOTKEY_NOTE"
	$VBox.add_child_below_node($VBox/TopHBox, note_label)
	# hotkey dialog
	add_child(_hotkey_dialog)
	_hotkey_dialog.connect("hotkey_confirmed", self, "_on_hotkey_confirmed")

func _on_content_built() -> void:
	_confirm_changes.disabled = _input_map_manager.is_cache_current()
	_restore_defaults.disabled = _input_map_manager.is_all_defaults()

func _build_item(action: String, action_label_str: String) -> HBoxContainer:
	var action_hbox := HBoxContainer.new()
	action_hbox.rect_min_size.x = key_box_min_size_x
	var action_label := Label.new()
	action_hbox.add_child(action_label)
	action_label.size_flags_horizontal = BoxContainer.SIZE_EXPAND_FILL
	action_label.text = action_label_str
	var index := 0
	var scancodes := _input_map_manager.get_scancodes_w_mods_for_action(action)
	for scancode in scancodes:
		var key_button := Button.new()
		action_hbox.add_child(key_button)
		key_button.text = OS.get_scancode_string(scancode)
		key_button.connect("pressed", _hotkey_dialog, "open", [action, index, action_label_str,
				key_button.text, layout])
		index += 1
	var empty_key_button := Button.new()
	action_hbox.add_child(empty_key_button)
	empty_key_button.connect("pressed", _hotkey_dialog, "open", [action, index, action_label_str,
			"", layout])
	var default_button := Button.new()
	action_hbox.add_child(default_button)
	default_button.text = "!"
	default_button.disabled = _input_map_manager.is_default(action)
	default_button.connect("pressed", self, "_restore_default", [action])
	return action_hbox

func _restore_default(action: String) -> void:
	_input_map_manager.restore_default(action, true)
	call_deferred("_build_content")

func _on_hotkey_confirmed(action: String, index: int, scancode: int,
		control: bool, alt: bool, shift: bool, meta: bool) -> void:
	if scancode == -1:
		_input_map_manager.remove_event_dict_by_index(action, "InputEventKey", index, true)
	else:
		var event_dict := {event_class = "InputEventKey", scancode = scancode}
		if control:
			event_dict.control = true
		if alt:
			event_dict.alt = true
		if shift:
			event_dict.shift = true
		if meta:
			event_dict.meta = true
		print("Set ", action, ": ", event_dict)
		_input_map_manager.set_action_event_dict(action, event_dict, index, true)
	_build_content()

func _on_restore_defaults() -> void:
	_input_map_manager.restore_all_defaults(true)
	call_deferred("_build_content")

func _on_confirm_changes() -> void:
	_input_map_manager.cache_now()
	hide()

func _on_cancel_changes() -> void:
	_input_map_manager.restore_from_cache()
	hide()

func _open_options() -> void:
	if !is_connected("popup_hide", Global, "emit_signal"):
		connect("popup_hide", Global, "emit_signal", ["options_requested"], CONNECT_ONESHOT)
	_on_cancel()
