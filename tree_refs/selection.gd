# selection.gd
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
class_name IVSelection
extends Reference

# Wrapper for whatever you want selected, which could be anything or just a
# text string. We wrap selection so all API expects the same type.
# SelectionManager maintains selection history.
#
# For core ivoyager we only select Body instances and provide view info for
# camera and some data access for GUI.


const math := preload("res://ivoyager/static/math.gd") # =IVMath when issue #37529 fixed

const CameraFlags := IVEnums.CameraFlags
const IDENTITY_BASIS := Basis.IDENTITY
const ECLIPTIC_X := Vector3(1.0, 0.0, 0.0)
const ECLIPTIC_Y := Vector3(0.0, 1.0, 0.0)
const ECLIPTIC_Z := Vector3(0.0, 0.0, 1.0)
const VECTOR2_ZERO := Vector2.ZERO

const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL
const PERSIST_PROPERTIES := [
	"name",
	"gui_name",
	"is_body",
	"up_selection_name",
	"view_rotate_when_close",
	"view_min_distance",
	"track_ground_positions",
	"track_orbit_positions",
	"track_ecliptic_positions",
	"spatial",
	"body",
]

# persisted - read only
var name: String
var gui_name: String # name for GUI display (already translated)
var is_body: bool
var up_selection_name := "" # top selection (only) doesn't have one
var view_rotate_when_close := false
var view_min_distance: float # camera normalizes for fov = 50
var track_ground_positions: Array #Vector3 for 1st four VIEW_TYPE_'S
var track_orbit_positions: Array #Vector3 for 1st four VIEW_TYPE_'S
var track_ecliptic_positions: Array #Vector3 for 1st four VIEW_TYPE_'S
var spatial: Spatial # for camera; same as 'body' if is_body
var body: IVBody # = spatial if is_body else null

# read-only
var texture_2d: Texture
var texture_slice_2d: Texture # stars only

# private
var _times: Array = IVGlobal.times


func _init() -> void:
	IVGlobal.connect("system_tree_ready", self, "_init_after_system", [], CONNECT_ONESHOT)
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_clear")


func _init_after_system(_dummy: bool) -> void:
	# Called for gameload; dynamically created must set these
	if is_body:
		texture_2d = body.texture_2d
		texture_slice_2d = body.texture_slice_2d


func _clear() -> void:
	if IVGlobal.is_connected("system_tree_ready", self, "_init_after_system"):
		IVGlobal.disconnect("system_tree_ready", self, "_init_after_system")
	spatial = null
	body = null


func get_name() -> String:
	return name


func get_gui_name() -> String:
	# return is already translated
	return gui_name


func get_body_name() -> String:
	return body.name if is_body else ""


func get_real_precision(path: String) -> int:
	if !is_body:
		return -1
	return body.get_real_precision(path)


func get_system_radius() -> float:
	if !is_body:
		return 0.0
	return body.get_system_radius()


func get_perspective_radius() -> float:
	if !is_body:
		return 0.0
	return body.get_perspective_radius()


func get_latitude_longitude(at_translation: Vector3, time := NAN) -> Vector2:
	if !is_body:
		return VECTOR2_ZERO
	return body.get_latitude_longitude(at_translation, time)


func get_global_origin() -> Vector3:
	if !spatial:
		return Vector3.ZERO
	return spatial.global_translation


func get_flags() -> int:
	if !is_body:
		return 0
	return body.flags


func get_orbit_normal(time := NAN, flip_retrograde := false) -> Vector3:
	if !is_body:
		return ECLIPTIC_Z
	return body.get_orbit_normal(time, flip_retrograde)


func get_up(time := NAN) -> Vector3:
	if !is_body:
		return ECLIPTIC_Z
	return body.get_north_pole(time)


func get_ground_basis(time := NAN) -> Basis:
	if !is_body:
		return IDENTITY_BASIS
	return body.get_ground_basis(time)


func get_orbit_basis(time := NAN) -> Basis:
	if !is_body:
		return IDENTITY_BASIS
	return body.get_orbit_basis(time)


func get_ecliptic_basis() -> Basis:
	if !is_body:
		return IDENTITY_BASIS
	return body.global_transform.basis


func get_radius_for_camera() -> float:
	if !is_body:
		return IVUnits.KM
	return body.get_mean_radius()


func get_position_for_view_and_tracking(camera_flags: int) -> Vector3:
	var view_type: int = (
			0 if camera_flags & CameraFlags.VIEW_ZOOM
			else 1 if camera_flags & CameraFlags.VIEW_45
			else 2 if camera_flags & CameraFlags.VIEW_TOP
			else 3)
	if camera_flags & CameraFlags.TRACK_GROUND:
		return track_ground_positions[view_type]
	elif camera_flags & CameraFlags.TRACK_ORBIT:
		return track_orbit_positions[view_type]
	return track_ecliptic_positions[view_type]

