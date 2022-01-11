# selection_builder.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2022 Charlie Whitfield
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

extends Reference
class_name IVSelectionBuilder

const BodyFlags := IVEnums.BodyFlags
const IS_STAR := BodyFlags.IS_STAR
const IS_TRUE_PLANET := BodyFlags.IS_TRUE_PLANET
const IS_DWARF_PLANET := BodyFlags.IS_DWARF_PLANET
const IS_MOON := BodyFlags.IS_MOON
const IS_STAR_ORBITING := BodyFlags.IS_STAR_ORBITING
const IS_PLANET := BodyFlags.IS_TRUE_PLANET | BodyFlags.IS_DWARF_PLANET


# project vars
var above_bodies_selection_name := "" # "SYSTEM_SOLAR_SYSTEM"
var ecliptic_longitude_offset := 0.0
var ecliptic_latitude_offset := 0.0
var ground_longitude_offset := 0.0
var ground_latitude_offset := 0.0
var orbit_longitude_offset := deg2rad(60.0)
var orbit_latitude_offset := deg2rad(0.0)
var ground_longitude_offset_moon := deg2rad(195.0)
var ground_latitude_offset_moon := deg2rad(15.0)
var orbit_longitude_offset_moon := deg2rad(195.0)
var orbit_latitude_offset_moon := deg2rad(15.0)
var latitude_offset_top := deg2rad(85.0)
var latitude_offset_45 := deg2rad(45.0)
var min_system_m_radius_multiplier := 15.0
var min_view_dist_radius_multiplier := 1.65
var zoom_divisor := 1.5e-4 * IVUnits.KM # bigger makes zoom closer
var size_ratio_exponent := 0.8 # at 1.0 bodies are distanced to appear same size
var system_radius_multiplier_top := 2.5

# private
var _home_view_from_user_time_zone: bool = IVGlobal.home_view_from_user_time_zone
var _body_registry: BodyRegistry
var _SelectionItem_: Script

func build_body_selection_items() -> void:
	for top_body in _body_registry.top_bodies:
		build_body_selection_items_recursive(top_body, null)

func build_body_selection_items_recursive(body: IVBody, parent_body: IVBody) -> void:
	# build bottom up to calculate system_radius
	var system_radius := body.m_radius * min_system_m_radius_multiplier
	for satellite in body.satellites:
		var a: float = satellite.get_orbit_semi_major_axis()
		if system_radius < a:
			system_radius = a
		build_body_selection_items_recursive(satellite, body)
	var selection_item := build_body_selection_item(body, parent_body, system_radius)
	_body_registry.register_selection_item(selection_item)

func build_body_selection_item(body: IVBody, parent_body: IVBody, system_radius: float) -> IVSelectionItem:
	var selection_item: IVSelectionItem = _SelectionItem_.new()
	selection_item.system_radius = system_radius
	selection_item.is_body = true
	selection_item.spatial = body
	selection_item.body = body
	selection_item.name = body.name
	if body.characteristics.has("temp_real_precisions"):
		selection_item.real_precisions = body.characteristics.temp_real_precisions
		body.characteristics.erase("temp_real_precisions")
	set_view_parameters_from_body(selection_item, body)
	if parent_body:
		selection_item.up_selection_name = parent_body.name
		# TODO: Some special handling for barycenters
	else:
		selection_item.up_selection_name = above_bodies_selection_name
	return selection_item

func set_view_parameters_from_body(selection_item: IVSelectionItem, body: IVBody) -> void:
	var use_ground_longitude_offset: float
	var use_orbit_longitude_offset: float
	var use_ground_latitude_offset: float
	var use_orbit_latitude_offset: float
	if body.flags & IS_STAR_ORBITING or body.flags & IS_STAR: # non-moons
		use_ground_longitude_offset = ground_longitude_offset
		use_orbit_longitude_offset = orbit_longitude_offset
		use_ground_latitude_offset = ground_latitude_offset
		use_orbit_latitude_offset = orbit_latitude_offset
		if _home_view_from_user_time_zone and body.name == "PLANET_EARTH":
			var time_zone_info := OS.get_time_zone_info()
			use_ground_longitude_offset = fposmod(time_zone_info.bias * TAU / 1440.0, TAU)
			prints("time zone offset:", use_ground_longitude_offset)
	else: # moons or moon satellites
		use_ground_longitude_offset = ground_longitude_offset_moon
		use_orbit_longitude_offset = orbit_longitude_offset_moon
		use_ground_latitude_offset = ground_latitude_offset_moon
		use_orbit_latitude_offset = orbit_latitude_offset_moon
	var m_radius := body.get_mean_radius()
	selection_item.view_min_distance = m_radius * min_view_dist_radius_multiplier
	var view_dist_zoom := pow(m_radius / zoom_divisor, size_ratio_exponent) * IVUnits.KM
	var view_dist_top := selection_item.system_radius * system_radius_multiplier_top * 50.0 # /fov
	var view_dist_45 := exp((log(view_dist_zoom) + log(view_dist_top)) / 2.0)
	match body.name:
		"STAR_SUN":
			view_dist_45 *= 4.0
		"PLANET_URANUS":
			view_dist_45 /= 2.5
		"PLANET_NEPTUNE":
			view_dist_45 /= 4.0
	
	selection_item.track_ground_positions = [ # camera will divide dist by fov
		Vector3(use_ground_longitude_offset, use_ground_latitude_offset, view_dist_zoom), # VIEW_ZOOM
		Vector3(use_ground_longitude_offset, latitude_offset_45, view_dist_45), # VIEW_45
		Vector3(use_ground_longitude_offset, latitude_offset_top, view_dist_top), # VIEW_TOP
		Vector3(use_ground_longitude_offset, use_ground_latitude_offset, view_dist_zoom) # VIEW_OUTWARD
	]
	selection_item.track_orbit_positions = [ # camera will divide dist by fov
		Vector3(use_orbit_longitude_offset, use_orbit_latitude_offset, view_dist_zoom), # VIEW_ZOOM
		Vector3(use_orbit_longitude_offset, latitude_offset_45, view_dist_45), # VIEW_45
		Vector3(use_orbit_longitude_offset, latitude_offset_top, view_dist_top), # VIEW_TOP
		Vector3(use_orbit_longitude_offset, use_orbit_latitude_offset, view_dist_zoom) # VIEW_OUTWARD
	]
	selection_item.track_ecliptic_positions = [ # camera will divide dist by fov
		Vector3(ecliptic_longitude_offset, ecliptic_latitude_offset, view_dist_zoom), # VIEW_ZOOM
		Vector3(ecliptic_longitude_offset, latitude_offset_45, view_dist_45), # VIEW_45
		Vector3(ecliptic_longitude_offset, latitude_offset_top, view_dist_top), # VIEW_TOP
		Vector3(ecliptic_longitude_offset, ecliptic_latitude_offset, view_dist_zoom) # VIEW_OUTWARD
	]

# *****************************************************************************

func _project_init() -> void:
	_body_registry = IVGlobal.program.BodyRegistry
	_SelectionItem_ = IVGlobal.script_classes._SelectionItem_
