# mouse_click_selector.gd
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
# This is a work-around for not using ray casting and collision bodies. Only
# bodies with visible == true (and their children) need to be tested.

extends Reference
class_name MouseClickSelector

const MOUSE_CLICK_RANGE_SQ := 500.0 # in viewport pixels
const NULL_ROTATION := Vector3(-INF, -INF, -INF)

var _registrar: Registrar
var _mouse_position: Vector2
var _camera: Camera
var _camera_global_translation: Vector3
var _viewport_height: float
var _body: Body
var _closest_dist_sq := INF

func project_init() -> void:
	Global.connect("mouse_clicked_viewport_at", self, "select_at")
	_registrar = Global.program.Registrar

func select_at(mouse_position: Vector2, camera: Camera, _is_left_click: bool) -> void:
	_mouse_position = mouse_position
	_camera = camera
	_camera_global_translation = camera.global_transform.origin
	_viewport_height = camera.get_viewport().get_visible_rect().size.y
	_body = null
	_closest_dist_sq = INF
	_test_body_recursive(_registrar.top_body)
	if _body:
		Global.emit_signal("move_camera_to_body_requested", _body, -1, Vector3.ZERO, NULL_ROTATION)
	else:
		# placeholder for WIP PointPicker
		pass

func _test_body_recursive(body: Body) -> void:
	var test_global_position := body.global_transform.origin
	if !_camera.is_position_behind(test_global_position):
		var dist_sq := (_camera_global_translation - test_global_position).length_squared()
		if dist_sq < _closest_dist_sq:
			var screen_radius_sq := _get_screen_radius_sq(body.m_radius, _viewport_height, _camera.fov, dist_sq)
			var screen_range_sq := (_mouse_position - _camera.unproject_position(test_global_position)).length_squared()
			if screen_range_sq < MOUSE_CLICK_RANGE_SQ + screen_radius_sq:
				_body = body
				_closest_dist_sq = dist_sq
	for child in body.satellites:
		if child.visible:
			_test_body_recursive(child)

static func _get_screen_radius_sq(radius: float, viewport_height: float, camera_fov: float, camera_dist_sq: float) -> float:
	return pow(55.0 * radius * viewport_height / camera_fov, 2.0) / camera_dist_sq

