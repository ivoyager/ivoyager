# fov_box.gd
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
#
# This widget expects the camera to have signal "focal_length_changed", member
# "focal_lengths" and function "increment_focal_length".

extends VBoxContainer
class_name FOVBox
const SCENE := "res://ivoyager/gui_widgets/fov_box.tscn"

var _camera: Camera
onready var _fov_label: Label = $FOVLabel
onready var _fov_decr: Button = $FOVButtons/Minus
onready var _fov_incr: Button = $FOVButtons/Plus

func _ready():
	Global.connect("camera_ready", self, "_connect_camera")
	_fov_decr.connect("pressed", self, "_increment_focal_length", [-1])
	_fov_incr.connect("pressed", self, "_increment_focal_length", [1])
	_connect_camera(get_viewport().get_camera())

func _connect_camera(camera: Camera) -> void:
	if _camera != camera:
		_disconnect_camera()
		_camera = camera
		_camera.connect("focal_length_changed", self, "_update_focal_length")

func _disconnect_camera() -> void:
	if _camera:
		_camera.disconnect("focal_length_changed", self, "_update_focal_length")
		_camera = null

func _update_focal_length(focal_length: float) -> void:
	_fov_label.text = "%.f mm" % focal_length
	var focal_lengths: Array = _camera.focal_lengths
	_fov_decr.disabled = focal_length <= focal_lengths[0]
	_fov_incr.disabled = focal_length >= focal_lengths[-1]

func _increment_focal_length(increment: int) -> void:
	_camera.increment_focal_length(increment)
