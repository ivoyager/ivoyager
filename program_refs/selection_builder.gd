# selection_builder.gd
# This file is part of I, Voyager
# https://ivoyager.dev
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

# project vars
var above_bodies_selection_name := "" # "SYSTEM_SOLAR_SYSTEM"
var longitude_fixed := 0.0
var latitude_fixed := 0.0
var longitude_zoom_offset_star_behind := PI + PI / 3.0 # view from above 3 O'Clock
var latitude_zoom_offset_star_behind := -PI / 200.0 # a bit below equator shows off Saturn's rings
var longitude_zoom_offset_parent_forground := PI / 10.0 # eg, Earth slightly right of Moon
var latitude_zoom_offset_parent_forground := PI / 10.0 # eg, Earth slightly above Moon
var min_view_dist_radius_multiplier := 1.65

var m_radius_fill_view_zoom := 7e5 # km; this size object fills the zoom view
var size_compensation_exponent := 0.2 # < 0.0 is "full" compensation; 1.0 is none
var system_radius_multiplier_top := 1.5

# dependencies
var _scale: float = Global.scale
var _registrar: Registrar
var _SelectionItem_: Script

func project_init() -> void:
	_registrar = Global.objects.Registrar
	_SelectionItem_ = Global.script_classes._SelectionItem_

func build_from_body(body: Body, parent_body: Body) -> SelectionItem:
	# parent_body = null for top Body
	var selection_item: SelectionItem = _SelectionItem_.new()
	var selection_type := _get_selection_type_from_body(body)
	body.selection_type = selection_type
	selection_item.init(selection_type)
	selection_item.is_body = true
	selection_item.spatial = body
	selection_item.body = body
	selection_item.name = body.name
	selection_item.classification = _get_classification_from_body(body)
	set_view_parameters_from_body(selection_item, body)
	if parent_body:
		selection_item.up_selection_name = parent_body.name
		# TODO: Some special handling for barycenters
	else:
		selection_item.up_selection_name = above_bodies_selection_name
	_registrar.register_selection_item(selection_item)
	return selection_item

func set_view_parameters_from_body(selection_item: SelectionItem, body: Body) -> void:
	var x_offset_zoom: float
	var y_offset_zoom: float
	if body.is_top or !body.orbit:
		x_offset_zoom = longitude_fixed
		y_offset_zoom = latitude_fixed
	elif body.is_star_orbiting and !body.is_star: # put parent star behind camera
		selection_item.view_rotate_when_close = true
		x_offset_zoom = longitude_zoom_offset_star_behind
		y_offset_zoom = latitude_zoom_offset_star_behind
	else: # put the target's parent (eg, Earth) behind the target (Moon)
		selection_item.view_rotate_when_close = true
		x_offset_zoom = longitude_zoom_offset_parent_forground
		y_offset_zoom = latitude_zoom_offset_parent_forground
	var x_offset_top := longitude_fixed
	var y_offset_top := PI / 2.0 - VoyagerCamera.MIN_ANGLE_TO_POLE
	var x_offset_45 := (x_offset_zoom + x_offset_top) / 2.0
	var y_offset_45 := (y_offset_zoom + y_offset_top) / 2.0
	var m_radius := body.m_radius
	selection_item.view_min_distance = m_radius * min_view_dist_radius_multiplier
	var view_dist_zoom := 120.0 * m_radius
	var adj_ratio := pow((m_radius_fill_view_zoom * _scale) / m_radius, size_compensation_exponent)
	view_dist_zoom *= adj_ratio
	var view_dist_top := 400.0 * body.system_radius * system_radius_multiplier_top
	var view_dist_45 := exp((log(view_dist_zoom) + log(view_dist_top)) / 2.0)
	selection_item.camera_spherical_positions = [ # camera will divide dist by fov
		Vector3(x_offset_zoom, y_offset_zoom, view_dist_zoom), # VIEW_ZOOM
		Vector3(x_offset_45, y_offset_45, view_dist_45), # VIEW_45
		Vector3(x_offset_top, y_offset_top, view_dist_top) # VIEW_TOP
	]

func _get_selection_type_from_body(body: Body) -> int:
	if body.is_star:
		return Enums.SELECTION_STAR
	if body.is_dwarf_planet:
		return Enums.SELECTION_DWARF_PLANET
	if body.is_planet:
		return Enums.SELECTION_PLANET
	if body.is_moon:
		return Enums.SELECTION_MOON
	return -1

func _get_classification_from_body(body: Body) -> String:
	# for UI display "Classification: ______"
	if body.is_star:
		return "CLASSIFICATION_STAR"
	if body.is_dwarf_planet:
		return "CLASSIFICATION_DWARF_PLANET"
	if body.is_planet:
		return "CLASSIFICATION_PLANET"
	if body.is_moon:
		return "CLASSIFICATION_MOON"
	return ""
	
	
