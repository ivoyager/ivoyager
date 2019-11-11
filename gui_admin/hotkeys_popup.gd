# hotkeys_popup.gd
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
class_name HotkeysPopup

const DPRINT := true

var key_box_min_size_x := 300

onready var _input_map_manager: InputMapManager = Global.objects.InputMapManager
onready var _actions: Dictionary = _input_map_manager.current
var _hotkey_dialog: HotkeyDialog


func _on_init():
	# Edit layout directly or use CachedItemsPopup functions at project init.
	layout = [
		[ # column 1; each dict is a subpanel
			{
				header = "Admin",
				toggle_options = "Options",
				toggle_hotkeys = "Hotkeys",
				load_game = "Load File",
				quick_load = "Quick Load",
				save_as = "Save As",
				quick_save = "Quick Save",
				quit = "Quit",
				save_quit = "Save & Quit",
			},
			{
				header = "Time",
				incr_speed = "Speed up",
				decr_speed = "Slow down",
				toggle_pause_or_real_time = "Pause (or real-time)",
				reverse_time = "Reverse time",
			},
			{
				header = "Show/Hide",
				toggle_orbits = "Orbits",
				toggle_icons = "Icons",
				toggle_labels = "Labels",
				toggle_full_screen = "All GUI",
			},
			{
				header = "GUI",
				obtain_gui_focus = "Obtain GUI focus",
				release_gui_focus = "Release GUI focus",
			},
		],
		[ # column 2
			{
				header = "Selection",
				select_up = "Up",
				select_down = "Down",
				select_left = "Last",
				select_right = "Next",
				select_forward = "Select Forward",
				select_back = "Select Back",
				next_system = "Select System",
				next_star = "Select Sun",
				next_planet = "Next Planet",
				previous_planet = "Last Planet",
				next_moon = "Next Moon",
				previous_moon = "Last Moon",
				next_asteroid = "Next Asteroid",
				previous_asteroid = "Last Asteroid",
				next_comet = "Next Comet",
				previous_comet = "Last Comet",
				next_spacecraft = "Next Spacecraft",
				previous_spacecraft = "Last Spacecraft",
			},
		],
		[ # column 3
			{
				header = "Camera",
				camera_zoom_view = "Go to zoom view",
				camera_45_view = "Go to 45 view",
				camera_top_view = "Go to top view",
				camera_up = "Move up",
				camera_down = "Move down",
				camera_left = "Move left",
				camera_right = "Move right",
				camera_in = "Move in",
				camera_out = "Move out",
				recenter = "Recenter",
				pitch_up = "Pitch up",
				pitch_down = "Pitch down",
				yaw_left = "Yaw left",
				yaw_right = "Yaw right",
				roll_left = "Roll left",
				roll_right = "Roll right",
			},
			{
				header = "Developer",
				write_debug_logs_now = "Force log print",
				open_asteroid_importer = "AsteroidImporter",
				open_wiki_bot = "WikiBot",
			}
		],
	]

func project_init() -> void:
	.project_init()
	Global.connect("hotkeys_requested", self, "_open")
	if !Global.allow_time_reversal:
		remove_item("reverse_time")
	if !Global.allow_dev_tools:
		remove_subpanel("Developer")

func _on_ready():
	._on_ready()
	_header.text = "Hotkeys"
	_hotkey_dialog = SaverLoader.make_object_or_scene(HotkeyDialog)
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
	var scancodes := _input_map_manager.get_scancodes_with_modifiers(action)
	for scancode in scancodes:
		var key_button := Button.new()
		action_hbox.add_child(key_button)
		key_button.text = OS.get_scancode_string(scancode)
		key_button.connect("pressed", _hotkey_dialog, "open", [action, index, action_label_str, key_button.text, layout])
		index += 1
	var empty_key_button := Button.new()
	action_hbox.add_child(empty_key_button)
	empty_key_button.connect("pressed", _hotkey_dialog, "open", [action, index, action_label_str, "", layout])
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
		_input_map_manager.remove_event_dict(action, "InputEventKey", index, true)
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
		_input_map_manager.set_action_event_dict(action, event_dict, "InputEventKey", index, true)
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

































