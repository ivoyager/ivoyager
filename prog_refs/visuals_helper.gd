# visuals_helper.gd
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

class_name VisualsHelper

const VECTOR2_NULL := Vector2(-INF, -INF)

var camera: Camera # IVCamera sets
var camera_fov: float # IVCamera sets
var veiwport_height: float
var mouse_position: Vector2 # IVProjectionSurface sets
var mouse_target: Object
var target_dist := INF


func get_distance_to_camera(global_translation: Vector3) -> float:
	var camera_global_translation := camera.global_transform.origin
	return global_translation.distance_to(camera_global_translation)

func unproject_position_in_front(global_translation: Vector3) -> Vector2:
	if camera.is_position_behind(global_translation):
		return VECTOR2_NULL
	return camera.unproject_position(global_translation)

func set_mouse_target(target: Object, camera_dist: float) -> void:
	if camera_dist < target_dist:
		mouse_target = target
		target_dist = camera_dist

func remove_mouse_target(target: Object) -> void:
	if mouse_target == target:
		mouse_target = null
		target_dist = INF

func _project_init() -> void:
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_reset")
	var viewport := IVGlobal.get_viewport()
	viewport.connect("size_changed", self, "_on_viewport_size_changed")
	veiwport_height = viewport.size.y

func _reset() -> void:
	mouse_target = null
	target_dist = INF

func _on_viewport_size_changed() -> void:
	var viewport := IVGlobal.get_viewport()
	veiwport_height = viewport.size.y
