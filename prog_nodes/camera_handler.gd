# camera_handler.gd
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
class_name IVCameraHandler
extends Node

# Handles input for IVCamera movements and click selection. Remove or replace
# this class if you have a different camera.

enum {
	DRAG_MOVE,
	DRAG_PITCH_YAW,
	DRAG_ROLL,
	DRAG_PITCH_YAW_ROLL_HYBRID
}

const VIEW_ZOOM = IVEnums.ViewType.VIEW_ZOOM
const VIEW_45 = IVEnums.ViewType.VIEW_45
const VIEW_TOP = IVEnums.ViewType.VIEW_TOP
const VIEW_OUTWARD = IVEnums.ViewType.VIEW_OUTWARD
const VIEW_BUMPED = IVEnums.ViewType.VIEW_BUMPED
const VIEW_BUMPED_ROTATED = IVEnums.ViewType.VIEW_BUMPED_ROTATED
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
var left_drag := DRAG_MOVE
var right_drag := DRAG_PITCH_YAW_ROLL_HYBRID
var ctrl_drag := DRAG_PITCH_YAW_ROLL_HYBRID # same as right_drag for Mac!
var cmd_drag := DRAG_PITCH_YAW_ROLL_HYBRID # same as above?
var shift_drag := DRAG_PITCH_YAW
var alt_drag := DRAG_ROLL
var hybrid_drag_center_zone := 0.2 # for DRAG_PITCH_YAW_ROLL_HYBRID
var hybrid_drag_outside_zone := 0.7 # for DRAG_PITCH_YAW_ROLL_HYBRID

# private
var _settings: Dictionary = IVGlobal.settings
var _world_targeting: Array = IVGlobal.world_targeting
var _camera: IVCamera
var _selection_manager: IVSelectionManager

var _drag_mode := -1 # one of DRAG_ enums when active
var _drag_vector := VECTOR2_ZERO
var _mwheel_turning := 0.0
var _move_pressed := VECTOR3_ZERO
var _rotate_pressed := VECTOR3_ZERO

onready var _world_controller: IVWorldController = IVGlobal.program.WorldController
onready var _tree := get_tree()
onready var _viewport := get_viewport()
onready var _mouse_in_out_rate: float = _settings.camera_mouse_in_out_rate * mouse_wheel_adj
onready var _mouse_move_rate: float = _settings.camera_mouse_move_rate * mouse_move_adj
onready var _mouse_pitch_yaw_rate: float = _settings.camera_mouse_pitch_yaw_rate * mouse_pitch_yaw_adj
onready var _mouse_roll_rate: float = _settings.camera_mouse_roll_rate * mouse_roll_adj
onready var _key_in_out_rate: float = _settings.camera_key_in_out_rate * key_in_out_adj
onready var _key_move_rate: float = _settings.camera_key_move_rate * key_move_adj
onready var _key_pitch_yaw_rate: float = _settings.camera_key_pitch_yaw_rate * key_pitch_yaw_adj
onready var _key_roll_rate: float = _settings.camera_key_roll_rate * key_roll_adj


func _ready():
	IVGlobal.connect("about_to_start_simulator", self, "_on_about_to_start_simulator")
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_restore_init_state")
	IVGlobal.connect("camera_ready", self, "_connect_camera")
	IVGlobal.connect("setting_changed", self, "_settings_listener")
	_world_controller.connect("mouse_target_clicked", self, "_on_mouse_target_clicked")
	_world_controller.connect("mouse_dragged", self, "_on_mouse_dragged")
	_world_controller.connect("mouse_wheel_turned", self, "_on_mouse_wheel_turned")


func _on_about_to_start_simulator(_is_new_game: bool) -> void:
	_selection_manager = IVGlobal.program.ProjectGUI.selection_manager
	_selection_manager.connect("selection_changed", self, "_on_selection_changed")
	_selection_manager.connect("selection_reselected", self, "_on_selection_reselected")


func _process(delta: float) -> void:
	if _drag_vector:
		match _drag_mode:
			DRAG_MOVE:
				_drag_vector *= delta * _mouse_move_rate
				_camera.add_motion(Vector3(-_drag_vector.x, _drag_vector.y, 0.0))
			DRAG_PITCH_YAW:
				_drag_vector *= delta * _mouse_pitch_yaw_rate
				_camera.add_rotation(Vector3(_drag_vector.y, _drag_vector.x, 0.0))
			DRAG_ROLL:
				var mouse_position: Vector2 = _world_targeting[0]
				var center_to_mouse := (mouse_position - _viewport.size / 2.0).normalized()
				_drag_vector *= delta * _mouse_roll_rate
				_camera.add_rotation(Vector3(0.0, 0.0, center_to_mouse.cross(_drag_vector)))
			DRAG_PITCH_YAW_ROLL_HYBRID:
				# one or a mix of two above based on mouse position
				var mouse_position: Vector2 = _world_targeting[0]
				var mouse_rotate := _drag_vector * delta
				var z_proportion := (2.0 * mouse_position - _viewport.size).length() / _viewport.size.x
				z_proportion -= hybrid_drag_center_zone
				z_proportion /= hybrid_drag_outside_zone - hybrid_drag_center_zone
				z_proportion = clamp(z_proportion, 0.0, 1.0)
				var center_to_mouse := (mouse_position - _viewport.size / 2.0).normalized()
				var z_rotate := center_to_mouse.cross(mouse_rotate) * z_proportion * _mouse_roll_rate
				mouse_rotate *= (1.0 - z_proportion) * _mouse_pitch_yaw_rate
				_camera.add_rotation(Vector3(mouse_rotate.y, mouse_rotate.x, z_rotate))
		_drag_vector = VECTOR2_ZERO
	if _mwheel_turning:
		_camera.add_motion(Vector3(0.0, 0.0, _mwheel_turning * delta))
		_mwheel_turning = 0.0
	if _move_pressed:
		_camera.add_motion(_move_pressed * delta)
	if _rotate_pressed:
		_camera.add_rotation(_rotate_pressed * delta)


func _unhandled_key_input(event: InputEventKey) -> void:
	if !event.is_action_type() or !_camera:
		return
	if event.is_pressed():
		if event.is_action_pressed("camera_zoom_view"):
			_camera.move_to(null, VIEW_ZOOM, Vector3.ZERO, Vector3.ZERO, -1)
		elif event.is_action_pressed("camera_45_view"):
			_camera.move_to(null, VIEW_45, Vector3.ZERO, Vector3.ZERO, -1)
		elif event.is_action_pressed("camera_top_view"):
			_camera.move_to(null, VIEW_TOP, Vector3.ZERO, Vector3.ZERO, -1)
		elif event.is_action_pressed("recenter"):
			_camera.move_to(null, -1, Vector3.ZERO, Vector3.ZERO, -1)
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
		_tree.set_input_as_handled()
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
		_tree.set_input_as_handled()


func _restore_init_state() -> void:
	_disconnect_camera()
	if _selection_manager:
		_selection_manager.disconnect("selection_changed", self, "_on_selection_changed")
		_selection_manager = null


func _connect_camera(camera: IVCamera) -> void:
	_disconnect_camera()
	_camera = camera
	_camera.connect("camera_lock_changed", self, "_on_camera_lock_changed")


func _disconnect_camera() -> void:
	if !_camera:
		return
	_camera.disconnect("camera_lock_changed", self, "_on_camera_lock_changed")
	_camera = null


func _on_selection_changed() -> void:
	if _camera and _camera.is_camera_lock:
		# Cancel rotations, but keep relative position.
		_camera.move_to(_selection_manager.selection, -1, Vector3.ZERO,
				Vector3.ZERO, -1)

func _on_selection_reselected() -> void:
	if _camera and _camera.is_camera_lock:
		# Cancel rotations, but keep relative position.
		_camera.move_to(_selection_manager.selection, -1, Vector3.ZERO,
				Vector3.ZERO, -1)


func _on_camera_lock_changed(is_camera_lock: bool) -> void:
	if is_camera_lock:
		_camera.move_to(_selection_manager.selection, -1, Vector3.ZERO,
				NULL_ROTATION, -1)


func _on_mouse_target_clicked(target: Object, _button_mask: int, _key_modifier_mask: int) -> void:
	# We only handle IVBody as target object for now. This could change.
	if !_camera:
		return
	var body := target as IVBody
	if !body:
		return
	if _camera.is_camera_lock: # move via selection
		_selection_manager.select_body(body)
	else: # move camera directly
		# Cancel rotations, but keep relative position.
		_camera.move_to_body(body, -1, Vector3.ZERO, Vector3.ZERO, -1)


func _on_mouse_dragged(drag_vector: Vector2, button_mask: int, key_modifier_mask: int) -> void:
	_drag_vector += drag_vector
	if key_modifier_mask & KEY_MASK_CMD:
		_drag_mode = cmd_drag
	elif key_modifier_mask & KEY_MASK_CTRL:
		_drag_mode = ctrl_drag
	elif key_modifier_mask & KEY_MASK_ALT:
		_drag_mode = alt_drag
	elif key_modifier_mask & KEY_MASK_SHIFT:
		_drag_mode = shift_drag
	elif button_mask & BUTTON_MASK_RIGHT:
		_drag_mode = right_drag
	else:
		_drag_mode = left_drag


func _on_mouse_wheel_turned(is_up: bool) -> void:
	_mwheel_turning = _mouse_in_out_rate * (1.0 if is_up else -1.0)


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
