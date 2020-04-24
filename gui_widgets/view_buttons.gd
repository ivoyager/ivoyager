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
# VIEW_TYPE_ enums.

extends HBoxContainer

var use_small_txt := false
var include_recenter := false

var _camera: Camera
onready var _recenter_button: Button = $Recenter
onready var _zoom_button: Button = $Zoom
onready var _fortyfive_button: Button = $FortyFive
onready var _top_button: Button = $Top

func _ready():
	Global.connect("camera_ready", self, "_connect_camera")
	if use_small_txt:
		_recenter_button.text = "BUTTON_RCTR"
		_zoom_button.text = "BUTTON_ZM"
		_top_button.text = "BUTTON_TP"
	if include_recenter:
		_recenter_button.connect("pressed", self, "_recenter")
	else:
		_recenter_button.queue_free()
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
	if include_recenter:
		_recenter_button.pressed = view_type != Enums.VIEW_UNCENTERED
	_zoom_button.pressed = view_type == Enums.VIEW_ZOOM
	_fortyfive_button.pressed = view_type == Enums.VIEW_45
	_top_button.pressed = view_type == Enums.VIEW_TOP

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
		_camera.move(null, Enums.VIEW_ZOOM, Vector3.ZERO, Vector3.ZERO)
	else:
		_zoom_button.pressed = true

func _fortyfive() -> void:
	if !_camera:
		return
	if _fortyfive_button.pressed:
		_camera.move(null, Enums.VIEW_45, Vector3.ZERO, Vector3.ZERO)
	else:
		_fortyfive_button.pressed = true

func _top() -> void:
	if !_camera:
		return
	if _top_button.pressed:
		_camera.move(null, Enums.VIEW_TOP, Vector3.ZERO, Vector3.ZERO)
	else:
		_top_button.pressed = true
