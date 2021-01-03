# track_controler.gd
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
# GUI Widget

extends HBoxContainer

const TRACK_NONE = Enums.TrackTypes.TRACK_NONE
const TRACK_ORBIT = Enums.TrackTypes.TRACK_ORBIT
const TRACK_GROUND = Enums.TrackTypes.TRACK_GROUND

onready var _orbit_checkbox: CheckBox = $Orbit
onready var _ground_checkbox: CheckBox = $Ground
var _camera: Camera


func _ready():
	Global.connect("camera_ready", self, "_connect_camera")
	_connect_camera(get_viewport().get_camera())
	_orbit_checkbox.connect("pressed", self, "_on_orbit_pressed")
	_ground_checkbox.connect("pressed", self, "_on_ground_pressed")

func _connect_camera(camera: Camera) -> void:
	if _camera != camera:
		_disconnect_camera()
		_camera = camera
		_camera.connect("track_type_changed", self, "_update_track_type")
		_update_track_type(_camera.track_type)

func _disconnect_camera() -> void:
	if _camera and is_instance_valid(_camera):
		_camera.disconnect("track_type_changed", self, "_update_track_type")
	_camera = null

func _update_track_type(track_type: int) -> void:
	_orbit_checkbox.pressed = track_type == TRACK_ORBIT
	_ground_checkbox.pressed = track_type == TRACK_GROUND

func _on_orbit_pressed() -> void:
	if !_camera:
		return
	if _orbit_checkbox.pressed:
		_camera.change_track_type(TRACK_ORBIT)
	else:
		_camera.change_track_type(TRACK_NONE)

func _on_ground_pressed() -> void:
	if !_camera:
		return
	if _ground_checkbox.pressed:
		_camera.change_track_type(TRACK_GROUND)
	else:
		_camera.change_track_type(TRACK_NONE)

