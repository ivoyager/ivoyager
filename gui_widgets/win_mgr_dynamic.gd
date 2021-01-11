# win_mgr_dynamic.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
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
# Add to Container (e.g., a GUI PanelContainer) for draggablity and window
# resizing margins. This should be the last child so margin controls are on
# top.
#
# Modify default sizes and snap values from _ready() in the parent Container.
#
# This component replaces WinMgrSimple. (Having both might crash.)

extends Control

enum {MARGIN_TL, MARGIN_T, MARGIN_TR, MARGIN_R, MARGIN_BR, MARGIN_B, MARGIN_BL, MARGIN_L}

# project vars
var screen_edge_snap := 100.0
var panel_edge_snap := 40.0
var default_sizes := [
	Vector2(435.0, 291.0), # GUI_SMALL
	Vector2(575.0, 354.0), # GUI_MEDIUM
	Vector2(712.0, 421.0), # GUI_LARGE
]

# private
var _settings: Dictionary = Global.settings
onready var _viewport := get_viewport()
onready var _parent: Container = get_parent()
var _margin_drag_x := 0.0
var _margin_drag_y := 0.0
var _drag_point := Vector2.ZERO
var _custom_size := Vector2.ZERO

func _ready():
	Global.connect("gui_refresh_requested", self, "_resize")
	Global.connect("setting_changed", self, "_settings_listener")
	_parent.connect("gui_input", self, "_on_parent_input")
	$TL.connect("gui_input", self, "_on_margin_input", [MARGIN_TL])
	$T.connect("gui_input", self, "_on_margin_input", [MARGIN_T])
	$TR.connect("gui_input", self, "_on_margin_input", [MARGIN_TR])
	$R.connect("gui_input", self, "_on_margin_input", [MARGIN_R])
	$BR.connect("gui_input", self, "_on_margin_input", [MARGIN_BR])
	$B.connect("gui_input", self, "_on_margin_input", [MARGIN_B])
	$BL.connect("gui_input", self, "_on_margin_input", [MARGIN_BL])
	$L.connect("gui_input", self, "_on_margin_input", [MARGIN_L])

func _finish_move() -> void:
	_drag_point = Vector2.ZERO
	_snap_horizontal()
	_snap_vertical()
	_fix_offscreen()
	_set_anchors_to_position()

func _snap_horizontal() -> void:
	var left := _parent.rect_position.x
	if left < screen_edge_snap:
		_parent.rect_position.x = 0.0
		return
	var right := left + _parent.rect_size.x
	var screen_right := _viewport.size.x
	if right > screen_right - screen_edge_snap:
		_parent.rect_position.x = screen_right - right + left
		return
	var top := _parent.rect_position.y
	var bottom := top + _parent.rect_size.y
	for child in _parent.get_parent().get_children():
		var test_panel := child as PanelContainer
		if !test_panel or test_panel == _parent:
			continue
		var panel_top := test_panel.rect_position.y
		if bottom < panel_top:
			continue
		var panel_bottom := panel_top + test_panel.rect_size.y
		if top > panel_bottom:
			continue
		var panel_left := test_panel.rect_position.x
		if abs(right - panel_left) < panel_edge_snap:
			_parent.rect_position.x = panel_left - right + left
			return
		var panel_right := panel_left + test_panel.rect_size.x
		if abs(left - panel_right) < panel_edge_snap:
			_parent.rect_position.x = panel_right
			return

func _snap_vertical() -> void:
	var top := _parent.rect_position.y
	if top < screen_edge_snap:
		_parent.rect_position.y = 0.0
		return
	var bottom := top + _parent.rect_size.y
	var screen_bottom := _viewport.size.y
	if bottom > screen_bottom - screen_edge_snap:
		_parent.rect_position.y = screen_bottom - bottom + top
		return
	var left := _parent.rect_position.x
	var right := left + _parent.rect_size.x
	for child in _parent.get_parent().get_children():
		var test_panel := child as PanelContainer
		if !test_panel or test_panel == _parent:
			continue
		var panel_left := test_panel.rect_position.x
		if right < panel_left:
			continue
		var panel_top := test_panel.rect_position.y
		if abs(bottom - panel_top) < panel_edge_snap:
			_parent.rect_position.y = panel_top - bottom + top
			return
		var panel_bottom := panel_top + test_panel.rect_size.y
		if abs(top - panel_bottom) < panel_edge_snap:
			_parent.rect_position.y = panel_bottom
			return

func _fix_offscreen() -> void:
	var rect := _parent.get_rect()
	var screen_rect := get_viewport_rect()
	if screen_rect.encloses(rect):
		return
	if rect.position.x < 0.0:
		_parent.rect_position.x = 0.0
	elif rect.end.x > screen_rect.end.x:
		_parent.rect_position.x = screen_rect.end.x - rect.size.x
	if rect.position.y < 0.0:
		_parent.rect_position.y = 0.0
	elif rect.end.y > screen_rect.end.y:
		_parent.rect_position.y = screen_rect.end.y - rect.size.y

func _set_anchors_to_position() -> void:
	var position := _parent.rect_position
	var size := _parent.rect_size
	var horizontal_anchor := clamp(position.x / (_viewport.size.x - size.x), 0.0, 1.0)
	var vertical_anchor := clamp(position.y / (_viewport.size.y - size.y), 0.0, 1.0)
	_parent.anchor_left = horizontal_anchor
	_parent.anchor_right = horizontal_anchor
	_parent.anchor_top = vertical_anchor
	_parent.anchor_bottom = vertical_anchor
	_parent.rect_position = position # setting anchors screws up position (Godot bug?)

func _reposition_to_anchors() -> void:
	# assumes anchor_left == anchor_right and anchor_top == anchor_bottom
	_parent.rect_position.x = _parent.anchor_left * (_viewport.size.x - _parent.rect_size.x)
	_parent.rect_position.y = _parent.anchor_top * (_viewport.size.y - _parent.rect_size.y)

func _resize() -> void:
	var gui_size: int = _settings.gui_size
	_parent.rect_min_size = default_sizes[gui_size]
	_parent.rect_size = _custom_size # only matters if custom > default in x or y
	_reposition_to_anchors()

func _update_for_user_resize() -> void:
	# If user resized to minimum (= settings default) in either dimension, we
	# assume that they want the panel to resize again with settings changes.
	var gui_size: int = _settings.gui_size
	var default_size: Vector2 = default_sizes[gui_size]
	_custom_size = _parent.rect_size
	if _custom_size.x == default_size.x:
		_custom_size.x = 0.0
	if _custom_size.y == default_size.y:
		_custom_size.y = 0.0

func _settings_listener(setting: String, _value) -> void:
	match setting:
		"gui_size":
			_resize()

func _on_parent_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			accept_event()
			if event.pressed:
				_drag_point = get_global_mouse_position() - _parent.rect_position
			else:
				_finish_move()
	elif event is InputEventMouseMotion and _drag_point:
		accept_event()
		_parent.rect_position = get_global_mouse_position() - _drag_point

func _on_margin_input(event: InputEvent, location: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			accept_event()
			var mouse_pos := get_global_mouse_position()
			if event.pressed:
				match location:
					MARGIN_TL, MARGIN_T, MARGIN_TR:
						_margin_drag_y = mouse_pos.y - _parent.margin_top
					MARGIN_BL, MARGIN_B, MARGIN_BR:
						_margin_drag_y = mouse_pos.y - _parent.margin_bottom
				match location:
					MARGIN_TL, MARGIN_L, MARGIN_BL:
						_margin_drag_x = mouse_pos.x - _parent.margin_left
					MARGIN_TR, MARGIN_R, MARGIN_BR:
						_margin_drag_x = mouse_pos.x - _parent.margin_right
			else:
				_margin_drag_x = 0.0
				_margin_drag_y = 0.0
				_update_for_user_resize()
				_finish_move() # is this needed?
	elif event is InputEventMouseMotion and (_margin_drag_x or _margin_drag_y):
		accept_event()
		var mouse_pos := get_global_mouse_position()
		match location:
			MARGIN_TL, MARGIN_T, MARGIN_TR:
				_parent.margin_top = mouse_pos.y - _margin_drag_y
			MARGIN_BL, MARGIN_B, MARGIN_BR:
				_parent.margin_bottom = mouse_pos.y - _margin_drag_y
		match location:
			MARGIN_TL, MARGIN_L, MARGIN_BL:
				_parent.margin_left = mouse_pos.x - _margin_drag_x
			MARGIN_TR, MARGIN_R, MARGIN_BR:
				_parent.margin_right = mouse_pos.x - _margin_drag_x
