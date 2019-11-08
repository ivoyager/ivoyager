# camera_range.gd
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

extends Label
class_name CameraRange
const SCENE := "res://ivoyager/gui_widgets/camera_range.tscn"

onready var _string_maker: StringMaker = Global.objects.StringMaker
var _camera: Camera

func _ready():
	Global.connect("camera_ready", self, "_connect_camera")
	_connect_camera(get_viewport().get_camera())
	
func _connect_camera(camera: Camera) -> void:
	if _camera != camera:
		_disconnect_camera()
		_camera = camera
		_camera.connect("range_changed", self, "_update")

func _disconnect_camera() -> void:
	if _camera:
		_camera.disconnect("range_changed", self, "_update")
		_camera = null

func _update(new_range: float) -> void:
	text = _string_maker.get_str(new_range, _string_maker.DISPLAY_LENGTH)

