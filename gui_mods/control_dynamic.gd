# control_dynamic.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield
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
# Use only one of the Control mods:
#    ControlSized - resizes with Options/GUI Size
#    ControlDraggable - above plus user draggable
#    ControlDynamic - above plus user resizing margins
#
# Add to Control (eg, a PanelContainer or PopupPanel) for draggablity and window
# resizing margins. This should be the last child so margin controls are on
# top.  Assumes parent Control is NOT in a Container and has anchor_left ==
# anchor_right and anchor_top == anchor_bottom (ie, panels aren't intended to
# strech if viewport stretches).
#
# Modify default sizes and snap values from _ready() in the parent Control.

extends Control

enum {TL, T, TR, R, BR, B, BL, L}

# project vars
var screen_edge_snap := 100.0
var panel_edge_snap := 40.0
var default_sizes := [
	# Use rounded floats. Values applied at runtime may be reduced by
	# max_default_screen_proportions, below.
	Vector2(435.0, 291.0), # GUI_SMALL
	Vector2(575.0, 354.0), # GUI_MEDIUM
	Vector2(712.0, 421.0), # GUI_LARGE
]
var max_default_screen_proportions := Vector2(0.45, 0.45)

# private
var _settings: Dictionary = Global.settings
onready var _viewport := get_viewport()
onready var _parent: Control = get_parent()
var _margin_drag_x := 0.0
var _margin_drag_y := 0.0
var _drag_point := Vector2.ZERO
var _custom_size := Vector2.ZERO
var _default_size: Vector2

func set_min_size() -> void:
	for i in range(default_sizes.size()):
		default_sizes[i] = Vector2.ZERO

func _ready():
	Global.connect("update_gui_needed", self, "_on_update_gui_needed")
	Global.connect("setting_changed", self, "_settings_listener")
	_viewport.connect("size_changed", self, "_resize")
	_parent.connect("gui_input", self, "_on_parent_input")
	$TL.connect("gui_input", self, "_on_margin_input", [TL])
	$T.connect("gui_input", self, "_on_margin_input", [T])
	$TR.connect("gui_input", self, "_on_margin_input", [TR])
	$R.connect("gui_input", self, "_on_margin_input", [R])
	$BR.connect("gui_input", self, "_on_margin_input", [BR])
	$B.connect("gui_input", self, "_on_margin_input", [B])
	$BL.connect("gui_input", self, "_on_margin_input", [BL])
	$L.connect("gui_input", self, "_on_margin_input", [L])
	set_process_input(false) # only during drag

func _on_update_gui_needed() -> void:
	_resize()
	_finish_move()

func _finish_move() -> void:
	_drag_point = Vector2.ZERO
	set_process_input(false)
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
	var extra_x := _viewport.size.x - size.x
	var horizontal_anchor := 1.0
	if extra_x > 0.0:
		horizontal_anchor = clamp(position.x / extra_x, 0.0, 1.0)
	var extra_y := _viewport.size.y - size.y
	var vertical_anchor := 1.0
	if extra_y > 0.0:
		vertical_anchor = clamp(position.y / extra_y, 0.0, 1.0)
	_parent.anchor_left = horizontal_anchor
	_parent.anchor_right = horizontal_anchor
	_parent.anchor_top = vertical_anchor
	_parent.anchor_bottom = vertical_anchor
	_parent.rect_position = position # setting anchors screws up position (Godot bug?)

func _resize() -> void:
	var default_size := _get_default_size()
	if _default_size == default_size:
		return
	_default_size = default_size
	_parent.rect_min_size = default_size
	# Some content needs immediate resize (eg, PlanetMoonButtons so it can
	# conform to its parent container). Other content needs delayed resize.
	# _custom_size may be (0, 0) or smaller than rect_min_size now, but code
	# below will trigger immediate and delayed size refreshes in any case. 
	_parent.rect_size = _custom_size
	yield(get_tree(), "idle_frame")
	_parent.rect_size = _custom_size
	# reposition to anchors given new actual size
	_parent.rect_position.x = _parent.anchor_left * (_viewport.size.x - _parent.rect_size.x)
	_parent.rect_position.y = _parent.anchor_top * (_viewport.size.y - _parent.rect_size.y)

func _get_default_size() -> Vector2:
	var gui_size: int = _settings.gui_size
	var default_size: Vector2 = default_sizes[gui_size]
	var max_x := round(_viewport.size.x * max_default_screen_proportions.x)
	var max_y := round(_viewport.size.y * max_default_screen_proportions.y)
	if default_size.x > max_x:
		default_size.x = max_x
	if default_size.y > max_y:
		default_size.y = max_y
	return default_size

func _update_custom_size() -> void:
	# If user resized to (or near) minimum in either dimension, we assume
	# they want default sizing (so it can shrink again on settings change).
	_custom_size = _parent.rect_size
	var default_size := _get_default_size()
	prints(default_size, _custom_size) # test whether defaults need y expansion
	if _custom_size.x < default_size.x + 5.0:
		_custom_size.x = 0.0
	if _custom_size.y < default_size.y + 5.0:
		_custom_size.y = 0.0

func _settings_listener(setting: String, _value) -> void:
	if setting == "gui_size":
		_resize()

func _on_parent_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == BUTTON_LEFT:
			_drag_point = get_global_mouse_position() - _parent.rect_position
			set_process_input(true)
			_parent.set_default_cursor_shape(CURSOR_MOVE)
	elif event is InputEventMouseMotion and _drag_point:
		_parent.rect_position = get_global_mouse_position() - _drag_point

func _input(event):
	# We process input only during drag. It is posible for the parent control
	# to never get the button-up event (happens in HTML5 builds).
	if event is InputEventMouseButton:
		if !event.pressed and event.button_index == BUTTON_LEFT:
			_finish_move()
			_parent.set_default_cursor_shape(CURSOR_ARROW)

func _on_margin_input(event: InputEvent, location: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			var mouse_pos := get_global_mouse_position()
			if event.pressed:
				match location:
					TL, T, TR:
						_margin_drag_y = mouse_pos.y - _parent.margin_top
					BL, B, BR:
						_margin_drag_y = mouse_pos.y - _parent.margin_bottom
				match location:
					TL, L, BL:
						_margin_drag_x = mouse_pos.x - _parent.margin_left
					TR, R, BR:
						_margin_drag_x = mouse_pos.x - _parent.margin_right
			else:
				_margin_drag_x = 0.0
				_margin_drag_y = 0.0
				_update_custom_size()
				_finish_move()
	elif event is InputEventMouseMotion and (_margin_drag_x or _margin_drag_y):
		var mouse_pos := get_global_mouse_position()
		match location:
			TL, T, TR:
				_parent.margin_top = mouse_pos.y - _margin_drag_y
			BL, B, BR:
				_parent.margin_bottom = mouse_pos.y - _margin_drag_y
		match location:
			TL, L, BL:
				_parent.margin_left = mouse_pos.x - _margin_drag_x
			TR, R, BR:
				_parent.margin_right = mouse_pos.x - _margin_drag_x
