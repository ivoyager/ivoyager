# hud_points.gd
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
class_name IVHUDPoints
extends MeshInstance

# This node constitutes many (up to 100000s of) display points as shaders that
# maintain their own orbit.

const ORBIT_FLAGS = (
		ArrayMesh.ARRAY_FORMAT_VERTEX
		| ArrayMesh.ARRAY_FORMAT_NORMAL
		| ArrayMesh.ARRAY_FORMAT_COLOR
)
const TROJAN_ORBIT_FLAGS = (
		ArrayMesh.ARRAY_FORMAT_VERTEX
		| ArrayMesh.ARRAY_FORMAT_NORMAL
		| ArrayMesh.ARRAY_FORMAT_COLOR
		| ArrayMesh.ARRAY_FORMAT_TEX_UV2
)
const CALIBRATION := IVPointPicker.CALIBRATION

var group: IVAsteroidGroup
var color: Color # read only

var _times: Array = IVGlobal.times
var _world_targeting: Array = IVGlobal.world_targeting
var _orbit_points := ShaderMaterial.new()
var _last_update_time := -INF


var _cycle_step := -1
var _calibration_size := CALIBRATION.size()
var _n_cycle_steps := _calibration_size + 3


func _init():
	hide()


func _ready() -> void:
	IVGlobal.connect("setting_changed", self, "_settings_listener")


func init(group_: IVAsteroidGroup, color_: Color) -> void:
	group = group_
	color = color_
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	if !group.is_trojans:
		_orbit_points.shader = IVGlobal.shared_resources.orbit_points_shader
	else:
		_orbit_points.shader = IVGlobal.shared_resources.orbit_points_lagrangian_shader
	material_override = _orbit_points


func draw_points() -> void:
	var points_mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	
	if !group.is_trojans:
		arrays[ArrayMesh.ARRAY_VERTEX] = group.vec3ids
		arrays[ArrayMesh.ARRAY_NORMAL] = group.a_e_i
		arrays[ArrayMesh.ARRAY_COLOR] = group.Om_w_M0_n
	#	arrays[ArrayMesh.ARRAY_TEX_UV] = group.s_g
		points_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays, [], ORBIT_FLAGS)
	else: # trojans
		arrays[ArrayMesh.ARRAY_VERTEX] = group.vec3ids
		arrays[ArrayMesh.ARRAY_NORMAL] = group.d_e_i
		arrays[ArrayMesh.ARRAY_COLOR] = group.Om_w_D_f
		arrays[ArrayMesh.ARRAY_TEX_UV2] = group.th0
		points_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays, [], TROJAN_ORBIT_FLAGS)
	var half_aabb = group.max_apoapsis * Vector3(1.1, 1.1, 1.1)
	points_mesh.custom_aabb = AABB(-half_aabb, 2.0 * half_aabb)
	mesh = points_mesh
	_orbit_points.set_shader_param("color", Vector3(color.r, color.g, color.b))
	_orbit_points.set_shader_param("point_size", float(IVGlobal.settings.point_size))
	_orbit_points.set_shader_param("point_picker_range", float(_world_targeting[7]))


func _process(_delta: float) -> void:
	var time: float = _times[0]
	if !visible or time == _last_update_time:
		return
	_last_update_time = time
	_cycle_step += 1
	if _cycle_step == _n_cycle_steps:
		_cycle_step = 0
	var cycle_value: float
	if _cycle_step < _calibration_size:
		cycle_value = CALIBRATION[_cycle_step] # calibration values (0.25..0.75)
	else:
		cycle_value = float(_cycle_step - _calibration_size + 1) # 1.0, 2.0, 3.0
	_orbit_points.set_shader_param("time_cycle", Vector2(time, cycle_value))
	_orbit_points.set_shader_param("mouse_coord", _world_targeting[6])
	# TODO 4.0: Set above data as global uniforms!
	if group.lagrange_point:
		var langrange_elements: Array = group.lagrange_point.dynamic_elements
		var lagrange_a: float = langrange_elements[0]
		var lagrange_M: float = langrange_elements[5] + langrange_elements[6] * time
		var lagrange_L: float = lagrange_M + langrange_elements[4] + langrange_elements[3] # L = M + w + Om
		_orbit_points.set_shader_param("lagrange_data", Vector2(lagrange_a, lagrange_L))


func _settings_listener(setting: String, value) -> void:
	if setting == "asteroid_point_color":
		color = value
		color.a = 1.0
		_orbit_points.set_shader_param("color", Vector3(color.r, color.g, color.b))
	elif setting == "point_size":
		_orbit_points.set_shader_param("point_size", float(value))
	
	
