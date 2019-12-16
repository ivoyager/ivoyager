# viewpoint_box.gd
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
onready var _zoom_view: Button = $Zoom
onready var _fortyfive_view: Button = $FortyFive
onready var _top_view: Button = $Top

func _ready():
	Global.connect("camera_ready", self, "_connect_camera")
	_zoom_view.connect("toggled", self, "_change_camera_viewpoint", [VoyagerCamera.VIEWPOINT_ZOOM])
	_fortyfive_view.connect("toggled", self, "_change_camera_viewpoint", [VoyagerCamera.VIEWPOINT_45])
	_top_view.connect("toggled", self, "_change_camera_viewpoint", [VoyagerCamera.VIEWPOINT_TOP])
	_connect_camera(get_viewport().get_camera())

func _connect_camera(camera: Camera) -> void:
	if _camera != camera:
		_disconnect_camera()
		_camera = camera
		_camera.connect("viewpoint_changed", self, "_update_viewpoint")

func _disconnect_camera() -> void:
	if _camera:
		_camera.disconnect("viewpoint_changed", self, "_update_viewpoint")
		_camera = null

func _update_viewpoint(viewpoint: int) -> void:
	_zoom_view.pressed = viewpoint == VoyagerCamera.VIEWPOINT_ZOOM
	_fortyfive_view.pressed = viewpoint == VoyagerCamera.VIEWPOINT_45
	_top_view.pressed = viewpoint == VoyagerCamera.VIEWPOINT_TOP

func _change_camera_viewpoint(_button_pressed: bool, viewpoint: int) -> void:
	_camera.move(null, viewpoint, Vector3.ZERO)
