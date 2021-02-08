# vygr_camera_handler.gd
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
# Handles input for VygrCamera movements and click selection. Remove or replace
# this class if you have a different camera.

extends Node
class_name VygrCameraHandler

enum {
	DRAG_MOVE,
	DRAG_PITCH_YAW,
	DRAG_ROLL,
	DRAG_PITCH_YAW_ROLL_HYBRID
}

const VIEW_ZOOM = Enums.ViewType.VIEW_ZOOM
const VIEW_45 = Enums.ViewType.VIEW_45
const VIEW_TOP = Enums.ViewType.VIEW_TOP
const VIEW_OUTWARD = Enums.ViewType.VIEW_OUTWARD
const VIEW_BUMPED = Enums.ViewType.VIEW_BUMPED
const VIEW_BUMPED_ROTATED = Enums.ViewType.VIEW_BUMPED_ROTATED
const VECTOR2_ZERO := Vector2.ZERO
const VECTOR3_ZERO := Vector3.ZERO
const NULL_ROTATION := Vector3(-INF, -INF, -INF)

# project vars
# set _adj vars so user option can be close to 1.0
var mouse_wheel_adj := 7.5
var mouse_move_adj := 0.3
var mouse_pitch_yaw_adj := 0.13
var mouse_roll_adj := 0.5
var key_in_out_adj := 3.0
var key_move_adj := 0.7
var key_pitch_yaw_adj := 2.0
var key_roll_adj := 3.0
var l_button_drag := DRAG_MOVE
var r_button_drag := DRAG_PITCH_YAW_ROLL_HYBRID
var cntr_drag := DRAG_PITCH_YAW_ROLL_HYBRID # same as r_button_drag for Mac!
var shift_drag := DRAG_PITCH_YAW
var alt_drag := DRAG_ROLL
var hybrid_drag_center_zone := 0.2 # for _drag_mode = DRAG_PITCH_YAW_ROLL_HYBRID
var hybrid_drag_outside_zone := 0.7 # for _drag_mode = DRAG_PITCH_YAW_ROLL_HYBRID

# private
var _camera: VygrCamera
var _selection_manager: SelectionManager
onready var _tree := get_tree()
onready var _viewport := get_viewport()

var _settings: Dictionary = Global.settings
onready var _mouse_in_out_rate: float = _settings.camera_mouse_in_out_rate * mouse_wheel_adj
onready var _mouse_move_rate: float = _settings.camera_mouse_move_rate * mouse_move_adj
onready var _mouse_pitch_yaw_rate: float = _settings.camera_mouse_pitch_yaw_rate * mouse_pitch_yaw_adj
onready var _mouse_roll_rate: float = _settings.camera_mouse_roll_rate * mouse_roll_adj
onready var _key_in_out_rate: float = _settings.camera_key_in_out_rate * key_in_out_adj
onready var _key_move_rate: float = _settings.camera_key_move_rate * key_move_adj
onready var _key_pitch_yaw_rate: float = _settings.camera_key_pitch_yaw_rate * key_pitch_yaw_adj
onready var _key_roll_rate: float = _settings.camera_key_roll_rate * key_roll_adj

var _drag_mode := -1 # one of DRAG_ enums when active
var _drag_start := VECTOR2_ZERO
var _drag_segment_start := VECTOR2_ZERO
var _drag_vector := VECTOR2_ZERO
var _mwheel_turning := 0.0
var _move_pressed := VECTOR3_ZERO
var _rotate_pressed := VECTOR3_ZERO
var _suppress_camera_move := false


func project_init() -> void:
	pass

func _ready():
	Global.connect("system_tree_ready", self, "_on_system_tree_ready")
	Global.connect("run_state_changed", self, "_on_run_state_changed")
	Global.connect("about_to_free_procedural_nodes", self, "_restore_init_state")
	Global.connect("camera_ready", self, "_connect_camera")
#	Global.connect("projection_unhandled_mouse_event", self,
#			"_on_projection_unhandled_mouse_event")
	Global.connect("setting_changed", self, "_settings_listener")
	set_process(false)
	set_process_unhandled_input(false)

func _restore_init_state() -> void:
	_disconnect_camera()
	if _selection_manager:
		_selection_manager.disconnect("selection_changed", self, "_on_selection_changed")
		_selection_manager = null

func _connect_camera(camera: VygrCamera) -> void:
	_disconnect_camera()
	_camera = camera
	_camera.connect("move_started", self, "_on_camera_move_started")
	_camera.connect("camera_lock_changed", self, "_on_camera_lock_changed")

func _disconnect_camera() -> void:
	if !_camera:
		return
	_camera.disconnect("move_started", self, "_on_camera_move_started")
	_camera.disconnect("camera_lock_changed", self, "_on_camera_lock_changed")
	_camera = null

func _on_system_tree_ready(_is_new_game: bool) -> void:
	_selection_manager = Global.program.ProjectGUI.selection_manager
	_selection_manager.connect("selection_changed", self, "_on_selection_changed")

func _on_run_state_changed(is_running: bool) -> void:
	set_process(is_running)
	set_process_unhandled_input(is_running)

func _on_selection_changed() -> void:
	if _camera and _camera.is_camera_lock and !_suppress_camera_move:
		_camera.move_to_selection(_selection_manager.selection_item, -1, Vector3.ZERO,
				NULL_ROTATION, -1)

func _on_camera_move_started(to_body: Body, is_camera_lock: bool) -> void:
	if is_camera_lock:
		_suppress_camera_move = true
		_selection_manager.select_body(to_body)
	_suppress_camera_move = false

func _on_camera_lock_changed(is_camera_lock: bool) -> void:
	if is_camera_lock and !_suppress_camera_move:
		_camera.move_to_selection(_selection_manager.selection_item, -1, Vector3.ZERO,
				NULL_ROTATION, -1)

func _process(delta: float) -> void:
	if _drag_vector:
		match _drag_mode:
			DRAG_MOVE:
				_drag_vector *= delta * _mouse_move_rate
				_camera.add_move_action(Vector3(-_drag_vector.x, _drag_vector.y, 0.0))
			DRAG_PITCH_YAW:
				_drag_vector *= delta * _mouse_pitch_yaw_rate
				_camera.add_rotate_action(Vector3(_drag_vector.y, _drag_vector.x, 0.0))
			DRAG_ROLL:
				var mouse_position := _drag_segment_start + _drag_vector
				var center_to_mouse := (mouse_position - _viewport.size / 2.0).normalized()
				_drag_vector *= delta * _mouse_roll_rate
				_camera.add_rotate_action(Vector3(0.0, 0.0, center_to_mouse.cross(_drag_vector)))
			DRAG_PITCH_YAW_ROLL_HYBRID:
				# one or a mix of two above based on mouse position
				var mouse_rotate := _drag_vector * delta
				var z_proportion := (2.0 * _drag_start - _viewport.size).length() / _viewport.size.x
				z_proportion -= hybrid_drag_center_zone
				z_proportion /= hybrid_drag_outside_zone - hybrid_drag_center_zone
				z_proportion = clamp(z_proportion, 0.0, 1.0)
				var mouse_position := _drag_segment_start + _drag_vector
				var center_to_mouse := (mouse_position - _viewport.size / 2.0).normalized()
				var z_rotate := center_to_mouse.cross(mouse_rotate) * z_proportion * _mouse_roll_rate
				mouse_rotate *= (1.0 - z_proportion) * _mouse_pitch_yaw_rate
				_camera.add_rotate_action(Vector3(mouse_rotate.y, mouse_rotate.x, z_rotate))
		_drag_vector = VECTOR2_ZERO
	if _mwheel_turning:
		_camera.add_move_action(Vector3(0.0, 0.0, _mwheel_turning * delta))
		_mwheel_turning = 0.0
	if _move_pressed:
		_camera.add_move_action(_move_pressed * delta)
	if _rotate_pressed:
		_camera.add_rotate_action(_rotate_pressed * delta)

#func _on_projection_unhandled_mouse_event(event: InputEventMouse) -> void:
#	if !_camera:
#		return
#	var is_handled := false
#	if event is InputEventMouseButton:
#		var button_index: int = event.button_index
#		# BUTTON_WHEEL_UP & _DOWN always fires twice (pressed then not pressed)
#		if button_index == BUTTON_WHEEL_UP:
#			_mwheel_turning = _mouse_in_out_rate
#			is_handled = true
#		elif button_index == BUTTON_WHEEL_DOWN:
#			_mwheel_turning = -_mouse_in_out_rate
#			is_handled = true
#	if is_handled:
#		_tree.set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if !_camera:
		return
	var is_handled := false
	if event is InputEventMouseButton:
		var button_index: int = event.button_index
		# BUTTON_WHEEL_UP & _DOWN always fires twice (pressed then not pressed)
		if button_index == BUTTON_WHEEL_UP:
			_mwheel_turning = _mouse_in_out_rate
			is_handled = true
		elif button_index == BUTTON_WHEEL_DOWN:
			_mwheel_turning = -_mouse_in_out_rate
			is_handled = true
		# start/stop mouse drag or process a mouse click
		elif button_index == BUTTON_LEFT or button_index == BUTTON_RIGHT:
			if event.pressed: # possible drag start (but may be a click selection!)
				_drag_start = event.position
				_drag_segment_start = _drag_start
				if event.control:
					_drag_mode = cntr_drag
				elif event.shift:
					_drag_mode = shift_drag
				elif event.alt:
					_drag_mode = alt_drag
				elif button_index == BUTTON_RIGHT:
					_drag_mode = r_button_drag
				else:
					_drag_mode = l_button_drag
			else: # end of drag, or button-up after a mouse click selection
				if _drag_start == event.position: # was a mouse click!
					Global.emit_signal("mouse_clicked_viewport_at", event.position, _camera,
							true)
				_drag_start = VECTOR2_ZERO
				_drag_segment_start = VECTOR2_ZERO
				_drag_mode = -1
			is_handled = true
	elif event is InputEventMouseMotion:
		if _drag_segment_start: # accumulate mouse drag motion
			var current_mouse_pos: Vector2 = event.position
			_drag_vector += current_mouse_pos - _drag_segment_start
			_drag_segment_start = current_mouse_pos
			is_handled = true
	elif event.is_action_type():
		if event.is_pressed():
			if event.is_action_pressed("camera_zoom_view"):
				_camera.move_to_selection(null, VIEW_ZOOM, Vector3.ZERO, Vector3.ZERO, -1)
			elif event.is_action_pressed("camera_45_view"):
				_camera.move_to_selection(null, VIEW_45, Vector3.ZERO, Vector3.ZERO, -1)
			elif event.is_action_pressed("camera_top_view"):
				_camera.move_to_selection(null, VIEW_TOP, Vector3.ZERO, Vector3.ZERO, -1)
			
			# TODO: VIEW_OUTWARD
			
			
			elif event.is_action_pressed("recenter"):
				_camera.move_to_selection(null, -1, Vector3.ZERO, Vector3.ZERO, -1)
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
			_mouse_in_out_rate = value * mouse_wheel_adj
		"camera_mouse_move_rate":
			_mouse_move_rate = value * mouse_move_adj
		"camera_mouse_pitch_yaw_rate":
			_mouse_pitch_yaw_rate = value * mouse_pitch_yaw_adj
		"camera_mouse_roll_rate":
			_mouse_roll_rate = value * mouse_roll_adj
		"camera_key_in_out_rate":
			_key_in_out_rate = value * key_in_out_adj
		"camera_key_move_rate":
			_key_move_rate = value * key_move_adj
		"camera_key_pitch_yaw_rate":
			_key_pitch_yaw_rate = value * key_pitch_yaw_adj
		"camera_key_roll_rate":
			_key_roll_rate = value * key_roll_adj
