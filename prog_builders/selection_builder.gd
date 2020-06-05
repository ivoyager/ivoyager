# selection_builder.gd
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

extends Reference
class_name SelectionBuilder

const BodyFlags := Enums.BodyFlags
const IS_STAR := BodyFlags.IS_STAR
const IS_TRUE_PLANET := BodyFlags.IS_TRUE_PLANET
const IS_DWARF_PLANET := BodyFlags.IS_DWARF_PLANET
const IS_MOON := BodyFlags.IS_MOON
const IS_STAR_ORBITING := BodyFlags.IS_STAR_ORBITING
const IS_PLANET := BodyFlags.IS_TRUE_PLANET | BodyFlags.IS_DWARF_PLANET

# project vars
var above_bodies_selection_name := "" # "SYSTEM_SOLAR_SYSTEM"
var longitude_fixed := 0.0
var latitude_fixed := 0.0
var longitude_zoom_offset_star_behind := 0.0 # PI + PI / 3.0 # view from above 3 O'Clock
var latitude_zoom_offset_star_behind := 0.0 # -PI / 200.0 # a bit below equator shows off Saturn's rings
var longitude_zoom_offset_parent_forground := PI # PI / 10.0 # eg, Earth slightly right of Moon
var latitude_zoom_offset_parent_forground := 0.0 # PI / 10.0 # eg, Earth slightly above Moon
var min_view_dist_radius_multiplier := 1.65
var zoom_divisor := 3e3 * UnitDefs.KM # bigger makes zoom closer
var size_ratio_exponent := 0.8 # 1.0 is full size compensation
var system_radius_multiplier_top := 1.5

# dependencies
var _registrar: Registrar
var _SelectionItem_: Script

func project_init() -> void:
	Global.connect("system_tree_built_or_loaded", self, "_set_system_counts")
	_registrar = Global.program.Registrar
	_SelectionItem_ = Global.script_classes._SelectionItem_

func build_and_register(body: Body, parent_body: Body) -> void:
	# parent_body = null for top Body
	var selection_item: SelectionItem = _SelectionItem_.new()
	selection_item.is_body = true
	selection_item.spatial = body
	selection_item.body = body
	selection_item.name = body.name
	set_view_parameters_from_body(selection_item, body)
	if parent_body:
		selection_item.up_selection_name = parent_body.name
		# TODO: Some special handling for barycenters
	else:
		selection_item.up_selection_name = above_bodies_selection_name
#	selection_item.selection_type = body.selection_type
	if body.flags & IS_PLANET:
		selection_item.n_moons = 0
	elif body.flags & IS_STAR:
		selection_item.n_planets = 0
		selection_item.n_dwarf_planets = 0
		selection_item.n_moons = 0
#		selection_item.n_asteroids = 0
#		selection_item.n_comets = 0
	_registrar.register_selection_item(selection_item)

func set_view_parameters_from_body(selection_item: SelectionItem, body: Body) -> void:
	var x_offset_zoom: float
	var y_offset_zoom: float
	if !body.orbit:
		x_offset_zoom = longitude_fixed
		y_offset_zoom = latitude_fixed
	elif body.flags & IS_STAR_ORBITING and not body.flags & IS_STAR: # put parent star behind camera
		selection_item.view_rotate_when_close = true
		x_offset_zoom = longitude_zoom_offset_star_behind
		y_offset_zoom = latitude_zoom_offset_star_behind
	else: # put the target's parent (eg, Earth) behind the target (Moon)
		selection_item.view_rotate_when_close = true
		x_offset_zoom = longitude_zoom_offset_parent_forground
		y_offset_zoom = latitude_zoom_offset_parent_forground
	var x_offset_top := longitude_fixed
	var y_offset_top := PI / 2.0 - 0.1
	var x_offset_45 := (x_offset_zoom + x_offset_top) / 2.0
	var y_offset_45 := (y_offset_zoom + y_offset_top) / 2.0
	var m_radius := body.properties.m_radius
	selection_item.view_min_distance = m_radius * min_view_dist_radius_multiplier
	var view_dist_zoom := pow(m_radius / zoom_divisor, size_ratio_exponent)
	var view_dist_top := 500.0 * body.system_radius * system_radius_multiplier_top
	var view_dist_45 := exp((log(view_dist_zoom) + log(view_dist_top)) / 2.0)
	selection_item.camera_view_positions = [ # camera will divide dist by fov
		Vector3(x_offset_zoom, y_offset_zoom, view_dist_zoom), # VIEW_ZOOM
		Vector3(x_offset_45, y_offset_45, view_dist_45), # VIEW_45
		Vector3(x_offset_top, y_offset_top, view_dist_top), # VIEW_TOP
		Vector3(0.0, 0.0, view_dist_zoom) # VIEW_OUTWARD
	]

func _set_system_counts(is_new_game: bool) -> void:
	if is_new_game:
		for body in _registrar.top_bodies:
			_set_counts_recursive(body)

func _set_counts_recursive(body: Body) -> void:
	if body.flags & IS_STAR:
		for child in body.satellites:
			_set_counts_recursive(child)
	var selection_item := _registrar.get_selection_for_body(body)
	if body.flags & IS_PLANET:
		for child in body.satellites:
			if child.flags & IS_MOON:
				selection_item.n_moons += 1
	elif body.flags & IS_STAR:
		for child in body.satellites:
			if child.flags & IS_DWARF_PLANET:
				selection_item.n_dwarf_planets += 1
			elif child.flags & IS_TRUE_PLANET:
				selection_item.n_planets += 1
			if child.satellites:
				var child_selection_item := _registrar.get_selection_for_body(child)
				selection_item.n_moons += child_selection_item.n_moons
