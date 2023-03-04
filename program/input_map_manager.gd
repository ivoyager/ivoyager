# input_map_manager.gd
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
class_name IVInputMapManager
extends IVCacheManager

# We define InputMap actions here to decouple version control for ivoyager and
# extensions/addons (i.e., get them out of project.godot), and to allow player
# modification via IVHotkeysPopup. Non-default actions are persisted in
# <cache_dir>/<cache_file_name> (specified below).
#
# This node and IVHotkeysPopup are unaware of actions defined in project.godot.

# project vars
var reserved_scancodes := [] # user can't overwrite w/ or w/out key mods
var event_classes := { # we'll expand this as needed
	"InputEventKey" : InputEventKey,
	"InputEventJoypadButton" : InputEventJoypadButton,
	}

# read-only!
var actions_by_scancode_w_mods := {}


# *****************************************************************************

func _on_init() -> void:
	# project vars - modify on signal project_objects_instantiated
	cache_file_name = "input_map.vbinary"
	defaults = {
		# Each "event_dict" must have event_class; all other keys are properties
		# to be set on the InputEvent. Don't remove an action -- just give it an
		# empty array to disable.
		#
		# Note: I'M TOTALLY IGNORANT ABOUT JOYPAD CONTROLLERS! SOMEONE PLEASE
		# HELP!
		#
		# Note 2: ui_xxx actions have hard-coding problems; see issue #43663.
		# We can't set them here and (even in godot.project) we can't use key
		# modifiers. Hopefully in 4.0 these can be fully customized.
		
#		ui_up = [
#			{event_class = "InputEventKey", scancode = KEY_UP, alt = true},
#			{event_class = "InputEventJoypadButton", button_index = 12},
#			],
#		ui_down = [
#			{event_class = "InputEventKey", scancode = KEY_DOWN, alt = true},
#			{event_class = "InputEventJoypadButton", button_index = 13},
#			],
#		ui_left = [
#			{event_class = "InputEventKey", scancode = KEY_LEFT, alt = true},
#			{event_class = "InputEventJoypadButton", button_index = 14},
#			],
#		ui_right = [
#			{event_class = "InputEventKey", scancode = KEY_RIGHT, alt = true},
#			{event_class = "InputEventJoypadButton", button_index = 15},
#			],
		
		camera_up = [
			{event_class = "InputEventKey", scancode = KEY_UP},
			{event_class = "InputEventKey", scancode = KEY_UP, control = true},
			],
		camera_down = [
			{event_class = "InputEventKey", scancode = KEY_DOWN},
			{event_class = "InputEventKey", scancode = KEY_DOWN, control = true},
			],
		camera_left = [
			{event_class = "InputEventKey", scancode = KEY_LEFT},
			{event_class = "InputEventKey", scancode = KEY_LEFT, control = true},
			],
		camera_right = [
			{event_class = "InputEventKey", scancode = KEY_RIGHT},
			{event_class = "InputEventKey", scancode = KEY_RIGHT, control = true},
			],
		camera_in = [{event_class = "InputEventKey", scancode = KEY_PAGEDOWN}],
		camera_out = [{event_class = "InputEventKey", scancode = KEY_PAGEUP}],
		
		recenter = [
			{event_class = "InputEventKey", scancode = KEY_KP_5},
			{event_class = "InputEventKey", scancode = KEY_D},
			],
		pitch_up = [
			{event_class = "InputEventKey", scancode = KEY_KP_8},
			{event_class = "InputEventKey", scancode = KEY_E},
			],
		pitch_down = [
			{event_class = "InputEventKey", scancode = KEY_KP_2},
			{event_class = "InputEventKey", scancode = KEY_C},
			],
		yaw_left = [
			{event_class = "InputEventKey", scancode = KEY_KP_4},
			{event_class = "InputEventKey", scancode = KEY_S},
			],
		yaw_right = [
			{event_class = "InputEventKey", scancode = KEY_KP_6},
			{event_class = "InputEventKey", scancode = KEY_F},
			],
		roll_left = [
			{event_class = "InputEventKey", scancode = KEY_KP_1},
			{event_class = "InputEventKey", scancode = KEY_X},
			],
		roll_right = [
			{event_class = "InputEventKey", scancode = KEY_KP_3},
			{event_class = "InputEventKey", scancode = KEY_V},
			],
		
		select_up = [{event_class = "InputEventKey", scancode = KEY_UP, shift = true}],
		select_down = [{event_class = "InputEventKey", scancode = KEY_DOWN, shift = true}],
		select_left = [{event_class = "InputEventKey", scancode = KEY_LEFT, shift = true}],
		select_right = [{event_class = "InputEventKey", scancode = KEY_RIGHT, shift = true}],
		select_forward = [{event_class = "InputEventKey", scancode = KEY_PERIOD}],
		select_back = [{event_class = "InputEventKey", scancode = KEY_COMMA}],
		next_system = [{event_class = "InputEventKey", scancode = KEY_Y}],
		previous_system = [{event_class = "InputEventKey", scancode = KEY_Y, shift = true}],
		next_star = [{event_class = "InputEventKey", scancode = KEY_T}],
		previous_star = [{event_class = "InputEventKey", scancode = KEY_T, shift = true}],
		next_planet = [{event_class = "InputEventKey", scancode = KEY_P}],
		previous_planet = [{event_class = "InputEventKey", scancode = KEY_P, shift = true}],
		next_nav_moon = [{event_class = "InputEventKey", scancode = KEY_M}],
		previous_nav_moon = [{event_class = "InputEventKey", scancode = KEY_M, shift = true}],
		next_moon = [{event_class = "InputEventKey", scancode = KEY_N}],
		previous_moon = [{event_class = "InputEventKey", scancode = KEY_N, shift = true}],
		next_asteroid = [{event_class = "InputEventKey", scancode = KEY_H}],
		previous_asteroid = [{event_class = "InputEventKey", scancode = KEY_H, shift = true}],
		next_asteroid_group = [{event_class = "InputEventKey", scancode = KEY_G}],
		previous_asteroid_group = [{event_class = "InputEventKey", scancode = KEY_G, shift = true}],
		next_comet = [{event_class = "InputEventKey", scancode = KEY_J}],
		previous_comet = [{event_class = "InputEventKey", scancode = KEY_J, shift = true}],
		next_spacecraft = [{event_class = "InputEventKey", scancode = KEY_K}],
		previous_spacecraft = [{event_class = "InputEventKey", scancode = KEY_K, shift = true}],
		toggle_orbits = [{event_class = "InputEventKey", scancode = KEY_O}],
		toggle_symbols = [{event_class = "InputEventKey", scancode = KEY_I}],
		toggle_names = [{event_class = "InputEventKey", scancode = KEY_L}],
		toggle_all_gui = [{event_class = "InputEventKey", scancode = KEY_G, control = true}],
		toggle_fullscreen = [{event_class = "InputEventKey", scancode = KEY_F, control = true}],
		toggle_pause = [{event_class = "InputEventKey", scancode = KEY_SPACE}],
		incr_speed = [
			{event_class = "InputEventKey", scancode = KEY_EQUAL},
			{event_class = "InputEventKey", scancode = KEY_BRACERIGHT},
			{event_class = "InputEventKey", scancode = KEY_BRACKETRIGHT}, # grrrr. Browsers!
			],
		decr_speed = [
			{event_class = "InputEventKey", scancode = KEY_MINUS},
			{event_class = "InputEventKey", scancode = KEY_BRACELEFT},
			{event_class = "InputEventKey", scancode = KEY_BRACKETLEFT},
			],
		reverse_time = [
			{event_class = "InputEventKey", scancode = KEY_BACKSPACE},
			{event_class = "InputEventKey", scancode = KEY_BACKSLASH},
			],
			
		toggle_options = [{event_class = "InputEventKey", scancode = KEY_O, control = true}],
		toggle_hotkeys = [{event_class = "InputEventKey", scancode = KEY_H, control = true}],
		load_game = [{event_class = "InputEventKey", scancode = KEY_L, control = true}],
		quick_load = [{event_class = "InputEventKey", scancode = KEY_L, alt = true}],
		save_as = [{event_class = "InputEventKey", scancode = KEY_S, control = true}],
		quick_save = [{event_class = "InputEventKey", scancode = KEY_S, alt = true}],
		quit = [{event_class = "InputEventKey", scancode = KEY_Q, control = true}],
		save_quit = [{event_class = "InputEventKey", scancode = KEY_Q, alt = true}],
		
		# Used by ProjectCyclablePanels GUI mod (which is used by Planetarium)
		cycle_next_panel = [{event_class = "InputEventKey", scancode = KEY_QUOTELEFT}],
		cycle_prev_panel = [{event_class = "InputEventKey", scancode = KEY_QUOTELEFT, shift = true}],
		
	}
	
	current = {}


func _project_init() -> void:
	._project_init()
	_init_actions()


func _init_actions() -> void:
	for action in current:
		var scancodes := get_scancodes_w_mods_for_action(action)
		for scancode_w_mods in scancodes:
#			assert(!actions_by_scancode_w_mods.has(scancode_w_mods))
			actions_by_scancode_w_mods[scancode_w_mods] = action
		_set_input_map(action)


# *****************************************************************************

func set_action_event_dict(action: String, event_dict: Dictionary, index: int,
		suppress_caching := false) -> void:
	# index can be arbitrarily large to add to end.
	# If suppress_caching = true, be sure to call cache_now() later.
	var events_array: Array = current[action]
	_about_to_change_current(action) # un-indexes scancodes, if any
	var event_class: String = event_dict.event_class
	var event_array_index := get_event_array_index(action, event_class, index)
	if event_array_index == events_array.size():
		events_array.append(event_dict)
	else:
		events_array[event_array_index] = event_dict
	_on_change_current(action)
	if !suppress_caching:
		cache_now()


func get_event_array_index(action: String, event_class: String, index: int) -> int:
	# index can be arbitrarily large
	var events_array: Array = current[action]
	var i := 0
	var class_index := 0
	while i < events_array.size():
		var event_dict: Dictionary = events_array[i]
		if event_dict.event_class == event_class:
			if index == class_index:
				return i
			class_index += 1
		i += 1
	return i # size of events_array


func get_event_dicts(action: String, event_class: String) -> Array:
	var result := []
	var events_array: Array = current[action]
	for event_dict in events_array:
		if event_dict.event_class == event_class:
			result.append(event_dict)
	return result


func remove_event_dict_by_index(action: String, event_class: String, index: int,
		suppress_caching := false) -> void:
	# index is for event dicts of specified event_class (not array index!)
	var scancodes_w_mods: Array
	if event_class == "InputEventKey":
		scancodes_w_mods = get_scancodes_w_mods_for_action(action)
	var events_array: Array = current[action]
	var i := 0
	var class_index := 0
	while i < events_array.size():
		var event_dict: Dictionary = events_array[i]
		if event_dict.event_class == event_class:
			if index == class_index:
				events_array.remove(i)
				if event_class == "InputEventKey":
					var scancode_w_mods: int = scancodes_w_mods[index]
					actions_by_scancode_w_mods.erase(scancode_w_mods)
				break
			class_index += 1
		i += 1
	_on_change_current(action)
	if !suppress_caching:
		cache_now()


func remove_event_dict_by_match(action: String, event_class: String, scancode_w_mods := -1,
		button_index := -1, suppress_caching := false) -> void:
	# NOT TESTED!!!
	# supply scancode_w_mods or button_index, depending on event_class
	var events_array: Array = current[action]
	var i := 0
	while i < events_array.size():
		var event_dict: Dictionary = events_array[i]
		if event_dict.event_class == event_class:
			if event_class == "InputEventKey":
				if scancode_w_mods == get_scancode_w_mods_for_event_dict(event_dict):
					events_array.remove(i)
					actions_by_scancode_w_mods.erase(scancode_w_mods)
					break
			elif event_class == "InputEventJoypadButton":
				if button_index == event_dict.button_index:
					events_array.remove(i)
					break
		i += 1
	if !suppress_caching:
		cache_now()


func get_scancodes_w_mods_for_action(action: String) -> Array:
	var scancodes := []
	var events_array: Array = current[action]
	for event_dict in events_array:
		if event_dict.event_class == "InputEventKey":
			var scancode := get_scancode_w_mods_for_event_dict(event_dict)
			scancodes.append(scancode)
	return scancodes


static func get_scancode_w_mods_for_event_dict(event_dict: Dictionary) -> int:
	assert(event_dict.event_class == "InputEventKey")
	var scancode: int = event_dict.scancode
	var shift: bool = event_dict.get("shift", false)
	var control: bool = event_dict.get("control", false)
	var alt: bool = event_dict.get("alt", false)
	var meta: bool = event_dict.get("meta", false)
	return get_scancode_w_mods(scancode, shift, control, alt, meta)


static func get_scancode_w_mods(scancode: int, shift := false, control := false,
		alt := false, meta := false) -> int:
	if shift:
		scancode |= KEY_MASK_SHIFT
	if control:
		scancode |= KEY_MASK_CTRL
	if alt:
		scancode |= KEY_MASK_ALT
	if meta:
		scancode |= KEY_MASK_META
	return scancode


static func strip_scancode_mods(scancode: int) -> int:
	# Note: InputEventKey.scancode is already stripped.
	scancode &= ~KEY_MASK_SHIFT
	scancode &= ~KEY_MASK_CTRL
	scancode &= ~KEY_MASK_ALT
	scancode &= ~KEY_MASK_META
	return scancode


# *****************************************************************************

func _about_to_change_current(action: String) -> void:
	var scancodes := get_scancodes_w_mods_for_action(action)
	for scancode_w_mods in scancodes:
		actions_by_scancode_w_mods.erase(scancode_w_mods)


func _on_change_current(action: String) -> void:
	var scancodes := get_scancodes_w_mods_for_action(action)
	for scancode_w_mods in scancodes:
		actions_by_scancode_w_mods[scancode_w_mods] = action
	_set_input_map(action)


func _set_input_map(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)
	var events_array: Array = current[action]
	for event_dict in events_array:
		var event: InputEvent = event_classes[event_dict.event_class].new()
		for key in event_dict:
			if key != "event_class":
				event.set(key, event_dict[key])
		InputMap.action_add_event(action, event)
