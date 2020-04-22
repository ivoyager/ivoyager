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
# Handles input for camera movements and click selection. This node expects
# specific members and functions present in BCamera. Modify, remove or replace
# this node if these don't apply.
#
# TODO: Shift-drag -> offset
# TODO: alt-drag - yaw

extends Node
class_name ViewportInput

const MOUSE_WHEEL_ADJ := 2.5 # adjust so default setting can be ~1.0
const MOUSE_MOVE_ADJ := 0.4
const MOUSE_PITCH_YAW_ADJ := 0.2
const MOUSE_ROLL_ADJ := 0.5
const KEY_IN_OUT_ADJ := 1.0
const KEY_MOVE_ADJ := 1.0
const KEY_PITCH_YAW_ADJ := 3.0
const KEY_ROLL_ADJ := 3.0

const VIEW_ZOOM = Enums.VIEW_ZOOM
const VIEW_45 = Enums.VIEW_45
const VIEW_TOP = Enums.VIEW_TOP
const VIEW_CENTERED = Enums.VIEW_CENTERED
const VIEW_UNCENTERED = Enums.VIEW_UNCENTERED
const VECTOR2_ZERO := Vector2.ZERO
const VECTOR3_ZERO := Vector3.ZERO

var mouse_rotate_min_z_at_offcenter := 0.2
var mouse_rotate_max_z_at_offcenter := 0.7

var _camera: Camera
onready var _tree := get_tree()
onready var _viewport := get_viewport()

var _settings: Dictionary = Global.settings
onready var _mouse_in_out_rate: float = _settings.camera_mouse_in_out_rate * MOUSE_WHEEL_ADJ
onready var _mouse_move_rate: float = _settings.camera_mouse_move_rate * MOUSE_MOVE_ADJ
onready var _mouse_pitch_yaw_rate: float = _settings.camera_mouse_pitch_yaw_rate * MOUSE_PITCH_YAW_ADJ
onready var _mouse_roll_rate: float = _settings.camera_mouse_roll_rate * MOUSE_ROLL_ADJ
onready var _key_in_out_rate: float = _settings.camera_key_in_out_rate * KEY_IN_OUT_ADJ
onready var _key_move_rate: float = _settings.camera_key_move_rate * KEY_MOVE_ADJ
onready var _key_pitch_yaw_rate: float = _settings.camera_key_pitch_yaw_rate * KEY_PITCH_YAW_ADJ
onready var _key_roll_rate: float = _settings.camera_key_roll_rate * KEY_ROLL_ADJ

var _drag_l_button_start := VECTOR2_ZERO
var _drag_l_button_segment_start := VECTOR2_ZERO
var _drag_r_button_start := VECTOR2_ZERO
var _drag_r_button_segment_start := VECTOR2_ZERO
var _left_drag_vector := VECTOR2_ZERO
var _right_drag_vector := VECTOR2_ZERO

var _mwheel_turning := 0.0
var _move_pressed := VECTOR3_ZERO
var _rotate_pressed := VECTOR3_ZERO


func project_init() -> void:
	Global.connect("run_state_changed", self, "set_process") # starts/stops
	Global.connect("about_to_free_procedural_nodes", self, "_restore_init_state")
	Global.connect("camera_ready", self, "_connect_camera")

func _restore_init_state() -> void:
	_camera = null

func _connect_camera(camera: Camera) -> void:
	_camera = camera

func _ready():
	set_process(false)

func _process(delta: float) -> void:
	if _left_drag_vector:
		_camera.move_action.x -= _left_drag_vector.x * delta * _mouse_move_rate
		_camera.move_action.y += _left_drag_vector.y * delta * _mouse_move_rate
		_left_drag_vector = VECTOR2_ZERO
	if _right_drag_vector: # hybrid mode
		var mouse_rotate := _right_drag_vector * delta
		_right_drag_vector = VECTOR2_ZERO
		var z_proportion := (2.0 * _drag_r_button_start - _viewport.size).length() \
				/ _viewport.size.x
		z_proportion -= mouse_rotate_min_z_at_offcenter
		z_proportion /= mouse_rotate_max_z_at_offcenter - mouse_rotate_min_z_at_offcenter
		z_proportion = clamp(z_proportion, 0.0, 1.0)
		var center_to_mouse := (_viewport.get_mouse_position() - _viewport.size / 2.0).normalized()
		_camera.rotate_action.z += center_to_mouse.cross(mouse_rotate) * z_proportion * _mouse_roll_rate
		mouse_rotate *= (1.0 - z_proportion) * _mouse_pitch_yaw_rate
		_camera.rotate_action.x += mouse_rotate.y
		_camera.rotate_action.y += mouse_rotate.x
	if _mwheel_turning:
		_camera.move_action.z += _mwheel_turning * delta
		_mwheel_turning = 0.0
	if _move_pressed:
		_camera.move_action += _move_pressed * delta
	if _rotate_pressed:
		_camera.rotate_action += _rotate_pressed * delta

func _unhandled_input(event: InputEvent) -> void:
	if !_camera:
		return
	var is_handled := false
	if event is InputEventMouseButton:
		# BUTTON_WHEEL_UP & _DOWN always fire twice (pressed then not pressed)
		if event.button_index == BUTTON_WHEEL_UP:
			_mwheel_turning = _mouse_in_out_rate
			is_handled = true
		elif event.button_index == BUTTON_WHEEL_DOWN:
			_mwheel_turning = -_mouse_in_out_rate
			is_handled = true
		# start/stop mouse drag or process a mouse click
		elif event.button_index == BUTTON_LEFT:
			if event.pressed:
				_drag_l_button_start = _viewport.get_mouse_position()
				_drag_l_button_segment_start = _drag_l_button_start
			else:
				if _drag_l_button_start == _viewport.get_mouse_position(): # mouse click!
					Global.emit_signal("mouse_clicked_viewport_at", event.position, _camera, true)
				_drag_l_button_start = VECTOR2_ZERO
				_drag_l_button_segment_start = VECTOR2_ZERO
			is_handled = true
		elif event.button_index == BUTTON_RIGHT:
			if event.pressed:
				_drag_r_button_start = _viewport.get_mouse_position()
				_drag_r_button_segment_start = _drag_r_button_start
			else:
				if _drag_r_button_start == _viewport.get_mouse_position(): # it was a mouse click, not drag movement
					Global.emit_signal("mouse_clicked_viewport_at", event.position, _camera, false)
				_drag_r_button_start = VECTOR2_ZERO
				_drag_r_button_segment_start = VECTOR2_ZERO
			is_handled = true
	elif event is InputEventMouseMotion:
		# accumulate mouse drag motion
		if _drag_l_button_segment_start:
			var current_mouse_pos := _viewport.get_mouse_position()
			_left_drag_vector += current_mouse_pos - _drag_l_button_segment_start
			_drag_l_button_segment_start = current_mouse_pos
			is_handled = true
		if _drag_r_button_segment_start:
			var current_mouse_pos := _viewport.get_mouse_position()
			_right_drag_vector += current_mouse_pos - _drag_r_button_segment_start
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
				_move_pressed.x = -_key_move_rate
			elif event.is_action_pressed("camera_right"):
				_move_pressed.x = _key_move_rate
			elif event.is_action_pressed("camera_up"):
				_move_pressed.y = _key_move_rate
			elif event.is_action_pressed("camera_down"):
				_move_pressed.y = -_key_move_rate
			elif event.is_action_pressed("camera_in"):
				_move_pressed.z = -_key_in_out_rate
			elif event.is_action_pressed("camera_out"):
				_move_pressed.z = _key_in_out_rate
			elif event.is_action_pressed("pitch_up"):
				_rotate_pressed.x = _key_pitch_yaw_rate
			elif event.is_action_pressed("pitch_down"):
				_rotate_pressed.x = -_key_pitch_yaw_rate
			elif event.is_action_pressed("yaw_left"):
				_rotate_pressed.y = _key_pitch_yaw_rate
			elif event.is_action_pressed("yaw_right"):
				_rotate_pressed.y = -_key_pitch_yaw_rate
			elif event.is_action_pressed("roll_left"):
				_rotate_pressed.z = -_key_roll_rate
			elif event.is_action_pressed("roll_right"):
				_rotate_pressed.z = _key_roll_rate
			else:
				return  # no input handled
		else: # key release
			if event.is_action_released("camera_left"):
				_move_pressed.x = 0.0
			elif event.is_action_released("camera_right"):
				_move_pressed.x = 0.0
			elif event.is_action_released("camera_up"):
				_move_pressed.y = 0.0
			elif event.is_action_released("camera_down"):
				_move_pressed.y = 0.0
			elif event.is_action_released("camera_in"):
				_move_pressed.z = 0.0
			elif event.is_action_released("camera_out"):
				_move_pressed.z = 0.0
			elif event.is_action_released("pitch_up"):
				_rotate_pressed.x = 0.0
			elif event.is_action_released("pitch_down"):
				_rotate_pressed.x = 0.0
			elif event.is_action_released("yaw_left"):
				_rotate_pressed.y = 0.0
			elif event.is_action_released("yaw_right"):
				_rotate_pressed.y = 0.0
			elif event.is_action_released("roll_left"):
				_rotate_pressed.z = 0.0
			elif event.is_action_released("roll_right"):
				_rotate_pressed.z = 0.0
			else:
				return  # no input handled
		is_handled = true
	if is_handled:
		_tree.set_input_as_handled()

func _settings_listener(setting: String, value) -> void:
	match setting:
		"camera_mouse_in_out_rate":
			_mouse_in_out_rate = value * MOUSE_WHEEL_ADJ
		"camera_mouse_move_rate":
			_mouse_move_rate = value * MOUSE_MOVE_ADJ
		"camera_mouse_pitch_yaw_rate":
			_mouse_pitch_yaw_rate = value * MOUSE_PITCH_YAW_ADJ
		"camera_mouse_roll_rate":
			_mouse_roll_rate = value * MOUSE_ROLL_ADJ
		"camera_key_in_out_rate":
			_key_in_out_rate = value * KEY_IN_OUT_ADJ
		"camera_key_move_rate":
			_key_move_rate = value * KEY_MOVE_ADJ
		"camera_key_pitch_yaw_rate":
			_key_pitch_yaw_rate = value * KEY_PITCH_YAW_ADJ
		"camera_key_roll_rate":
			_key_roll_rate = value * KEY_ROLL_ADJ
