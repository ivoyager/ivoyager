# lat_long_label.gd
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
extends Label

# GUI widget. Expects the camera to have signals:
#     "latitude_longitude_changed"
#     "camera_lock_changed"


const CASE_LOWER := IVQuantityFormatter.CASE_LOWER
const N_S_E_W := IVQuantityFormatter.N_S_E_W
const LAT_LONG := IVQuantityFormatter.LAT_LONG
const PITCH_YAW := IVQuantityFormatter.PITCH_YAW
const USE_CARDINAL_DIRECTIONS := IVEnums.BodyFlags.USE_CARDINAL_DIRECTIONS
const USE_PITCH_YAW := IVEnums.BodyFlags.USE_PITCH_YAW


var _camera: Camera

onready var _qf: IVQuantityFormatter = IVGlobal.program.QuantityFormatter


func _ready():
	IVGlobal.connect("camera_ready", self, "_connect_camera")
	_connect_camera(get_viewport().get_camera())
	
	
func _connect_camera(camera: Camera) -> void:
	if _camera != camera:
		_disconnect_camera()
		_camera = camera
		_camera.connect("latitude_longitude_changed", self, "_on_latitude_longitude_changed")
		_camera.connect("camera_lock_changed", self, "_on_camera_lock_changed")


func _disconnect_camera() -> void:
	if _camera and is_instance_valid(_camera):
		_camera.disconnect("range_changed", self, "_on_latitude_longitude_changed")
		_camera.disconnect("camera_lock_changed", self, "_update_camera_lock")
	_camera = null


func _on_latitude_longitude_changed(lat_long: Vector2, is_ecliptic: bool,
		selection: IVSelection) -> void:
	var lat_long_type := N_S_E_W
	if !is_ecliptic:
		var flags := selection.get_flags()
		if flags & USE_CARDINAL_DIRECTIONS:
			lat_long_type = N_S_E_W
		elif flags & USE_PITCH_YAW:
			lat_long_type = PITCH_YAW
		else:
			lat_long_type = LAT_LONG
	var new_text := _qf.latitude_longitude(lat_long, 1, lat_long_type) # , false, CASE_LOWER)
	if is_ecliptic:
		new_text += " (" + tr("TXT_ECLIPTIC") + ")"
	text = new_text


func _on_camera_lock_changed(is_locked: bool) -> void:
	visible = is_locked
