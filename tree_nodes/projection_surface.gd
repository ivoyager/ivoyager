# projection_surface.gd
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
# Parent control for HUD labels or similar 2D objects. Receivs mouse events in
# the 3D area and interprets drags, wheel turn, and target Body click.
# All children are freed on exit or game load.

extends Control
class_name ProjectionSurface

signal mouse_wheel_turned(is_up)
signal mouse_dragged(drag_vector, drag_mode)

const DragMode := Enums.DragMode

var _mouse_info: Array = Global.mouse_info
var _mouse_target: Body
var _drag_start := Vector2.ZERO
var _drag_segment_start := Vector2.ZERO
var _drag_mode := -1


func project_init() -> void:
	pass

func _ready() -> void:
	Global.connect("about_to_free_procedural_nodes", self, "_free_children")
	set_anchors_and_margins_preset(Control.PRESET_WIDE)
	mouse_filter = MOUSE_FILTER_STOP

func _free_children() -> void:
	for child in get_children():
		child.queue_free()

func _process(_delta) -> void:
	if _drag_start:
		set_default_cursor_shape(CURSOR_MOVE)
	elif _mouse_info[2]: # target Body
		set_default_cursor_shape(CURSOR_POINTING_HAND)
	else:
		set_default_cursor_shape(CURSOR_ARROW)

func _gui_input(event) -> void:
	# event is consumed
	if event is InputEventMouseButton:
		var button_index: int = event.button_index
		# BUTTON_WHEEL_UP & _DOWN always fires twice (pressed then not pressed)
		if button_index == BUTTON_WHEEL_UP:
			emit_signal("mouse_wheel_turned", true)
			return
		if button_index == BUTTON_WHEEL_DOWN:
			emit_signal("mouse_wheel_turned", false)
			return
		# start/stop mouse drag or process a mouse click
		if button_index == BUTTON_LEFT or button_index == BUTTON_RIGHT:
			if event.pressed: # possible drag start (but may be a click selection!)
				_drag_start = event.position
				_drag_segment_start = _drag_start
				if event.control:
					_drag_mode = DragMode.CNTR_DRAG
				elif event.shift:
					_drag_mode = DragMode.SHIFT_DRAG
				elif event.alt:
					_drag_mode = DragMode.ALT_DRAG
				elif button_index == BUTTON_RIGHT:
					_drag_mode = DragMode.RIGHT_DRAG
				else:
					_drag_mode = DragMode.LEFT_DRAG
			else: # end of drag, or button-up after a mouse click selection
				if _drag_start == event.position: # was a mouse click!
					print(" MOUSE CLICK !!! ")
					var target_body: Body = _mouse_info[2]
					if target_body:
						Global.emit_signal("move_camera_to_body_requested", target_body)
				_drag_start = Vector2.ZERO
				_drag_segment_start = Vector2.ZERO
				_drag_mode = -1
	
	elif event is InputEventMouseMotion:
		var mouse_pos: Vector2 = event.position
		_mouse_info[0] = mouse_pos.x
		_mouse_info[1] = mouse_pos.y
		if _drag_segment_start: # accumulated mouse drag motion
			var drag_vector := mouse_pos - _drag_segment_start
			_drag_segment_start = mouse_pos
			emit_signal("mouse_dragged", drag_vector, _drag_mode)
			
	
	
	
#	Global.emit_signal("projection_unhandled_mouse_event", event)

