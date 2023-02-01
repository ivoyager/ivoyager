# selection_builder.gd
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
class_name IVSelectionBuilder
extends Reference


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
var min_view_dist_radius_multiplier := 1.65
var zoom_divisor := 1.5e-4 * IVUnits.KM # bigger makes zoom closer
var size_ratio_exponent := 0.8 # at 1.0 bodies are distanced to appear same size
var system_radius_multiplier_top := 2.5

# private
var _home_view_from_user_time_zone: bool = IVGlobal.home_view_from_user_time_zone
var _Selection_: Script


func _project_init() -> void:
	_Selection_ = IVGlobal.script_classes._Selection_


func build_body_selection(body: IVBody) -> IVSelection:
	var parent_body := body.get_parent() as IVBody
	var selection: IVSelection = _Selection_.new()
	selection.is_body = true
	selection.spatial = body
	selection.body = body
	selection.name = body.name
	selection.gui_name = tr(body.name)
	selection.texture_2d = body.texture_2d
	selection.texture_slice_2d = body.texture_slice_2d
	set_view_parameters_from_body(selection, body)
	if parent_body:
		selection.up_selection_name = parent_body.name
		# TODO: Some special handling for barycenters
	else:
		selection.up_selection_name = above_bodies_selection_name
	return selection


func set_view_parameters_from_body(selection: IVSelection, body: IVBody) -> void:
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
			var time_zone_info := Time.get_time_zone_from_system()
			use_ground_longitude_offset = fposmod(time_zone_info.bias * TAU / 1440.0, TAU)
			prints("time zone offset:", use_ground_longitude_offset)
	else: # moons or moon satellites
		use_ground_longitude_offset = ground_longitude_offset_moon
		use_orbit_longitude_offset = orbit_longitude_offset_moon
		use_ground_latitude_offset = ground_latitude_offset_moon
		use_orbit_latitude_offset = orbit_latitude_offset_moon
	var m_radius := body.get_mean_radius()
	selection.view_min_distance = m_radius * min_view_dist_radius_multiplier
	var view_dist_zoom := pow(m_radius / zoom_divisor, size_ratio_exponent) * IVUnits.KM
	var view_dist_top := selection.get_system_radius() * system_radius_multiplier_top * 50.0 # /fov
	var view_dist_45 := exp((log(view_dist_zoom) + log(view_dist_top)) / 2.0)
	match body.name:
		"STAR_SUN":
			view_dist_45 *= 4.0
		"PLANET_URANUS":
			view_dist_45 /= 2.5
		"PLANET_NEPTUNE":
			view_dist_45 /= 4.0
	
	selection.track_ground_positions = [ # camera will divide dist by fov
		Vector3(use_ground_longitude_offset, use_ground_latitude_offset, view_dist_zoom), # VIEW_ZOOM
		Vector3(use_ground_longitude_offset, latitude_offset_45, view_dist_45), # VIEW_45
		Vector3(use_ground_longitude_offset, latitude_offset_top, view_dist_top), # VIEW_TOP
		Vector3(use_ground_longitude_offset, use_ground_latitude_offset, view_dist_zoom) # VIEW_OUTWARD
	]
	selection.track_orbit_positions = [ # camera will divide dist by fov
		Vector3(use_orbit_longitude_offset, use_orbit_latitude_offset, view_dist_zoom), # VIEW_ZOOM
		Vector3(use_orbit_longitude_offset, latitude_offset_45, view_dist_45), # VIEW_45
		Vector3(use_orbit_longitude_offset, latitude_offset_top, view_dist_top), # VIEW_TOP
		Vector3(use_orbit_longitude_offset, use_orbit_latitude_offset, view_dist_zoom) # VIEW_OUTWARD
	]
	selection.track_ecliptic_positions = [ # camera will divide dist by fov
		Vector3(ecliptic_longitude_offset, ecliptic_latitude_offset, view_dist_zoom), # VIEW_ZOOM
		Vector3(ecliptic_longitude_offset, latitude_offset_45, view_dist_45), # VIEW_45
		Vector3(ecliptic_longitude_offset, latitude_offset_top, view_dist_top), # VIEW_TOP
		Vector3(ecliptic_longitude_offset, ecliptic_latitude_offset, view_dist_zoom) # VIEW_OUTWARD
	]
