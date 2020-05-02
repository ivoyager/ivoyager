# selection_item.gd
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
class_name SelectionItem

const SELECTION_STAR = Enums.SelectionTypes.SELECTION_STAR
const SELECTION_PLANET = Enums.SelectionTypes.SELECTION_PLANET
const SELECTION_DWARF_PLANET = Enums.SelectionTypes.SELECTION_DWARF_PLANET
const SELECTION_MAJOR_MOON = Enums.SelectionTypes.SELECTION_MAJOR_MOON
const SELECTION_MINOR_MOON = Enums.SelectionTypes.SELECTION_MINOR_MOON

const ECLIPTIC_NORTH := Vector3(0.0, 0.0, 1.0)

# persisted - read only
var name: String # Registrar guaranties these are unique
var selection_type: int
var is_body: bool
var up_selection_name := "" # top selection (only) doesn't have one
var non_body_texture_2d_path := "" # not used if is_body
# GUI data
var n_stars := -1
var n_planets := -1
var n_dwarf_planets := -1
var n_moons := -1
var n_asteroids := -1
var n_comets := -1
# camera
var view_rotate_when_close := false
var view_min_distance: float # camera normalizes for fov = 50
var camera_view_positions: Array #Vector3 for 1st three VIEW_TYPE_'S

var spatial: Spatial # for camera parenting
var body: Body # = spatial if is_body else null

const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["name", "selection_type", "is_body", "up_selection_name",
	"non_body_texture_2d_path", "n_stars", "n_planets", "n_dwarf_planets",
	"n_moons", "n_asteroids", "n_comets", "view_rotate_when_close", "view_min_distance",
	"camera_view_positions"]
const PERSIST_OBJ_PROPERTIES := ["spatial", "body"]

# read-only
var texture_2d: Texture
var texture_slice_2d: Texture # stars only
# private
var _times: Array = Global.times

func get_north() -> Vector3:
	if is_body:
		return body.north_pole
	return ECLIPTIC_NORTH

func get_radius_for_camera() -> float:
	if is_body:
		return body.m_radius
	return UnitDefs.KM

func get_orbit_anomaly_for_camera() -> float:
	if !is_body or !view_rotate_when_close:
		return 0.0
	var orbit: Orbit = body.orbit
	if !orbit:
		return 0.0
	return orbit.get_anomaly_for_camera(_times[0])

func change_count(change_selection_type: int, amount: int) -> void:
	match change_selection_type:
		SELECTION_MAJOR_MOON, SELECTION_MINOR_MOON:
			if n_moons != -1:
				n_moons += amount
		SELECTION_PLANET:
			if n_planets != -1:
				n_planets += amount
		SELECTION_DWARF_PLANET:
			if n_dwarf_planets != -1:
				n_dwarf_planets += amount
		SELECTION_STAR:
			if n_stars != -1:
				n_stars += amount

func _init() -> void:
	Global.connect("system_tree_built_or_loaded", self, "_init_unpersisted", [], CONNECT_ONESHOT)

func _init_unpersisted(_is_new_game: bool) -> void:
	if is_body:
		texture_2d = body.texture_2d
		texture_slice_2d = body.texture_slice_2d
	else:
		texture_2d = load(non_body_texture_2d_path)

