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
class_name IVLatLongLabel
extends Label

# GUI widget. Requires IVCamera and IVQuantityFormatter.

const CASE_LOWER := IVQuantityFormatter.CASE_LOWER
const N_S_E_W := IVQuantityFormatter.N_S_E_W
const LAT_LONG := IVQuantityFormatter.LAT_LONG
const PITCH_YAW := IVQuantityFormatter.PITCH_YAW
const USE_CARDINAL_DIRECTIONS := IVEnums.BodyFlags.USE_CARDINAL_DIRECTIONS
const USE_PITCH_YAW := IVEnums.BodyFlags.USE_PITCH_YAW

var _camera: IVCamera

@onready var _qf: IVQuantityFormatter = IVGlobal.program.QuantityFormatter


func _ready():
	IVGlobal.camera_ready.connect(_connect_camera)
	_connect_camera(get_viewport().get_camera_3d() as IVCamera) # null ok


func _connect_camera(camera: IVCamera) -> void:
	if _camera and is_instance_valid(_camera): # disconnect previous
		_camera.range_changed.disconnect(_on_latitude_longitude_changed)
		_camera.camera_lock_changed.disconnect(_on_camera_lock_changed)
	_camera = camera
	if camera:
		camera.latitude_longitude_changed.connect(_on_latitude_longitude_changed)
		camera.camera_lock_changed.connect(_on_camera_lock_changed)
		visible = camera.is_camera_lock


func _on_latitude_longitude_changed(lat_long: Vector2, is_ecliptic: bool, selection: IVSelection
		) -> void:
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


func _on_camera_lock_changed(is_camera_lock: bool) -> void:
	visible = is_camera_lock

