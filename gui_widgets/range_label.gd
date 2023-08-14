# range_label.gd
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
class_name IVRangeLabel
extends Label

# GUI widget. Requires IVCamera and IVQuantityFormatter.

var _camera: IVCamera

@onready var _qf: IVQuantityFormatter = IVGlobal.program.QuantityFormatter


func _ready():
	IVGlobal.camera_ready.connect(_connect_camera)
	_connect_camera(get_viewport().get_camera_3d() as IVCamera) # null ok


func _connect_camera(camera: IVCamera) -> void:
	if _camera and is_instance_valid(_camera):
		_camera.range_changed.disconnect(_on_range_changed)
		_camera.camera_lock_changed.disconnect(_on_camera_lock_changed)
	_camera = camera
	if camera:
		camera.range_changed.connect(_on_range_changed)
		camera.camera_lock_changed.connect(_on_camera_lock_changed)
		visible = camera.is_camera_lock


func _on_range_changed(new_range: float) -> void:
	text = _qf.number_option(new_range, _qf.LENGTH_M_KM_AU, "", 3)


func _on_camera_lock_changed(is_camera_lock: bool) -> void:
	visible = is_camera_lock

