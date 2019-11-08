# selection_panel.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2019 Charlie Whitfield
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
#

extends DraggablePanel
class_name SelectionPanel
const SCENE := "res://ivoyager/gui_in_game/selection_panel.tscn"


var _range_label: Label
var _fov_label: Label
var _fov_decr: Button
var _fov_incr: Button
var _zoom_view: Button
var _fortyfive_view: Button
var _top_view: Button
var _selection_name: Label
var _selection_image: TextureRect
var _camera: VoyagerCamera
var _focal_lengths: Array


func _on_ready() -> void:
	._on_ready()
	_range_label = $ImageBox/NameBox/CameraRange
	_fov_label = $FOVBox/FOVLabel
	_fov_decr = $FOVBox/FOVButtons/Minus
	_fov_incr = $FOVBox/FOVButtons/Plus
	_zoom_view = $ImageBox/ViewButtons/Zoom
	_fortyfive_view = $ImageBox/ViewButtons/FortyFive
	_top_view = $ImageBox/ViewButtons/Top
	_selection_name = $ImageBox/NameBox/ObjName
	_selection_image = $ImageBox/ObjImage
	Global.connect("camera_ready", self, "_connect_camera")
	Global.connect("gui_refresh_requested", self, "_update_selection")
	_zoom_view.connect("toggled", self, "_change_camera_viewpoint", [VoyagerCamera.VIEWPOINT_ZOOM])
	_fortyfive_view.connect("toggled", self, "_change_camera_viewpoint", [VoyagerCamera.VIEWPOINT_45])
	_top_view.connect("toggled", self, "_change_camera_viewpoint", [VoyagerCamera.VIEWPOINT_TOP])
	_fov_decr.connect("pressed", self, "_increment_focal_length", [-1])
	_fov_incr.connect("pressed", self, "_increment_focal_length", [1])
	get_parent().selection_manager.connect("selection_changed", self, "_update_selection")
	_connect_camera(get_viewport().get_camera())

func _prepare_for_deletion() -> void:
	._prepare_for_deletion()
	Global.disconnect("camera_ready", self, "_connect_camera")
	Global.disconnect("gui_refresh_requested", self, "_update_selection")
	get_parent().selection_manager.disconnect("selection_changed", self, "_update_selection")
	_disconnect_camera()

func _connect_camera(camera: Camera) -> void:
	if _camera != camera:
		_disconnect_camera()
		_camera = camera
		_camera.connect("focal_length_changed", self, "_update_focal_length")
		_camera.connect("camera_lock_changed", self, "_update_camera_lock")
		_camera.connect("viewpoint_changed", self, "_update_viewpoint")
		_focal_lengths = _camera.focal_lengths

func _disconnect_camera() -> void:
	if _camera:
		_camera.disconnect("focal_length_changed", self, "_update_focal_length")
		_camera.disconnect("camera_lock_changed", self, "_update_camera_lock")
		_camera.disconnect("viewpoint_changed", self, "_update_viewpoint")
		_camera = null

func _update_selection() -> void:
	var selection_manager: SelectionManager = get_parent().selection_manager
	_selection_name.text = selection_manager.get_name()
	_selection_image.texture = selection_manager.get_texture_2d()

func _update_focal_length(focal_length: float) -> void:
	_fov_label.text = "%.f mm" % focal_length
	_fov_decr.disabled = focal_length <= _focal_lengths[0]
	_fov_incr.disabled = focal_length >= _focal_lengths[-1]

func _update_camera_lock(is_locked: bool) -> void:
	_range_label.visible = is_locked

func _update_viewpoint(viewpoint: int) -> void:
	_zoom_view.pressed = viewpoint == VoyagerCamera.VIEWPOINT_ZOOM
	_fortyfive_view.pressed = viewpoint == VoyagerCamera.VIEWPOINT_45
	_top_view.pressed = viewpoint == VoyagerCamera.VIEWPOINT_TOP

func _change_camera_viewpoint(_button_pressed: bool, viewpoint: int) -> void:
	_camera.move(null, viewpoint)

func _increment_focal_length(increment: int) -> void:
	_camera.increment_focal_length(increment)
