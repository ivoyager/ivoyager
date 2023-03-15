# body_huds_state.gd
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
class_name IVBodyHUDsState
extends Node

# Maintains visibility and color state for Body HUDs. Body HUDs must connect
# and set their own visibility on changed signals.
#
# A complete set of group 'keys' is defined in data table 'visual_groups.tsv'
# based on exclusive bit flags in IVEnums.BodyFlags.
#
# See also IVSBGHUDsState for SmallBodiesGroup HUDs.

signal visibility_changed()
signal color_changed()


const NULL_COLOR := Color.black
const BodyFlags: Dictionary = IVEnums.BodyFlags

const PERSIST_MODE := IVEnums.PERSIST_PROPERTIES_ONLY
const PERSIST_PROPERTIES := [
	"name_visible_flags",
	"symbol_visible_flags",
	"orbit_visible_flags",
	"orbit_colors",
]


# persisted - read-only!
var name_visible_flags := 0 # exclusive w/ symbol_visible_flags
var symbol_visible_flags := 0 # exclusive w/ name_visible_flags
var orbit_visible_flags := 0
var orbit_colors := {} # must have full key set from all_flags bits!

# project vars - set at project init
var fallback_orbit_color := Color("FE9C33") # orange

# imported from visual_groups.tsv - ready-only!
var all_flags := 0
var default_name_visible_flags := 0 # exclusive w/ symbol_visible_flags
var default_symbol_visible_flags := 0 # exclusive w/ name_visible_flags
var default_orbit_visible_flags := 0
var default_orbit_colors := {}


onready var _tree := get_tree()



func _project_init() -> void:
	IVGlobal.connect("simulator_exited", self, "_set_current_to_default")
	IVGlobal.connect("update_gui_requested", self, "_signal_all_changed")
	var table_reader: IVTableReader = IVGlobal.program.TableReader
	for row in table_reader.get_n_rows("visual_groups"):
		var body_flag := table_reader.get_int("visual_groups", "body_flag", row)
		var is_name_visible := table_reader.get_bool("visual_groups", "default_name_visible", row)
		var is_symbol_visible := table_reader.get_bool("visual_groups", "default_symbol_visible", row)
		var is_orbit_visible := table_reader.get_bool("visual_groups", "default_orbit_visible", row)
		var orbit_color_str := table_reader.get_string("visual_groups", "default_orbit_color", row)
		
		all_flags |= body_flag
		if is_name_visible:
			default_name_visible_flags |= body_flag
		if is_symbol_visible:
			default_symbol_visible_flags |= body_flag
		if is_orbit_visible:
			default_orbit_visible_flags |= body_flag
		default_orbit_colors[body_flag] = Color(orbit_color_str)
	
	_set_current_to_default()


func _unhandled_key_input(event: InputEventKey):
	# Only Body HUDs, for now...
	if event.is_action_pressed("toggle_orbits"):
		set_all_orbits_visibility(bool(orbit_visible_flags != all_flags))
	elif event.is_action_pressed("toggle_symbols"):
		set_all_symbols_visibility(bool(symbol_visible_flags != all_flags))
	elif event.is_action_pressed("toggle_names"):
		set_all_names_visibility(bool(name_visible_flags != all_flags))
	else:
		return # input NOT handled!
	_tree.set_input_as_handled()



# visibility

func hide_all() -> void:
	if !orbit_visible_flags and !name_visible_flags and !symbol_visible_flags:
		return
	orbit_visible_flags = 0
	name_visible_flags = 0
	symbol_visible_flags = 0
	emit_signal("visibility_changed")


func set_default_visibilities() -> void:
	if (name_visible_flags == default_name_visible_flags
			and symbol_visible_flags == default_symbol_visible_flags
			and orbit_visible_flags == default_orbit_visible_flags):
		return
	name_visible_flags = default_name_visible_flags
	symbol_visible_flags = default_symbol_visible_flags
	orbit_visible_flags = default_orbit_visible_flags
	emit_signal("visibility_changed")


func is_name_visible(body_flags: int, match_all := false) -> bool:
	if match_all:
		body_flags &= all_flags
		return body_flags & name_visible_flags == body_flags
	return bool(body_flags & name_visible_flags) # match any


func is_symbol_visible(body_flags: int, match_all := false) -> bool:
	if match_all:
		body_flags &= all_flags
		return body_flags & symbol_visible_flags == body_flags
	return bool(body_flags & symbol_visible_flags) # match any


func is_orbit_visible(body_flags: int, match_all := false) -> bool:
	if match_all:
		body_flags &= all_flags
		return body_flags & orbit_visible_flags == body_flags
	return bool(body_flags & orbit_visible_flags) # match any


func is_all_names_visible() -> bool:
	return name_visible_flags == all_flags


func is_all_symbols_visible() -> bool:
	return symbol_visible_flags == all_flags


func is_all_orbits_visible() -> bool:
	return orbit_visible_flags == all_flags


func set_name_visibility(body_flags: int, is_show: bool) -> void:
	body_flags &= all_flags
	if is_show:
		if name_visible_flags & body_flags == body_flags:
			return
		name_visible_flags |= body_flags
		symbol_visible_flags &= ~body_flags # exclusive
		emit_signal("visibility_changed")
	else:
		if name_visible_flags & body_flags == 0:
			return
		name_visible_flags &= ~body_flags
		emit_signal("visibility_changed")


func set_symbol_visibility(body_flags: int, is_show: bool) -> void:
	body_flags &= all_flags
	if is_show:
		if symbol_visible_flags & body_flags == body_flags:
			return
		symbol_visible_flags |= body_flags
		name_visible_flags &= ~body_flags # exclusive
		emit_signal("visibility_changed")
	else:
		if symbol_visible_flags & body_flags == 0:
			return
		symbol_visible_flags &= ~body_flags
		emit_signal("visibility_changed")


func set_orbit_visibility(body_flags: int, is_show: bool) -> void:
	body_flags &= all_flags
	if is_show:
		if orbit_visible_flags & body_flags == body_flags:
			return
		orbit_visible_flags |= body_flags
		emit_signal("visibility_changed")
	else:
		if orbit_visible_flags & body_flags == 0:
			return
		orbit_visible_flags &= ~body_flags
		emit_signal("visibility_changed")
	emit_signal("visibility_changed")


func set_all_names_visibility(is_show: bool) -> void:
	if is_show:
		if name_visible_flags == all_flags:
			return
		name_visible_flags = all_flags
		symbol_visible_flags = 0 # exclusive
	else:
		if name_visible_flags == 0:
			return
		name_visible_flags = 0
	emit_signal("visibility_changed")


func set_all_symbols_visibility(is_show: bool) -> void:
	if is_show:
		if symbol_visible_flags == all_flags:
			return
		symbol_visible_flags = all_flags
		name_visible_flags = 0 # exclusive
	else:
		if symbol_visible_flags == 0:
			return
		symbol_visible_flags = 0
	emit_signal("visibility_changed")


func set_all_orbits_visibility(is_show: bool) -> void:
	if is_show:
		if orbit_visible_flags == all_flags:
			return
		orbit_visible_flags = all_flags
	else:
		if orbit_visible_flags == 0:
			return
		orbit_visible_flags = 0
	emit_signal("visibility_changed")


func set_name_visible_flags(name_visible_flags_: int) -> void:
	if name_visible_flags == name_visible_flags_:
		return
	name_visible_flags = name_visible_flags_
	symbol_visible_flags &= ~name_visible_flags_ # exclusive
	emit_signal("visibility_changed")


func set_symbol_visible_flags(symbol_visible_flags_: int) -> void:
	if symbol_visible_flags == symbol_visible_flags_:
		return
	symbol_visible_flags = symbol_visible_flags_
	name_visible_flags &= ~symbol_visible_flags_ # exclusive
	emit_signal("visibility_changed")


func set_orbit_visible_flags(orbit_visible_flags_: int) -> void:
	if orbit_visible_flags == orbit_visible_flags_:
		return
	orbit_visible_flags = orbit_visible_flags_
	emit_signal("visibility_changed")


# color

func set_default_colors() -> void:
	if deep_equal(orbit_colors, default_orbit_colors):
		return
	orbit_colors.merge(default_orbit_colors, true)
	emit_signal("color_changed")


func get_default_orbit_color(body_flags: int) -> Color:
	# If >1 bit from all_flags, will return fallback_orbit_color
	body_flags &= all_flags
	return default_orbit_colors.get(body_flags, fallback_orbit_color)


func get_orbit_color(body_flags: int) -> Color:
	# If >1 bit from all_flags, all must agree or returns NULL_COLOR
	body_flags &= all_flags
	if body_flags and !(body_flags & (body_flags - 1)): # single bit test
		return orbit_colors[body_flags]
	var has_first := false
	var consensus_color := NULL_COLOR
	var flag := 1
	while body_flags:
		if body_flags & 1:
			var color: Color = orbit_colors[flag]
			if has_first and color != consensus_color:
				return NULL_COLOR
			has_first = true
			consensus_color = color
		flag <<= 1
		body_flags >>= 1
	return consensus_color


func set_orbit_color(body_flags: int, color: Color) -> void:
	# Can set any number from all_flags.
	body_flags &= all_flags
	if body_flags and !(body_flags & (body_flags - 1)): # single bit test
		if orbit_colors[body_flags] != color:
			orbit_colors[body_flags] = color
			emit_signal("color_changed")
		return
	var color_changed := false
	var flag := 1
	while body_flags:
		if body_flags & 1:
			if orbit_colors[flag] != color:
				orbit_colors[flag] = color
				color_changed = true
		flag <<= 1
		body_flags >>= 1
	if color_changed:
		emit_signal("color_changed")


func get_non_default_orbit_colors() -> Dictionary:
	# key-values equal to default are skipped
	var dict := {}
	for key in orbit_colors:
		if orbit_colors[key] != default_orbit_colors[key]:
			dict[key] = orbit_colors[key]
	return dict


func set_all_orbit_colors(dict: Dictionary) -> void:
	# missing key-values are set to default
	var is_change := false
	for key in orbit_colors:
		if dict.has(key):
			if orbit_colors[key] != dict[key]:
				is_change = true
				orbit_colors[key] = dict[key]
		else:
			if orbit_colors[key] != default_orbit_colors[key]:
				is_change = true
				orbit_colors[key] = default_orbit_colors[key]
	if is_change:
		emit_signal("color_changed")


# private

func _set_current_to_default() -> void:
	set_default_visibilities()
	set_default_colors()


func _signal_all_changed() -> void:
	emit_signal("visibility_changed")
	emit_signal("color_changed")



