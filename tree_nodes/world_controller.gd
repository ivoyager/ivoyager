# world_controller.gd
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
class_name IVWorldController
extends Control

# Receives mouse events in the 3D world area, sets cursor shape and interprets
# mouse drags, clicks and wheel turn.
# Inits IVGlobal.world_targeting, which has elements:
#  [0] mouse_position: Vector2 (this object sets)
#  [1] veiwport_height: float (this object sets)
#  [2] camera: Camera (camera sets)
#  [3] camera_fov: float (camera sets)
#  [4] mouse_target: Object (potential targets set/unset themselves; e.g., IVBody)
#  [5] mouse_target_dist: float (as above)
#  [6] fragment_mouse_coord: Vector2 (this object sets; mouse_position w/ flipped y)
#  [7] fragment_range: int (FragmentIdentifier overrides)
#  [8] fragment_cycler: float (FragmentIdentifier overrides)
#
# TODO: Recode using Godot's built-in mouse drag functionality.

signal mouse_target_clicked(target, button_mask, key_modifier_mask)
signal mouse_dragged(drag_vector, button_mask, key_modifier_mask)
signal mouse_wheel_turned(is_up)

const NULL_MOUSE_COORD := Vector2(-100.0, -100.0)

var _world_targeting: Array = IVGlobal.world_targeting
var _pause_only_stops_time = IVGlobal.pause_only_stops_time
var _drag_start := Vector2.ZERO
var _drag_segment_start := Vector2.ZERO
var _has_mouse := true
var _is_true_pause := true

onready var _tree := get_tree()
onready var _viewport := get_viewport()
onready var _is_fragment_identifier := IVGlobal.program.has("FragmentIdentifier")


func _project_init() -> void:
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_clear")
	_world_targeting.resize(9)
	_world_targeting[0] = Vector2.ZERO
	_world_targeting[1] = 0.0
	_world_targeting[5] = INF
	_world_targeting[6] = NULL_MOUSE_COORD # mouse_coord for FragmentIdentifier & shaders
	_world_targeting[7] = 9.0 # fragment_range; FragmentIdentifier will override
	_world_targeting[8] = 0.0 # fragment_cycler: FragmentIdentifier maintains


func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS # but some functionaly stops if !pause_only_stops_time
	mouse_filter = MOUSE_FILTER_STOP
	IVGlobal.connect("paused_changed", self, "_set_true_pause_state")
	IVGlobal.connect("simulator_started", self, "_set_true_pause_state")
	connect("mouse_entered", self, "_on_mouse_entered")
	connect("mouse_exited", self, "_on_mouse_exited")
	set_anchors_and_margins_preset(Control.PRESET_WIDE)
	_viewport.connect("size_changed", self, "_on_viewport_size_changed")
	_world_targeting[1] = _viewport.size.y


func _process(_delta: float) -> void:
	if _drag_start:
		_world_targeting[6] = NULL_MOUSE_COORD
		set_default_cursor_shape(CURSOR_MOVE)
	elif _world_targeting[4]: # there is a target object under the mouse!
		_world_targeting[6] = NULL_MOUSE_COORD
		set_default_cursor_shape(CURSOR_POINTING_HAND)
	else:
		# no object target under mouse, but there could be a shader point
		if _is_fragment_identifier and _has_mouse:
			_world_targeting[6].x = _world_targeting[0].x
			_world_targeting[6].y = _world_targeting[1] - _world_targeting[0].y # flipped
		else:
			_world_targeting[6] = NULL_MOUSE_COORD
		set_default_cursor_shape(CURSOR_ARROW)


func _gui_input(input_event: InputEvent) -> void:
	# _gui_input events are consumed
	var event := input_event as InputEventMouse
	if !event:
		return # is this possible?
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = event.position
		_world_targeting[0] = mouse_pos
		if _is_true_pause:
			return
		if _drag_segment_start: # accumulated mouse drag motion
			var drag_vector := mouse_pos - _drag_segment_start
			_drag_segment_start = mouse_pos
			emit_signal("mouse_dragged", drag_vector, event.button_mask,
					_get_key_modifier_mask(event))
		return
	if _is_true_pause:
		return
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
					if _world_targeting[4]: # mouse_target
						emit_signal("mouse_target_clicked", _world_targeting[4],
								event.button_mask, _get_key_modifier_mask(event))
				_drag_start = Vector2.ZERO
				_drag_segment_start = Vector2.ZERO


func _clear() -> void:
	_world_targeting[2] = null
	_world_targeting[4] = null
	_world_targeting[5] = INF
	_drag_start = Vector2.ZERO
	_drag_segment_start = Vector2.ZERO


func _set_true_pause_state(_dummy := false) -> void:
	_is_true_pause = !_pause_only_stops_time and _tree.paused
	if _is_true_pause:
		_drag_start = Vector2.ZERO
		_drag_segment_start = Vector2.ZERO


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


func _on_viewport_size_changed() -> void:
	_world_targeting[1] = get_viewport().size.y


func _on_mouse_entered() -> void:
	_has_mouse = true


func _on_mouse_exited() -> void:
	_has_mouse = false

