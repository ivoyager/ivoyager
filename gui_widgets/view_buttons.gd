# view_buttons.gd
# This file is part of I, Voyager
# https://ivoyager.dev
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
# GUI widget. Expects the camera to have "view_type_changed" signal and to use
# VoyagerCamera VIEW_TYPE_ enums.

extends HBoxContainer

var _camera: Camera
onready var _recenter_button: Button = $Recenter
onready var _zoom_button: Button = $Zoom
onready var _fortyfive_button: Button = $FortyFive
onready var _top_button: Button = $Top

func _ready():
	Global.connect("camera_ready", self, "_connect_camera")
	_recenter_button.connect("pressed", self, "_recenter")
	_zoom_button.connect("pressed", self, "_zoom")
	_fortyfive_button.connect("pressed", self, "_fortyfive")
	_top_button.connect("pressed", self, "_top")
	_connect_camera(get_viewport().get_camera())

func _connect_camera(camera: Camera) -> void:
	if _camera != camera:
		_disconnect_camera()
		_camera = camera
		_camera.connect("view_type_changed", self, "_update_view_type")

func _disconnect_camera() -> void:
	if _camera and is_instance_valid(_camera):
		_camera.disconnect("view_type_changed", self, "_update_view_type")
	_camera = null

func _update_view_type(view_type: int) -> void:
	_recenter_button.pressed = view_type != VoyagerCamera.VIEW_TYPE_UNCENTERED
	_zoom_button.pressed = view_type == VoyagerCamera.VIEW_TYPE_ZOOM
	_fortyfive_button.pressed = view_type == VoyagerCamera.VIEW_TYPE_45
	_top_button.pressed = view_type == VoyagerCamera.VIEW_TYPE_TOP

func _recenter() -> void:
	if !_camera:
		return
	if _recenter_button.pressed:
		_camera.move(null, -1, Vector3.ZERO, Vector3.ZERO)
	else:
		_recenter_button.pressed = true

func _zoom() -> void:
	if !_camera:
		return
	if _zoom_button.pressed:
		_camera.move(null, VoyagerCamera.VIEW_TYPE_ZOOM, Vector3.ZERO, Vector3.ZERO)
	else:
		_zoom_button.pressed = true

func _fortyfive() -> void:
	if !_camera:
		return
	if _fortyfive_button.pressed:
		_camera.move(null, VoyagerCamera.VIEW_TYPE_45, Vector3.ZERO, Vector3.ZERO)
	else:
		_fortyfive_button.pressed = true

func _top() -> void:
	if !_camera:
		return
	if _top_button.pressed:
		_camera.move(null, VoyagerCamera.VIEW_TYPE_TOP, Vector3.ZERO, Vector3.ZERO)
	else:
		_top_button.pressed = true
