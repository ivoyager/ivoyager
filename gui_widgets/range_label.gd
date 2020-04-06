# range_label.gd
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
# GUI widget. Visible when camera "locked". Expects camera signals
# "range_changed" and "camera_lock_changed".

extends Label

onready var _qty_strs: QtyStrs = Global.program.QtyStrs
var _camera: Camera

func _ready():
	Global.connect("camera_ready", self, "_connect_camera")
	_connect_camera(get_viewport().get_camera())
	
func _connect_camera(camera: Camera) -> void:
	if _camera != camera:
		_disconnect_camera()
		_camera = camera
		_camera.connect("range_changed", self, "_on_range_changed")
		_camera.connect("camera_lock_changed", self, "_on_camera_lock_changed")

func _disconnect_camera() -> void:
	if _camera and is_instance_valid(_camera):
		_camera.disconnect("range_changed", self, "_update")
		_camera.disconnect("camera_lock_changed", self, "_update_camera_lock")
	_camera = null

func _on_range_changed(new_range: float) -> void:
	text = _qty_strs.length(new_range, true)

func _on_camera_lock_changed(is_locked: bool) -> void:
	visible = is_locked
