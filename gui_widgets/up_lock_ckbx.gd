# up_lock_ckbx.gd
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
class_name IVUpLockCkbx
extends CheckBox

# GUI Widget. Requires IVCamera.

const Flags := IVEnums.CameraFlags

var _camera: IVCamera


func _ready() -> void:
	IVGlobal.camera_ready.connect(_connect_camera)
	_connect_camera(get_viewport().get_camera_3d() as IVCamera)
	pressed.connect(_on_pressed)


func _connect_camera(camera: IVCamera) -> void:
	if _camera and is_instance_valid(_camera):
		_camera.up_lock_changed.disconnect(_update_ckbx)
	_camera = camera
	if camera:
		camera.up_lock_changed.connect(_update_ckbx)


func _update_ckbx(flags: int, _disable_flags: int) -> void:
	button_pressed = bool(flags & Flags.UP_LOCKED)


func _on_pressed() -> void:
	if !_camera:
		return
	_camera.set_up_lock(button_pressed)

