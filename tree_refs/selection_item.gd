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

const math := preload("res://ivoyager/static/math.gd") # =Math when issue #37529 fixed

const IDENTITY_BASIS := Basis.IDENTITY
const ECLIPTIC_X := Vector3(1.0, 0.0, 0.0)
const ECLIPTIC_Y := Vector3(0.0, 1.0, 0.0)
const ECLIPTIC_Z := Vector3(0.0, 0.0, 1.0)
const VECTOR2_ZERO := Vector2.ZERO

# persisted - read only
var name: String # Registrar guaranties these are unique
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
var camera_view_positions: Array #Vector3 for 1st four VIEW_TYPE_'S

var spatial: Spatial # for camera reference
var body: Body # = spatial if is_body else null


const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["name", "is_body", "up_selection_name",
	"non_body_texture_2d_path", "n_stars", "n_planets", "n_dwarf_planets",
	"n_moons", "n_asteroids", "n_comets", "view_rotate_when_close", "view_min_distance",
	"camera_view_positions"]
const PERSIST_OBJ_PROPERTIES := ["spatial", "body"]

# read-only
var texture_2d: Texture
var texture_slice_2d: Texture # stars only
# private
var _times: Array = Global.times


func get_global_origin() -> Vector3:
	return spatial.global_transform.origin

func get_flags() -> int:
	if is_body:
		return body.flags
	return 0

func get_orbit_normal(time := -INF) -> Vector3:
	if !is_body:
		return ECLIPTIC_Z
	return body.get_orbit_normal(time)

func get_north(time := -INF) -> Vector3:
	if !is_body:
		return ECLIPTIC_Z
	return body.get_north(time)

func get_ground_ref_basis(time := -INF) -> Basis:
	if !is_body:
		return IDENTITY_BASIS
	return body.get_ground_ref_basis(time)

func get_orbit_ref_basis(time := -INF) -> Basis:
	if !is_body:
		return IDENTITY_BASIS
	return body.get_orbit_ref_basis(time)


#func get_orbit_ref_ecliptic2(time := -INF) -> Vector2:
#	# Returns ecliptic spherical coordinates (RA, Dec) of parent body.
#	if !is_body:
#		return VECTOR2_ZERO
#	return body.get_orbit_ref_ecliptic2(time)
#
#func get_geo_ref_ecliptic2(time := -INF) -> Vector2:
#	# Returns ecliptic spherical coordinates (RA, Dec) of lat,long = 0,0.
#	# For tidally locked bodies, this is nearly same as get_orbit_ref_ecliptic2(),
#	# but varies with librations (see wiki Lunar Libration).
#	if !is_body:
#		return VECTOR2_ZERO
#	return body.get_geo_ref_ecliptic2(time)
	


func get_radius_for_camera() -> float:
	if is_body:
		return body.properties.m_radius
	return UnitDefs.KM

func get_orbit_anomaly_for_camera() -> float:
	if !is_body or !view_rotate_when_close:
		return 0.0
	var orbit: Orbit = body.orbit
	if !orbit:
		return 0.0
	return orbit.get_anomaly_for_camera(_times[0])

func get_ref_longitude() -> float:
	# direction of this item's zero longitude
	
	return 0.0


func _init() -> void:
	Global.connect("system_tree_built_or_loaded", self, "_init_unpersisted", [], CONNECT_ONESHOT)

func _init_unpersisted(_is_new_game: bool) -> void:
	if is_body:
		texture_2d = body.texture_2d
		texture_slice_2d = body.texture_slice_2d
	else:
		texture_2d = load(non_body_texture_2d_path)

