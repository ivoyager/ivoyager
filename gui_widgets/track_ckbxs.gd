# track_ckbxs.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2023 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield in the US
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
class_name IVTrackCkbxs
extends HBoxContainer

# GUI Widget.

const Flags := IVEnums.CameraFlags
const DisabledFlags := IVEnums.CameraDisabledFlags


var hide_highest_track := true # deselect 'Ground' & 'Orbit' to get 'Ecliptic'

var _camera: Camera

onready var _ecliptic_checkbox: CheckBox = $Ecliptic
onready var _orbit_checkbox: CheckBox = $Orbit
onready var _ground_checkbox: CheckBox = $Ground


func _ready():
	IVGlobal.connect("camera_ready", self, "_connect_camera")
	_connect_camera(get_viewport().get_camera())
	_ecliptic_checkbox.connect("pressed", self, "_on_ecliptic_pressed")
	_orbit_checkbox.connect("pressed", self, "_on_orbit_pressed")
	_ground_checkbox.connect("pressed", self, "_on_ground_pressed")


func _connect_camera(camera: Camera) -> void:
	if _camera != camera:
		_disconnect_camera()
		_camera = camera
		_camera.connect("tracking_changed", self, "_update_tracking")


func _disconnect_camera() -> void:
	if _camera and is_instance_valid(_camera):
		_camera.disconnect("tracking_changed", self, "_update_tracking")
	_camera = null


func _update_tracking(flags: int, _disable_flags: int) -> void:
	_ecliptic_checkbox.pressed = bool(flags & Flags.TRACK_ECLIPTIC)
	_orbit_checkbox.pressed = bool(flags & Flags.TRACK_ORBIT)
	_ground_checkbox.pressed = bool(flags & Flags.TRACK_GROUND)


func _on_ecliptic_pressed() -> void:
	if !_camera:
		return
	if _ecliptic_checkbox.pressed:
		_camera.move_to(null, Flags.TRACK_ECLIPTIC)
	else:
		_ecliptic_checkbox.pressed = true


func _on_orbit_pressed() -> void:
	if !_camera:
		return
	if _orbit_checkbox.pressed:
		_camera.move_to(null, Flags.TRACK_ORBIT)
	else:
		_orbit_checkbox.pressed = true


func _on_ground_pressed() -> void:
	if !_camera:
		return
	if _ground_checkbox.pressed:
		_camera.move_to(null, Flags.TRACK_GROUND)
	else:
		_ground_checkbox.pressed = true
