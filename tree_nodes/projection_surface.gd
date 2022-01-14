# projection_surface.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2022 Charlie Whitfield
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
class_name IVProjectionSurface
extends Control

# Receives mouse events in the 3D window area, sets cursor shape, and
# interprets drags, target object click, and wheel turn.
# Parent control for HUD labels or similar 2D projections of 3D objects.
# All children are freed on exit or game load.

signal mouse_target_clicked(target, button_mask, key_modifier_mask)
signal mouse_dragged(drag_vector, button_mask, key_modifier_mask)
signal mouse_wheel_turned(is_up)

var _visuals_helper: IVVisualsHelper = IVGlobal.program.VisualsHelper
var _drag_start := Vector2.ZERO
var _drag_segment_start := Vector2.ZERO


func _project_init() -> void:
	pass


func _ready() -> void:
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_clear")
	set_anchors_and_margins_preset(Control.PRESET_WIDE)
	mouse_filter = MOUSE_FILTER_STOP


func _clear() -> void:
	for child in get_children():
		child.queue_free()


func _process(_delta: float) -> void:
	if _drag_start:
		set_default_cursor_shape(CURSOR_MOVE)
	elif _visuals_helper.mouse_target: # there is a target object under the mouse!
		set_default_cursor_shape(CURSOR_POINTING_HAND)
	else:
		set_default_cursor_shape(CURSOR_ARROW)


func _gui_input(input_event: InputEvent) -> void:
	# _gui_input events are consumed
	var event := input_event as InputEventMouse
	if !event:
		return # is this possible?
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
			if event.pressed: # start of drag or button-down for click selection
				_drag_start = event.position
				_drag_segment_start = _drag_start
			else: # end of drag or button-up after click selection
				if _drag_start == event.position: # was a mouse click!
					var target := _visuals_helper.mouse_target
					if target:
						emit_signal("mouse_target_clicked", target, event.button_mask,
								_get_key_modifier_mask(event))
				_drag_start = Vector2.ZERO
				_drag_segment_start = Vector2.ZERO
	
	elif event is InputEventMouseMotion:
		var mouse_pos: Vector2 = event.position
		_visuals_helper.mouse_position = mouse_pos
		if _drag_segment_start: # accumulated mouse drag motion
			var drag_vector := mouse_pos - _drag_segment_start
			_drag_segment_start = mouse_pos
			emit_signal("mouse_dragged", drag_vector, event.button_mask,
					_get_key_modifier_mask(event))


func _get_key_modifier_mask(event: InputEventMouse) -> int:
	var mask := 0
	if event.alt:
		mask |= KEY_MASK_ALT
	if event.shift:
		mask |= KEY_MASK_SHIFT
	if event.control:
		mask |= KEY_MASK_CTRL
	if event.meta:
		mask |= KEY_MASK_META
	if event.command:
		mask |= KEY_MASK_CMD
	return mask
