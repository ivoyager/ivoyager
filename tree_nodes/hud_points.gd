# hud_points.gd
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
# This node constitutes many (up to 100000s of) display points as shaders that
# maintain their own orbit.

extends MeshInstance
class_name HUDPoints

const ORBIT_FLAGS = VisualServer.ARRAY_FORMAT_VERTEX & VisualServer.ARRAY_FORMAT_NORMAL \
		& VisualServer.ARRAY_FORMAT_COLOR
const TROJAN_FLAGS = VisualServer.ARRAY_FORMAT_VERTEX & VisualServer.ARRAY_FORMAT_NORMAL \
		& VisualServer.ARRAY_FORMAT_COLOR

var group: AsteroidGroup
var color: Color # read only

var _orbit_points := ShaderMaterial.new()
var _last_update_time := -INF

func init(group_: AsteroidGroup, color_: Color) -> void:
	group = group_
	color = color_
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	if !group.is_trojans:
		_orbit_points.shader = Global.shaders.orbit_points
	else:
		_orbit_points.shader = Global.shaders.orbit_points_lagrangian
	material_override = _orbit_points
	var timekeeper: Timekeeper = Global.program.Timekeeper
	timekeeper.connect("processed", self, "_timekeeper_process")

func draw_points() -> void:
	var points_mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = group.dummy_translations
	if !group.is_trojans:
		arrays[ArrayMesh.ARRAY_NORMAL] = group.a_e_i
		arrays[ArrayMesh.ARRAY_COLOR] = group.Om_w_M0_n
	#	arrays[ArrayMesh.ARRAY_TEX_UV] = group.s_g
		points_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays, [], ORBIT_FLAGS)
	else: # trojans
		arrays[ArrayMesh.ARRAY_NORMAL] = group.d_e_i
		arrays[ArrayMesh.ARRAY_COLOR] = group.Om_w_D_f
		arrays[ArrayMesh.ARRAY_TEX_UV2] = group.th0
		points_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays, [], TROJAN_FLAGS)
	var half_aabb = group.max_apoapsis * Vector3(1.1, 1.1, 1.1)
	points_mesh.custom_aabb = AABB(-half_aabb, 2.0 * half_aabb)
	mesh = points_mesh
	_orbit_points.set_shader_param("color", Vector3(color.r, color.g, color.b))
	_orbit_points.set_shader_param("point_size", 3.0)

func _init():
	hide()

func _ready() -> void:
	Global.connect("setting_changed", self, "_settings_listener")

func _timekeeper_process(time: float, _e_delta: float) -> void:
	if !visible or time == _last_update_time:
		return
	_last_update_time = time
	if group.lagrange_point:
		var langrange_elements: Array = group.lagrange_point.dynamic_elements
		var lagrange_a: float = langrange_elements[0]
		var lagrange_M: float = langrange_elements[5] + langrange_elements[6] * time
		var lagrange_L: float = lagrange_M + langrange_elements[4] + langrange_elements[3] # L = M + w + Om
		_orbit_points.set_shader_param("frame_data", Vector3(time, lagrange_a, lagrange_L))
	else:
		_orbit_points.set_shader_param("time", time)

func _settings_listener(setting: String, value) -> void:
	if setting == "asteroid_point_color":
		color = value
		_orbit_points.set_shader_param("color", Vector3(color.r, color.g, color.b))
