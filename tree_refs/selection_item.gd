# selection_item.gd
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
class_name IVSelectionItem

# DEPRECIATE for IVSelection

# Wrapper for whatever you want selected, which could be anything. In core
# ivoyager we only select Body instances and provide some associated UI info
# here, such as camera view angles and data precision (significant digets).

const math := preload("res://ivoyager/static/math.gd") # =IVMath when issue #37529 fixed

const IDENTITY_BASIS := Basis.IDENTITY
const ECLIPTIC_X := Vector3(1.0, 0.0, 0.0)
const ECLIPTIC_Y := Vector3(0.0, 1.0, 0.0)
const ECLIPTIC_Z := Vector3(0.0, 0.0, 1.0)
const VECTOR2_ZERO := Vector2.ZERO

# persisted - read only
var name: String # IVBodyRegistry guaranties these are unique
var is_body: bool
var up_selection_name := "" # top selection (only) doesn't have one
var system_radius := 0.0
var view_rotate_when_close := false
var view_min_distance: float # camera normalizes for fov = 50
var track_ground_positions: Array #Vector3 for 1st four VIEW_TYPE_'S
var track_orbit_positions: Array #Vector3 for 1st four VIEW_TYPE_'S
var track_ecliptic_positions: Array #Vector3 for 1st four VIEW_TYPE_'S
var spatial: Spatial # for camera reference
var body: IVBody # = spatial if is_body else null
const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["name", "is_body", "up_selection_name",
	"system_radius", "view_rotate_when_close", "view_min_distance",
	"track_ground_positions", "track_orbit_positions", "track_ecliptic_positions",
	"spatial", "body"]

# read-only
var texture_2d: Texture
var texture_slice_2d: Texture # stars only

# private
var _times: Array = IVGlobal.times


func _init() -> void:
	IVGlobal.connect("system_tree_ready", self, "_init_unpersisted", [], CONNECT_ONESHOT)


func _init_unpersisted(_is_new_game: bool) -> void:
	if is_body:
		texture_2d = body.texture_2d
		texture_slice_2d = body.texture_slice_2d


func get_real_precision(path: String) -> int:
	if !is_body:
		return -1
	return body.get_real_precision(path)


func get_latitude_longitude(at_translation: Vector3, time := NAN) -> Vector2:
	if !is_body:
		return VECTOR2_ZERO
	return body.get_latitude_longitude(at_translation, time)


func get_global_origin() -> Vector3:
	return spatial.global_transform.origin


func get_flags() -> int:
	if is_body:
		return body.flags
	return 0


func get_orbit_normal(time := NAN, flip_retrograde := false) -> Vector3:
	if !is_body:
		return ECLIPTIC_Z
	return body.get_orbit_normal(time, flip_retrograde)


func get_up(time := NAN) -> Vector3:
	if !is_body:
		return ECLIPTIC_Z
	return body.get_north_pole(time)


func get_ground_ref_basis(time := NAN) -> Basis:
	if !is_body:
		return IDENTITY_BASIS
	return body.get_ground_ref_basis(time)


func get_orbit_ref_basis(time := NAN) -> Basis:
	if !is_body:
		return IDENTITY_BASIS
	return body.get_orbit_ref_basis(time)


func get_radius_for_camera() -> float:
	if is_body:
		return body.get_mean_radius()
	return IVUnits.KM
