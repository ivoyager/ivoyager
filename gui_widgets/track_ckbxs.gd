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

# GUI Widget. Requires IVCamera.

const Flags := IVEnums.CameraFlags

var _camera: IVCamera

@onready var _ground_checkbox: CheckBox = $Ground
@onready var _orbit_checkbox: CheckBox = $Orbit
@onready var _ecliptic_checkbox: CheckBox = $Ecliptic


func _ready():
	IVGlobal.camera_ready.connect(_connect_camera)
	_connect_camera(get_viewport().get_camera_3d() as IVCamera)
	var button_group := ButtonGroup.new()
	button_group.pressed.connect(_on_pressed)
	_ecliptic_checkbox.button_group = button_group
	_orbit_checkbox.button_group = button_group
	_ground_checkbox.button_group = button_group


func _connect_camera(camera: IVCamera) -> void:
	if _camera and is_instance_valid(_camera):
		_camera.tracking_changed.disconnect(_update_tracking)
	_camera = camera
	if camera:
		camera.tracking_changed.connect(_update_tracking)


func _on_pressed(button: CheckBox) -> void:
	if !_camera:
		return
	match button.name:
		&"Ground":
			_camera.move_to(null, Flags.TRACK_GROUND)
		&"Orbit":
			_camera.move_to(null, Flags.TRACK_ORBIT)
		&"Ecliptic":
			_camera.move_to(null, Flags.TRACK_ECLIPTIC)


func _update_tracking(flags: int, _disable_flags: int) -> void:
	_ground_checkbox.set_pressed_no_signal(flags & Flags.TRACK_GROUND)
	_orbit_checkbox.set_pressed_no_signal(flags & Flags.TRACK_ORBIT)
	_ecliptic_checkbox.set_pressed_no_signal(flags & Flags.TRACK_ECLIPTIC)

