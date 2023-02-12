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

const TRACK_ECLIPTIC = IVEnums.TrackType.TRACK_ECLIPTIC
const TRACK_ORBIT = IVEnums.TrackType.TRACK_ORBIT
const TRACK_GROUND = IVEnums.TrackType.TRACK_GROUND

var _camera: Camera

onready var _orbit_checkbox: CheckBox = $Orbit
onready var _ground_checkbox: CheckBox = $Ground


func _ready():
	IVGlobal.connect("camera_ready", self, "_connect_camera")
	_connect_camera(get_viewport().get_camera())
	_orbit_checkbox.connect("pressed", self, "_on_orbit_pressed")
	_ground_checkbox.connect("pressed", self, "_on_ground_pressed")


func remove_track_label() -> void:
	$TrackLabel.queue_free()


func _connect_camera(camera: Camera) -> void:
	if _camera != camera:
		_disconnect_camera()
		_camera = camera
		_camera.connect("tracking_changed", self, "_update_tracking")
#		_update_tracking(_camera.track_type)


func _disconnect_camera() -> void:
	if _camera and is_instance_valid(_camera):
		_camera.disconnect("tracking_changed", self, "_update_tracking")
	_camera = null


func _update_tracking(track_type: int, is_ecliptic: bool) -> void:
	_orbit_checkbox.pressed = track_type == TRACK_ORBIT
	_ground_checkbox.disabled = is_ecliptic
	_ground_checkbox.pressed = track_type == TRACK_GROUND
	_orbit_checkbox.disabled = is_ecliptic


func _on_orbit_pressed() -> void:
	if !_camera:
		return
	if _orbit_checkbox.pressed:
		_camera.change_track_type(TRACK_ORBIT)
	else:
		_camera.change_track_type(TRACK_ECLIPTIC)


func _on_ground_pressed() -> void:
	if !_camera:
		return
	if _ground_checkbox.pressed:
		_camera.change_track_type(TRACK_GROUND)
	else:
		_camera.change_track_type(TRACK_ECLIPTIC)
