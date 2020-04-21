# viewport_input.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2020 Charlie Whitfield
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
# Handles input not handled by InputHandler or GUI -- in particular, camera
# movement and click selection. This node expects specific members and
# functions present in BCamera. Modify, remove or replace this node if these
# don't apply.
#
# TODO: Shift-drag -> offset
# TODO: alt-drag - yaw

extends Node
class_name ViewportInput

const MOUSE_WHEEL_ADJ := 20.0

const VIEW_ZOOM = Enums.VIEW_ZOOM
const VIEW_45 = Enums.VIEW_45
const VIEW_TOP = Enums.VIEW_TOP
const VIEW_CENTERED = Enums.VIEW_CENTERED
const VIEW_UNCENTERED = Enums.VIEW_UNCENTERED
const ZERO_DRAG := Vector2.ZERO


var _camera: Camera
onready var _tree := get_tree()
onready var _viewport := get_viewport()

var _settings: Dictionary = Global.settings
onready var _mouse_in_out_rate: float = _settings.camera_mouse_in_out_rate
onready var _mouse_move_rate: float = _settings.camera_mouse_move_rate
onready var _mouse_pitch_yaw_rate: float = _settings.camera_mouse_pitch_yaw_rate
onready var _mouse_roll_rate: float = _settings.camera_mouse_roll_rate
onready var _key_in_out_rate: float = _settings.camera_key_in_out_rate
onready var _key_move_rate: float = _settings.camera_key_move_rate
onready var _key_pitch_yaw_rate: float = _settings.camera_key_pitch_yaw_rate
onready var _key_roll_rate: float = _settings.camera_key_roll_rate

var _drag_l_button_start := ZERO_DRAG
var _drag_l_button_segment_start := ZERO_DRAG
var _drag_r_button_start := ZERO_DRAG
var _drag_r_button_segment_start := ZERO_DRAG


func project_init() -> void:
	Global.connect("about_to_free_procedural_nodes", self, "_restore_init_state")
	Global.connect("camera_ready", self, "_connect_camera")

func _restore_init_state() -> void:
	_camera = null

func _connect_camera(camera: Camera) -> void:
	_camera = camera

func _unhandled_input(event: InputEvent) -> void:
	if !_camera:
		return
	var is_handled := false
	if event is InputEventMouseButton:
		# mouse-wheel accumulates and is spread out so zooming isn't jumpy
		if event.button_index == BUTTON_WHEEL_UP:
			_camera.mouse_wheel_accumulator -= int(_mouse_in_out_rate * MOUSE_WHEEL_ADJ)
			is_handled = true
		elif event.button_index == BUTTON_WHEEL_DOWN:
			_camera.mouse_wheel_accumulator += int(_mouse_in_out_rate * MOUSE_WHEEL_ADJ)
			is_handled = true
		# start/stop mouse drag or process a mouse click
		elif event.button_index == BUTTON_LEFT:
			if event.pressed:
				_drag_l_button_start = _viewport.get_mouse_position()
				_drag_l_button_segment_start = _drag_l_button_start
			else:
				if _drag_l_button_start == _viewport.get_mouse_position(): # it was a mouse click, not drag movement
					Global.emit_signal("mouse_clicked_viewport_at", event.position, _camera, true)
				_drag_l_button_start = ZERO_DRAG
				_drag_l_button_segment_start = ZERO_DRAG
			is_handled = true
		elif event.button_index == BUTTON_RIGHT:
			if event.pressed:
				_drag_r_button_start = _viewport.get_mouse_position()
				_drag_r_button_segment_start = _drag_r_button_start
			else:
				if _drag_r_button_start == _viewport.get_mouse_position(): # it was a mouse click, not drag movement
					Global.emit_signal("mouse_clicked_viewport_at", event.position, _camera, false)
				_drag_r_button_start = ZERO_DRAG
				_drag_r_button_segment_start = ZERO_DRAG
			is_handled = true
	elif event is InputEventMouseMotion:
		# accumulate mouse drag motion
		if _drag_l_button_segment_start:
			var current_mouse_pos := _viewport.get_mouse_position()
			_camera.left_drag_vector += current_mouse_pos - _drag_l_button_segment_start
			_drag_l_button_segment_start = current_mouse_pos
			is_handled = true
		if _drag_r_button_segment_start:
			var current_mouse_pos := _viewport.get_mouse_position()
			_camera.right_drag_vector += current_mouse_pos - _drag_r_button_segment_start
			_drag_r_button_segment_start = current_mouse_pos
			is_handled = true
	elif event.is_action_type():
		if event.is_pressed():
			if event.is_action_pressed("camera_zoom_view"):
				_camera.move(null, VIEW_ZOOM, Vector3.ZERO, Vector3.ZERO, false)
			elif event.is_action_pressed("camera_45_view"):
				_camera.move(null, VIEW_45, Vector3.ZERO, Vector3.ZERO, false)
			elif event.is_action_pressed("camera_top_view"):
				_camera.move(null, VIEW_TOP, Vector3.ZERO, Vector3.ZERO, false)
			elif event.is_action_pressed("recenter"):
				_camera.move(null, -1, Vector3.ZERO, Vector3.ZERO, false)
			elif event.is_action_pressed("camera_left"):
				_camera.move_action.x = -_key_move_rate
			elif event.is_action_pressed("camera_right"):
				_camera.move_action.x = _key_move_rate
			elif event.is_action_pressed("camera_up"):
				_camera.move_action.y = _key_move_rate
			elif event.is_action_pressed("camera_down"):
				_camera.move_action.y = -_key_move_rate
			elif event.is_action_pressed("camera_in"):
				_camera.move_action.z = -_key_in_out_rate
			elif event.is_action_pressed("camera_out"):
				_camera.move_action.z = _key_in_out_rate
			elif event.is_action_pressed("pitch_up"):
				_camera.rotate_action.x = _key_pitch_yaw_rate
			elif event.is_action_pressed("pitch_down"):
				_camera.rotate_action.x = -_key_pitch_yaw_rate
			elif event.is_action_pressed("yaw_left"):
				_camera.rotate_action.y = _key_pitch_yaw_rate
			elif event.is_action_pressed("yaw_right"):
				_camera.rotate_action.y = -_key_pitch_yaw_rate
			elif event.is_action_pressed("roll_left"):
				_camera.rotate_action.z = -_key_roll_rate
			elif event.is_action_pressed("roll_right"):
				_camera.rotate_action.z = _key_roll_rate
			else:
				return  # no input handled
		else: # key release
			if event.is_action_released("camera_left"):
				_camera.move_action.x = 0.0
			elif event.is_action_released("camera_right"):
				_camera.move_action.x = 0.0
			elif event.is_action_released("camera_up"):
				_camera.move_action.y = 0.0
			elif event.is_action_released("camera_down"):
				_camera.move_action.y = 0.0
			elif event.is_action_released("camera_in"):
				_camera.move_action.z = 0.0
			elif event.is_action_released("camera_out"):
				_camera.move_action.z = 0.0
			elif event.is_action_released("pitch_up"):
				_camera.rotate_action.x = 0.0
			elif event.is_action_released("pitch_down"):
				_camera.rotate_action.x = 0.0
			elif event.is_action_released("yaw_left"):
				_camera.rotate_action.y = 0.0
			elif event.is_action_released("yaw_right"):
				_camera.rotate_action.y = 0.0
			elif event.is_action_released("roll_left"):
				_camera.rotate_action.z = 0.0
			elif event.is_action_released("roll_right"):
				_camera.rotate_action.z = 0.0
			else:
				return  # no input handled
		is_handled = true
	if is_handled:
		_tree.set_input_as_handled()


func _settings_listener(setting: String, value) -> void:
	match setting:
		"camera_mouse_in_out_rate":
			_mouse_in_out_rate = value
		"camera_key_in_out_rate":
			_key_in_out_rate = value
		"camera_key_move_rate":
			_key_move_rate = value
		"camera_key_pitch_yaw_rate":
			_key_pitch_yaw_rate = value
		"camera_key_roll_rate":
			_key_roll_rate = value
