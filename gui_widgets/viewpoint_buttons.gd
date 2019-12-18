# viewpoint_buttons.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2019 Charlie Whitfield
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
# GUI widget. Expects the camera to have "viewpoint_changed" signal and to use
# VoyagerCamera VIEWPOINT_ enums.

extends HBoxContainer

var _camera: Camera
onready var _recenter_button: Button = $Recenter
onready var _zoom_button: Button = $Zoom
onready var _fortyfive_button: Button = $FortyFive
onready var _top_button: Button = $Top

func _ready():
	Global.connect("camera_ready", self, "_connect_camera")
	_recenter_button.connect("toggled", self, "_recenter")
	_zoom_button.connect("toggled", self, "_change_viewpoint", [VoyagerCamera.VIEWPOINT_ZOOM])
	_fortyfive_button.connect("toggled", self, "_change_viewpoint", [VoyagerCamera.VIEWPOINT_45])
	_top_button.connect("toggled", self, "_change_viewpoint", [VoyagerCamera.VIEWPOINT_TOP])
	_connect_camera(get_viewport().get_camera())

func _connect_camera(camera: Camera) -> void:
	if _camera != camera:
		_disconnect_camera()
		_camera = camera
		_camera.connect("viewpoint_changed", self, "_update_viewpoint")

func _disconnect_camera() -> void:
	if _camera and is_instance_valid(_camera):
		_camera.disconnect("viewpoint_changed", self, "_update_viewpoint")
	_camera = null

func _update_viewpoint(viewpoint: int) -> void:
	_recenter_button.pressed = viewpoint != VoyagerCamera.VIEWPOINT_BUMPED_UNCENTERED
	_zoom_button.pressed = viewpoint == VoyagerCamera.VIEWPOINT_ZOOM
	_fortyfive_button.pressed = viewpoint == VoyagerCamera.VIEWPOINT_45
	_top_button.pressed = viewpoint == VoyagerCamera.VIEWPOINT_TOP

func _recenter(button_pressed: bool) -> void:
	if button_pressed:
		_camera.move(null, -1, Vector3.ZERO)
	else:
		_recenter_button.pressed = true

func _change_viewpoint(button_pressed: bool, viewpoint: int) -> void:
	if button_pressed:
		_camera.move(null, viewpoint, Vector3.ZERO)
	elif viewpoint == VoyagerCamera.VIEWPOINT_ZOOM:
		_zoom_button.pressed = true
	elif viewpoint == VoyagerCamera.VIEWPOINT_45:
		_fortyfive_button.pressed = true
	elif viewpoint == VoyagerCamera.VIEWPOINT_TOP:
		_top_button.pressed = true
