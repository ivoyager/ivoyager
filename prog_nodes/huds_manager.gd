# huds_manager.gd
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
class_name IVHUDsManager
extends Node

# Manages visibility of HUD elements.

signal visibility_changed()


const BodyFlags: Dictionary = IVEnums.BodyFlags


const PERSIST_MODE := IVEnums.PERSIST_PROPERTIES_ONLY
const PERSIST_PROPERTIES := [
	"orbit_visible_flags",
	"name_visible_flags",
	"symbol_visible_flags",
]

# not persisted - modify at project init if new types to manage
var all_visible_flags: int = (BodyFlags.IS_STAR | BodyFlags.IS_TRUE_PLANET
		| BodyFlags.IS_DWARF_PLANET | BodyFlags.IS_MOON | BodyFlags.IS_ASTEROID
		| BodyFlags.IS_SPACECRAFT)

# persisted - read-only except at project init
var orbit_visible_flags := all_visible_flags
var name_visible_flags := all_visible_flags # exclusive w/ symbol_visible_flags
var symbol_visible_flags := 0 # exclusive w/ name_visible_flags

onready var _tree := get_tree()


func _ready():
	IVGlobal.connect("update_gui_requested", self, "emit_signal", ["visibility_changed"])


func _unhandled_key_input(event: InputEventKey):
	if event.is_action_pressed("toggle_orbits"):
		set_all_orbits_visibility(bool(orbit_visible_flags != all_visible_flags))
	elif event.is_action_pressed("toggle_symbols"):
		set_all_symbols_visibility(bool(symbol_visible_flags != all_visible_flags))
	elif event.is_action_pressed("toggle_names"):
		set_all_names_visibility(bool(name_visible_flags != all_visible_flags))
	else:
		return # input NOT handled!
	_tree.set_input_as_handled()


func is_orbit_visible(body_flags: int, match_all := false) -> bool:
	if match_all:
		body_flags &= all_visible_flags
		return body_flags & orbit_visible_flags == body_flags
	return bool(body_flags & orbit_visible_flags) # any flags


func is_name_visible(body_flags: int, match_all := false) -> bool:
	if match_all:
		body_flags &= all_visible_flags
		return body_flags & name_visible_flags == body_flags
	return bool(body_flags & name_visible_flags) # any flags


func is_symbol_visible(body_flags: int, match_all := false) -> bool:
	if match_all:
		body_flags &= all_visible_flags
		return body_flags & symbol_visible_flags == body_flags
	return bool(body_flags & symbol_visible_flags) # any flags


func is_all_orbits_visible() -> bool:
	return orbit_visible_flags == all_visible_flags


func is_all_names_visible() -> bool:
	return name_visible_flags == all_visible_flags


func is_all_symbols_visible() -> bool:
	return symbol_visible_flags == all_visible_flags


func set_orbit_visibility(body_flags: int, is_show: bool) -> void:
	body_flags &= all_visible_flags
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


func set_name_visibility(body_flags: int, is_show: bool) -> void:
	body_flags &= all_visible_flags
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
	body_flags &= all_visible_flags
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


func set_all_orbits_visibility(is_show: bool) -> void:
	if is_show:
		if orbit_visible_flags == all_visible_flags:
			return
		orbit_visible_flags = all_visible_flags
	else:
		if orbit_visible_flags == 0:
			return
		orbit_visible_flags = 0
	emit_signal("visibility_changed")


func set_all_names_visibility(is_show: bool) -> void:
	if is_show:
		if name_visible_flags == all_visible_flags:
			return
		name_visible_flags = all_visible_flags
		symbol_visible_flags = 0 # exclusive
	else:
		if name_visible_flags == 0:
			return
		name_visible_flags = 0
	emit_signal("visibility_changed")


func set_all_symbols_visibility(is_show: bool) -> void:
	if is_show:
		if symbol_visible_flags == all_visible_flags:
			return
		symbol_visible_flags = all_visible_flags
		name_visible_flags = 0 # exclusive
	else:
		if symbol_visible_flags == 0:
			return
		symbol_visible_flags = 0
	emit_signal("visibility_changed")


func set_orbit_visible_flags(orbit_visible_flags_: int) -> void:
	if orbit_visible_flags == orbit_visible_flags_:
		return
	orbit_visible_flags = orbit_visible_flags_
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

