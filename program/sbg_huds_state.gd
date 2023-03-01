# sbg_huds_state.gd
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
class_name IVSBGHUDsState
extends Node

# Maintains visibility and color state for SmallBodiesGroup HUDs. HUD Nodes
# must connect and set visibility and color on changed signals.

signal points_visibility_changed()
signal orbits_visibility_changed()
signal points_color_changed()
signal orbits_color_changed()

const utils := preload("res://ivoyager/static/utils.gd")

const NULL_COLOR := Color.black

const PERSIST_MODE := IVEnums.PERSIST_PROPERTIES_ONLY
const PERSIST_PROPERTIES := [
	"points_visibilities",
	"orbits_visibilities",
	"points_colors",
	"orbits_colors",
]

# persisted - read-only!
var points_visibilities := {} # indexed by sbg_alias; missing same as false
var orbits_visibilities := {} # "
var points_colors := {} # indexed by sbg_alias; missing same as fallback color
var orbits_colors := {} # "

# project vars - set at project init
var fallback_points_color := Color(0.0, 0.6, 0.0)
var fallback_orbits_color := Color(0.8, 0.2, 0.2)
var default_points_visibilities := {} # default is none, unless project changes
var default_orbits_visibilities := {}

# imported from small_bodies_groups.tsv - ready-only!
var default_points_colors := {}
var default_orbits_colors := {}



func _project_init() -> void:
	IVGlobal.connect("simulator_exited", self, "_set_current_to_default")
	IVGlobal.connect("update_gui_requested", self, "_signal_all_changed")
	var table_reader: IVTableReader = IVGlobal.program.TableReader
	for row in table_reader.get_n_rows("small_bodies_groups"):
		if table_reader.get_bool("small_bodies_groups", "skip_import", row):
			continue
		var sbg_alias := table_reader.get_string("small_bodies_groups", "sbg_alias", row)
		var points_color_str := table_reader.get_string("small_bodies_groups", "points_color", row)
		var orbits_color_str := table_reader.get_string("small_bodies_groups", "orbits_color", row)
		var default_points_color := utils.str2color(points_color_str)
		var default_orbits_color := utils.str2color(orbits_color_str)
		default_points_colors[sbg_alias] = default_points_color
		default_orbits_colors[sbg_alias] = default_orbits_color
	_set_current_to_default()


# visibility

func hide_all() -> void:
	for key in points_visibilities:
		points_visibilities[key] = false
	for key in orbits_visibilities:
		orbits_visibilities[key] = false
	emit_signal("points_visibility_changed")
	emit_signal("orbits_visibility_changed")


func set_default_visibilities() -> void:
	if !deep_equal(points_visibilities, default_points_visibilities):
		points_visibilities.clear()
		points_visibilities.merge(default_points_visibilities)
		emit_signal("points_visibility_changed")
	if !deep_equal(orbits_visibilities, default_orbits_visibilities):
		orbits_visibilities.clear()
		orbits_visibilities.merge(default_orbits_visibilities)
		emit_signal("orbits_visibility_changed")


func is_points_visible(group: String) -> bool:
	return points_visibilities.get(group, false)


func change_points_visibility(group: String, is_show: bool) -> void:
	points_visibilities[group] = is_show
	emit_signal("points_visibility_changed")


func is_orbits_visible(group: String) -> bool:
	return orbits_visibilities.get(group, false)


func change_orbits_visibility(group: String, is_show: bool) -> void:
	orbits_visibilities[group] = is_show
	emit_signal("orbits_visibility_changed")


func get_visible_points_groups() -> Array:
	var array := []
	for key in points_visibilities:
		if points_visibilities[key]:
			array.append(key)
	return array


func get_visible_orbits_groups() -> Array:
	var array := []
	for key in orbits_visibilities:
		if orbits_visibilities[key]:
			array.append(key)
	return array


func set_visible_points_groups(array: Array) -> void:
	points_visibilities.clear()
	for key in array:
		points_visibilities[key] = true
	emit_signal("points_visibility_changed")


func set_visible_orbits_groups(array: Array) -> void:
	orbits_visibilities.clear()
	for key in array:
		orbits_visibilities[key] = true
	emit_signal("orbits_visibility_changed")


# color

func set_default_colors() -> void:
	if !deep_equal(points_colors, default_points_colors):
		points_colors.clear()
		points_colors.merge(default_points_colors)
		emit_signal("points_color_changed")
	if !deep_equal(orbits_colors, default_orbits_colors):
		orbits_colors.clear()
		orbits_colors.merge(default_orbits_colors)
		emit_signal("orbits_color_changed")


func get_default_points_color(group: String) -> Color:
	if default_points_colors.has(group):
		return default_points_colors[group]
	return fallback_points_color


func get_default_orbits_color(group: String) -> Color:
	if default_orbits_colors.has(group):
		return default_orbits_colors[group]
	return fallback_orbits_color


func get_points_color(group: String) -> Color:
	if points_colors.has(group):
		return points_colors[group]
	return fallback_points_color


func get_orbits_color(group: String) -> Color:
	if orbits_colors.has(group):
		return orbits_colors[group]
	return fallback_orbits_color


func get_consensus_points_color(groups: Array, is_default := false) -> Color:
	var has_color := false
	var consensus_color := NULL_COLOR
	for group in groups:
		var color := get_default_points_color(group) if is_default else get_points_color(group)
		if !has_color:
			has_color = true
			consensus_color = color
		elif color != consensus_color:
			return NULL_COLOR
	return consensus_color


func get_consensus_orbits_color(groups: Array, is_default := false) -> Color:
	var has_color := false
	var consensus_color := NULL_COLOR
	for group in groups:
		var color := get_default_orbits_color(group) if is_default else get_orbits_color(group)
		if !has_color:
			has_color = true
			consensus_color = color
		elif color != consensus_color:
			return NULL_COLOR
	return consensus_color


func set_points_color(group: String, color: Color) -> void:
	if points_colors.has(group):
		if color == points_colors[group]:
			return
	elif color == fallback_points_color:
		return
	points_colors[group] = color
	emit_signal("points_color_changed")


func set_orbits_color(group: String, color: Color) -> void:
	if orbits_colors.has(group):
		if color == orbits_colors[group]:
			return
	elif color == fallback_orbits_color:
		return
	orbits_colors[group] = color
	emit_signal("orbits_color_changed")


func get_points_colors_dict() -> Dictionary:
	return points_colors.duplicate()


func get_orbits_colors_dict() -> Dictionary:
	return orbits_colors.duplicate()


func set_points_colors_dict(dict: Dictionary) -> void:
	if deep_equal(dict, points_colors):
		return
	points_colors.clear()
	points_colors.merge(dict)
	emit_signal("points_color_changed")


func set_orbits_colors_dict(dict: Dictionary) -> void:
	if deep_equal(dict, orbits_colors):
		return
	orbits_colors.clear()
	orbits_colors.merge(dict)
	emit_signal("orbits_color_changed")


# private

func _set_current_to_default() -> void:
	set_default_visibilities()
	set_default_colors()


func _signal_all_changed() -> void:
	emit_signal("points_visibility_changed")
	emit_signal("orbits_visibility_changed")
	emit_signal("points_color_changed")
	emit_signal("orbits_color_changed")

