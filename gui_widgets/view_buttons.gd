# view_buttons.gd
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
class_name IVViewButtons
extends HBoxContainer

# GUI widget. Expects the camera to have "view_type_changed" signal.

const CameraFlags := IVEnums.CameraFlags

var enable_outward := false # WIP for astronomy; it's pretty crappy now
var use_small_txt := false

var _camera: Camera

onready var _zoom_button: Button = $Zoom
onready var _45_button: Button = $FortyFive
onready var _top_button: Button = $Top
onready var _outward_button: Button = $Outward


func _ready():
	IVGlobal.connect("camera_ready", self, "_connect_camera")
	_zoom_button.connect("pressed", self, "_on_zoom_pressed")
	_45_button.connect("pressed", self, "_on_45_pressed")
	_top_button.connect("pressed", self, "_on_top_pressed")
	_outward_button.connect("pressed", self, "_on_outward_pressed")
	if IVGlobal.state.is_system_built:
		_on_system_built(false)
	else:
		IVGlobal.connect("system_tree_built_or_loaded", self, "_on_system_built")
	_connect_camera(get_viewport().get_camera())


func _on_system_built(_is_loaded_game: bool) -> void:
	if enable_outward:
		_outward_button.show()
	if use_small_txt:
		_zoom_button.text = "BUTTON_ZM"
		_top_button.text = "BUTTON_TP"
		_outward_button.text = "BUTTON_OUTWD"


func _connect_camera(camera: Camera) -> void:
	if _camera != camera:
		_disconnect_camera()
		_camera = camera
		_camera.connect("view_type_changed", self, "_update_view_type")


func _disconnect_camera() -> void:
	if _camera and is_instance_valid(_camera):
		_camera.disconnect("view_type_changed", self, "_update_view_type")
	_camera = null


func _update_view_type(flags: int, _disable_flags: int) -> void:
	_zoom_button.pressed = bool(flags & CameraFlags.VIEW_ZOOM)
	_45_button.pressed = bool(flags & CameraFlags.VIEW_45)
	_top_button.pressed = bool(flags & CameraFlags.VIEW_TOP)
	_outward_button.pressed = bool(flags & CameraFlags.VIEW_OUTWARD)


func _on_zoom_pressed() -> void:
	if !_camera:
		return
	if _zoom_button.pressed:
		_camera.move_to(null, CameraFlags.VIEW_ZOOM)
	else:
		_zoom_button.pressed = true


func _on_45_pressed() -> void:
	if !_camera:
		return
	if _45_button.pressed:
		_camera.move_to(null, CameraFlags.VIEW_45)
	else:
		_45_button.pressed = true


func _on_top_pressed() -> void:
	if !_camera:
		return
	if _top_button.pressed:
		_camera.move_to(null, CameraFlags.VIEW_TOP)
	else:
		_top_button.pressed = true


func _on_outward_pressed() -> void:
	if !_camera:
		return
	if _outward_button.pressed:
		_camera.move_to(null, CameraFlags.VIEW_OUTWARD)
	else:
		_outward_button.pressed = true
