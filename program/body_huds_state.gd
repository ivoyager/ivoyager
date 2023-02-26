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

# Maintains visibility and color state for Body HUDs, and defines defaults.
# Body HUDs must connect and set their own visibility on changed signals.
#
# See also IVSBGHUDsState for small body group HUDs.

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

# not persisted - modify at project init

var all_flags: int = (
		# This is the complete and exclusive set.
		BodyFlags.IS_STAR
		| BodyFlags.IS_TRUE_PLANET
		| BodyFlags.IS_DWARF_PLANET
		| BodyFlags.IS_PLANETARY_MASS_MOON
		| BodyFlags.IS_NON_PLANETARY_MASS_MOON
		| BodyFlags.IS_ASTEROID
		| BodyFlags.IS_SPACECRAFT
)

var default_orbit_visible_flags: int = (
		BodyFlags.IS_STAR
		| BodyFlags.IS_TRUE_PLANET
		| BodyFlags.IS_DWARF_PLANET
		| BodyFlags.IS_PLANETARY_MASS_MOON
		| BodyFlags.IS_NON_PLANETARY_MASS_MOON
)
var default_name_visible_flags := default_orbit_visible_flags # exclusive w/ symbol_visible_flags
var default_symbol_visible_flags := 0 # exclusive w/ name_visible_flags

var default_orbit_colors := {
	# Keys must match all single bits in all_flags.
	BodyFlags.IS_STAR : Color(0.4, 0.4, 0.8), # maybe future use
	BodyFlags.IS_TRUE_PLANET :  Color(0.5, 0.5, 0.1),
	BodyFlags.IS_DWARF_PLANET : Color(0.1, 0.8, 0.2),
	BodyFlags.IS_PLANETARY_MASS_MOON : Color(0.3, 0.3, 0.9),
	BodyFlags.IS_NON_PLANETARY_MASS_MOON : Color(0.35, 0.1, 0.35),
	BodyFlags.IS_ASTEROID : Color(0.8, 0.2, 0.2),
	BodyFlags.IS_SPACECRAFT : Color(0.4, 0.4, 0.8),
}
var fallback_orbit_color := Color(0.4, 0.4, 0.8)


# persisted - read-only!
var name_visible_flags := default_name_visible_flags # exclusive w/ symbol_visible_flags
var symbol_visible_flags := default_symbol_visible_flags # exclusive w/ name_visible_flags
var orbit_visible_flags := default_orbit_visible_flags
var orbit_colors := default_orbit_colors.duplicate()


onready var _tree := get_tree()



func _ready() -> void:
	IVGlobal.connect("update_gui_requested", self, "_on_update_gui_requested")


func _on_update_gui_requested() -> void:
	emit_signal("visibility_changed")


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
	orbit_visible_flags = 0
	name_visible_flags = 0
	symbol_visible_flags = 0
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


func get_orbit_colors_dict() -> Dictionary:
	return orbit_colors.duplicate()


func set_orbit_colors_dict(dict: Dictionary) -> void:
	assert(dict.keys() == orbit_colors.keys())
	orbit_colors.merge(dict, true) # overwrite
	emit_signal("color_changed")

