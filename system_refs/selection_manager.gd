# selection_manager.gd
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
# Wraps currently selected item and keeps selection history.

extends Reference
class_name SelectionManager

signal selection_changed()

# persisted
var selection_item: SelectionItem
var _is_camera_selection := false
const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["_is_camera_selection"]
const PERSIST_OBJ_PROPERTIES := ["selection_item"]

# private
var _root: Viewport = Global.get_tree().get_root()
var _registrar: Registrar = Global.objects.Registrar
var _history := [] # weakrefs
var _history_index := -1
var _supress_history := false
var _supress_camera_move := false
var _connected_camera: VoyagerCamera # null unless _is_camera_selection

func init_as_camera_selection() -> void:
	_is_camera_selection = true

func select(selection_item_: SelectionItem) -> void:
	if selection_item == selection_item_:
		_supress_camera_move = false
		return
	selection_item = selection_item_
	if !_supress_camera_move and _connected_camera and _connected_camera.is_camera_lock:
		_connected_camera.move(selection_item)
	_supress_camera_move = false
	_add_history()
	emit_signal("selection_changed")

func select_body(body_: Body) -> void:
	var name := body_.name
	var selection_item_: SelectionItem = _registrar.selection_items[name]
	select(selection_item_)

func get_name() -> String:
	return selection_item.name
	
func get_texture_2d() -> Texture:
	return selection_item.texture_2d

func get_body() -> Body:
	return selection_item.body
	
func is_body() -> bool:
	return selection_item.is_body

func back() -> void:
	if _history_index < 1:
		return
	_history_index -= 1
	var wr: WeakRef = _history[_history_index]
	var new_selection: SelectionItem = wr.get_ref()
	if new_selection:
		_supress_history = true
		select(new_selection)
	else:
		back()
	
func forward() -> void:
	if _history_index > _history.size() - 2:
		return
	_history_index += 1
	var wr: WeakRef = _history[_history_index]
	var new_selection: SelectionItem = wr.get_ref()
	if new_selection:
		_supress_history = true
		select(new_selection)
	else:
		forward()
	
func up() -> void:
	var new_selection_name := selection_item.up_selection_name
	if new_selection_name:
		var new_selection: SelectionItem = _registrar.selection_items[new_selection_name]
		select(new_selection)

func can_go_back() -> bool:
	return _history_index > 0
	
func can_go_forward() -> bool:
	return _history_index < _history.size() - 1
	
func can_go_up() -> bool:
	return selection_item and selection_item.up_selection_name

func down() -> void:
	pass

func toggle(_incr: int) -> void:
	pass

func toggle_type(_incr: int, _selection_type: int, _and_selection_type := -1) -> void:
	pass

func _init() -> void:
	_on_init()

func _on_init() -> void:
	Global.connect("system_tree_ready", self, "_hook_up_if_camera_selection")

func _hook_up_if_camera_selection(_is_new_game: bool) -> void:
	if _is_camera_selection:
		Global.connect("camera_ready", self, "_connect_camera")
		_connect_camera(_root.get_camera())

func _connect_camera(camera: Camera) -> void:
	if _connected_camera == camera:
		return
	_disconnect_camera()
	_connected_camera = camera
	_connected_camera.connect("move_started", self, "_process_camera_move")
	_connected_camera.connect("camera_lock_changed", self, "_process_camera_lock_change")

func _disconnect_camera() -> void:
	if !_connected_camera:
		return
	_connected_camera.disconnect("move_started", self, "_process_camera_move")
	_connected_camera.disconnect("camera_lock_changed", self, "_process_camera_lock_change")
	_connected_camera = null

func _process_camera_move(to_body: Body, is_camera_lock: bool) -> void:
	if is_camera_lock and to_body != selection_item.spatial:
		_supress_camera_move = true
		select_body(to_body)

func _process_camera_lock_change(is_camera_lock: bool) -> void:
	if is_camera_lock and _connected_camera.spatial != selection_item.spatial:
		_connected_camera.move(selection_item)

func _add_history() -> void:
	if _supress_history:
		_supress_history = false
		return
	if _history_index >= 0:
		var last_wr: WeakRef = _history[_history_index]
		var last_selection_item: SelectionItem = last_wr.get_ref()
		if last_selection_item == selection_item:
			return
	_history_index += 1
	if _history.size() > _history_index:
		_history.resize(_history_index)
	var wr := weakref(selection_item)
	_history.append(wr)
