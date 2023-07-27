# control_dynamic.gd
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
class_name IVControlDynamic
extends Control

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

enum {TL, T, TR, R, BR, B, BL, L}
enum {UP, DOWN, LEFT, RIGHT}

# project vars
var avoid_overlap := true
var screen_edge_snap := 100.0
var panel_edge_snap := 40.0
var min_sizes := [
	# Use init_min_size() to set.
	Vector2(435.0, 291.0), # GUI_SMALL
	Vector2(575.0, 354.0), # GUI_MEDIUM
	Vector2(712.0, 421.0), # GUI_LARGE
]
var max_default_screen_proportions := Vector2(0.45, 0.45) # can override above

# private
var _settings: Dictionary = IVGlobal.settings
var _margin_drag_x := 0.0
var _margin_drag_y := 0.0
var _drag_point := Vector2.ZERO
var _custom_size := Vector2.ZERO

@onready var _viewport := get_viewport()
@onready var _parent: Control = get_parent()


func _ready():
	IVGlobal.connect("setting_changed", Callable(self, "_settings_listener"))
	_parent.connect("gui_input", Callable(self, "_on_parent_input"))
	$TL.connect("gui_input", Callable(self, "_on_margin_input").bind(TL))
	$T.connect("gui_input", Callable(self, "_on_margin_input").bind(T))
	$TR.connect("gui_input", Callable(self, "_on_margin_input").bind(TR))
	$R.connect("gui_input", Callable(self, "_on_margin_input").bind(R))
	$BR.connect("gui_input", Callable(self, "_on_margin_input").bind(BR))
	$B.connect("gui_input", Callable(self, "_on_margin_input").bind(B))
	$BL.connect("gui_input", Callable(self, "_on_margin_input").bind(BL))
	$L.connect("gui_input", Callable(self, "_on_margin_input").bind(L))
	set_process_input(false) # only during drag


func _input(event):
	# We process input only during drag. It is posible for the parent control
	# to never get the button-up event (happens in HTML5 builds).
	if event is InputEventMouseButton:
		if !event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			finish_move()
			_parent.set_default_cursor_shape(CURSOR_ARROW)


func init_min_size(gui_size: int, size: Vector2) -> void:
	# 'gui_size' is one of IVEnums.GUISize, or use -1 to set all.
	# Set x or y or both to zero for shrink to content.
	# Args [-1, Vector2.ZERO] sets all GUI sizes to shrink to content. 
	if gui_size != -1:
		min_sizes[gui_size] = size
	else:
		for i in min_sizes.size():
			min_sizes[i] = size


func resize_and_position_to_anchor() -> void:
	var default_size := _get_default_size()
	# Some content needs immediate resize (eg, PlanetMoonButtons so it can
	# conform to its parent container). Other content needs delayed resize.
	_parent.size = default_size
	await get_tree().idle_frame
	await get_tree().idle_frame
	await get_tree().idle_frame
	_parent.size = default_size
	_parent.position.x = _parent.anchor_left * (_viewport.size.x - _parent.size.x)
	_parent.position.y = _parent.anchor_top * (_viewport.size.y - _parent.size.y)


func finish_move() -> void:
	_drag_point = Vector2.ZERO
	set_process_input(false)
	_snap_horizontal()
	_snap_vertical()
	_fix_offscreen()
	if avoid_overlap:
		_fix_overlap()
	_set_anchors_to_position()


func _on_parent_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_drag_point = get_global_mouse_position() - _parent.position
			set_process_input(true)
			_parent.set_default_cursor_shape(CURSOR_MOVE)
	elif event is InputEventMouseMotion and _drag_point:
		_parent.position = get_global_mouse_position() - _drag_point


func _on_margin_input(event: InputEvent, location: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos := get_global_mouse_position()
			if event.pressed:
				match location:
					TL, T, TR:
						_margin_drag_y = mouse_pos.y - _parent.offset_top
					BL, B, BR:
						_margin_drag_y = mouse_pos.y - _parent.offset_bottom
				match location:
					TL, L, BL:
						_margin_drag_x = mouse_pos.x - _parent.offset_left
					TR, R, BR:
						_margin_drag_x = mouse_pos.x - _parent.offset_right
			else:
				_margin_drag_x = 0.0
				_margin_drag_y = 0.0
				_update_custom_size()
				finish_move()
	elif event is InputEventMouseMotion and (_margin_drag_x or _margin_drag_y):
		var mouse_pos := get_global_mouse_position()
		match location:
			TL, T, TR:
				_parent.offset_top = mouse_pos.y - _margin_drag_y
			BL, B, BR:
				_parent.offset_bottom = mouse_pos.y - _margin_drag_y
		match location:
			TL, L, BL:
				_parent.offset_left = mouse_pos.x - _margin_drag_x
			TR, R, BR:
				_parent.offset_right = mouse_pos.x - _margin_drag_x


func _snap_horizontal() -> void:
	var left := _parent.position.x
	if left < screen_edge_snap:
		_parent.position.x = 0.0
		return
	var right := left + _parent.size.x
	var screen_right := _viewport.size.x
	if right > screen_right - screen_edge_snap:
		_parent.position.x = screen_right - right + left
		return
	var top := _parent.position.y
	var bottom := top + _parent.size.y
	for child in _parent.get_parent().get_children():
		var test_panel := child as PanelContainer
		if !test_panel or test_panel == _parent:
			continue
		var panel_top := test_panel.position.y
		if bottom < panel_top:
			continue
		var panel_bottom := panel_top + test_panel.size.y
		if top > panel_bottom:
			continue
		var panel_left := test_panel.position.x
		if abs(right - panel_left) < panel_edge_snap:
			_parent.position.x = panel_left - right + left
			return
		var panel_right := panel_left + test_panel.size.x
		if abs(left - panel_right) < panel_edge_snap:
			_parent.position.x = panel_right
			return


func _snap_vertical() -> void:
	var top := _parent.position.y
	if top < screen_edge_snap:
		_parent.position.y = 0.0
		return
	var bottom := top + _parent.size.y
	var screen_bottom := _viewport.size.y
	if bottom > screen_bottom - screen_edge_snap:
		_parent.position.y = screen_bottom - bottom + top
		return
	var left := _parent.position.x
	var right := left + _parent.size.x
	for child in _parent.get_parent().get_children():
		var test_panel := child as PanelContainer
		if !test_panel or test_panel == _parent:
			continue
		var panel_left := test_panel.position.x
		if right < panel_left:
			continue
		var panel_top := test_panel.position.y
		if abs(bottom - panel_top) < panel_edge_snap:
			_parent.position.y = panel_top - bottom + top
			return
		var panel_bottom := panel_top + test_panel.size.y
		if abs(top - panel_bottom) < panel_edge_snap:
			_parent.position.y = panel_bottom
			return


func _fix_offscreen() -> void:
	var rect := _parent.get_rect()
	var screen_rect := get_viewport_rect()
	if screen_rect.encloses(rect):
		return
	if rect.position.x < 0.0:
		_parent.position.x = 0.0
	elif rect.end.x > screen_rect.end.x:
		_parent.position.x = screen_rect.end.x - rect.size.x
	if rect.position.y < 0.0:
		_parent.position.y = 0.0
	elif rect.end.y > screen_rect.end.y:
		_parent.position.y = screen_rect.end.y - rect.size.y


func _fix_overlap() -> void:
	# Tries 8 directions and then gives up
	var rect := _parent.get_rect()
	var overlap := _get_overlap(rect)
	if !overlap:
		return
	if _try_directions(rect, overlap.duplicate(), false):
		return
	_try_directions(rect, overlap, true)


func _try_directions(rect: Rect2, overlap: Array, diagonals: bool) -> bool:
	# smallest overlap is our prefered correction
	var overlap2: Array
	if diagonals:
		overlap2 = overlap.duplicate()
	while true:
		var smallest_offset := INF
		var smallest_direction := -1
		var direction := 0
		while direction < 4:
			if abs(overlap[direction]) < abs(smallest_offset):
				smallest_offset = overlap[direction]
				smallest_direction = direction
			direction += 1
		if smallest_direction == -1:
			return false # failed
		if !diagonals:
			if _try_cardinal_offset(rect, smallest_direction, smallest_offset):
				return true # success
		else:
			var orthogonal := []
			match smallest_direction:
				UP, DOWN:
					orthogonal.append(overlap2[LEFT])
					orthogonal.append(overlap2[RIGHT])
					if abs(overlap2[LEFT]) > abs(overlap2[RIGHT]):
						orthogonal.invert()
				RIGHT, LEFT:
					orthogonal.append(overlap2[UP])
					orthogonal.append(overlap2[DOWN])
					if abs(overlap2[UP]) > abs(overlap2[DOWN]):
						orthogonal.invert()
			if _try_diagonal_offset(rect, smallest_direction, smallest_offset, orthogonal):
				return true # success
		overlap[smallest_direction] = INF
	return false


func _try_cardinal_offset(rect: Rect2, direction: int, offset: float) -> bool:
	match direction:
		UP, DOWN:
			rect.position.y += offset
			if _get_overlap(rect):
				return false
			_parent.position.y += offset
		LEFT, RIGHT:
			rect.position.x += offset
			if _get_overlap(rect):
				return false
			_parent.position.x += offset
	return true


func _try_diagonal_offset(rect: Rect2, direction: int, offset: float, orthogonal: Array) -> bool:
	match direction:
		UP, DOWN:
			rect.position.y += offset
			rect.position.x += orthogonal[0]
			if !_get_overlap(rect):
				_parent.position.y += offset
				_parent.position.x += orthogonal[0]
				return true
			rect.position.x += orthogonal[1] - orthogonal[0]
			if !_get_overlap(rect):
				_parent.position.y += offset
				_parent.position.x += orthogonal[1]
				return true
		LEFT, RIGHT:
			rect.position.x += offset
			rect.position.y += orthogonal[0]
			if !_get_overlap(rect):
				_parent.position.x += offset
				_parent.position.y += orthogonal[0]
				return true
			rect.position.y += orthogonal[1] - orthogonal[0]
			if !_get_overlap(rect):
				_parent.position.x += offset
				_parent.position.y += orthogonal[1]
				return true
	return false


func _get_overlap(rect: Rect2) -> Array:
	for child in _parent.get_parent().get_children():
		var other := child as Control
		if !other or other == _parent:
			continue
		var other_rect := other.get_rect()
		if rect.intersects(other_rect):
			var right_down := other_rect.end - rect.position
			var up_left := rect.end - other_rect.position
			var overlap := [INF, INF, INF, INF]
			if right_down.x > 0:
				overlap[RIGHT] = right_down.x # move right to fix
			if up_left.x > 0:
				overlap[LEFT] = -up_left.x # move left to fix
			if right_down.y > 0:
				overlap[DOWN] = right_down.y # move down to fix
			if up_left.y > 0:
				overlap[UP] = -up_left.y # move up to fix
			return overlap
	var screen_rect := get_viewport_rect()
	if screen_rect.encloses(rect):
		return [] # good position
	return [INF, INF, INF, INF] # bad position


func _set_anchors_to_position() -> void:
	var position := _parent.position
	var size := _parent.size
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
	_parent.position = position # setting anchors screws up position (Godot bug?)


func _get_default_size() -> Vector2:
	var gui_size: int = _settings.gui_size
	var default_size: Vector2 = min_sizes[gui_size]
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
	_custom_size = _parent.size
	var default_size := _get_default_size()
	prints(default_size, _custom_size) # test whether defaults need y expansion
	if _custom_size.x < default_size.x + 5.0:
		_custom_size.x = 0.0
	if _custom_size.y < default_size.y + 5.0:
		_custom_size.y = 0.0


func _settings_listener(setting: String, _value) -> void:
	if setting == "gui_size":
		resize_and_position_to_anchor()
