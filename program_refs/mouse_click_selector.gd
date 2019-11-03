# mouse_click_selector.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2019 Charlie Whitfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# *****************************************************************************
#
# This is a work-around for not using ray casting and collision bodies. Only
# bodies with visible == true (and their children) need to be tested.

extends Reference
class_name MouseClickSelector

const MOUSE_CLICK_RANGE_SQ := 500.0 # in viewport pixels

var _registrar: Registrar
var _math: Math
var _mouse_position: Vector2
var _camera: Camera
var _camera_global_translation: Vector3
var _viewport_height: float
var _body: Body
var _closest_dist_sq := INF

func project_init() -> void:
	Global.connect("mouse_clicked_viewport_at", self, "select_at")
	_registrar = Global.objects.Registrar
	_math = Global.objects.Math

func select_at(mouse_position: Vector2, camera: Camera, _is_left_click: bool) -> void:
	_mouse_position = mouse_position
	_camera = camera
	_camera_global_translation = camera.global_transform.origin
	_viewport_height = camera.get_viewport().get_visible_rect().size.y
	_body = null
	_closest_dist_sq = INF
	_test_body_recursive(_registrar.top_body)
	if _body:
		Global.emit_signal("move_camera_to_body_requested", _body)
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

