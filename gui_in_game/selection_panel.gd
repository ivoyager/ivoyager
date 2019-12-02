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
var _selection_name: Label
var _selection_image: TextureRect
var _camera: VoyagerCamera


func _on_ready() -> void:
	._on_ready()
	_range_label = $ImageBox/NameBox/CameraRange
	_selection_name = $ImageBox/NameBox/ObjName
	_selection_image = $ImageBox/ObjImage
	Global.connect("camera_ready", self, "_connect_camera")
	Global.connect("gui_refresh_requested", self, "_update_selection")
	_selection_image.connect("gui_input", self, "_on_selection_image_gui_input")
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
		_camera.connect("camera_lock_changed", self, "_update_camera_lock")

func _disconnect_camera() -> void:
	if _camera:
		_camera.disconnect("camera_lock_changed", self, "_update_camera_lock")
		_camera = null

func _update_selection() -> void:
	var selection_manager: SelectionManager = get_parent().selection_manager
	_selection_name.text = selection_manager.get_name()
	_selection_image.texture = selection_manager.get_texture_2d()

func _update_camera_lock(is_locked: bool) -> void:
	_range_label.visible = is_locked

func _on_selection_image_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		var selection_manager: SelectionManager = get_parent().selection_manager
		Global.emit_signal("move_camera_to_selection_requested", selection_manager.selection_item, -1, Vector3.ZERO)
