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

# Visual points for a SmallBodiesGroup instance. Uses points.shader or
# points_l4_l5.shader, which set vertex positions using their own orbital
# math.

const ARRAY_FLAGS = (
		ArrayMesh.ARRAY_FORMAT_VERTEX
		| ArrayMesh.ARRAY_FORMAT_NORMAL
		| ArrayMesh.ARRAY_FORMAT_COLOR
)
const TROJAN_ARRAY_FLAGS = (
		ArrayMesh.ARRAY_FORMAT_VERTEX
		| ArrayMesh.ARRAY_FORMAT_NORMAL
		| ArrayMesh.ARRAY_FORMAT_COLOR
		| ArrayMesh.ARRAY_FORMAT_TEX_UV2
)
const PI_DIV_3 := PI / 3.0 # 60 degrees

var _group: IVSmallBodiesGroup
var _color_setting: String

var _times: Array = IVGlobal.times
var _world_targeting: Array = IVGlobal.world_targeting

# Lagrange point
var _lp_integer := -1
var _secondary_orbit: IVOrbit

var _last_update_time := -INF

var _cycle_step := -1

onready var _huds_visibility: IVHUDsVisibility = IVGlobal.program.HUDsVisibility


func _init(group_: IVSmallBodiesGroup, color_setting: String) -> void:
	_group = group_
	_color_setting = color_setting
	_lp_integer = _group.lp_integer
	material_override = ShaderMaterial.new()
	if _lp_integer == -1: # not trojans
		material_override.shader = IVGlobal.shared.points_shader
	elif _lp_integer >= 4: # trojans
		_secondary_orbit = _group.secondary_body.orbit
		material_override.shader = IVGlobal.shared.points_l4_l5_shader
	else:
		assert(false)


func _ready() -> void:
	_huds_visibility.connect("sbg_points_visibility_changed", self, "_on_visibility_changed")
	IVGlobal.connect("setting_changed", self, "_settings_listener")
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	draw_points()
	hide()


func draw_points() -> void:
	var points_mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	if _lp_integer == -1: # not trojans
		arrays[ArrayMesh.ARRAY_VERTEX] = _group.points_vec3ids
		arrays[ArrayMesh.ARRAY_NORMAL] = _group.a_e_i
		arrays[ArrayMesh.ARRAY_COLOR] = _group.Om_w_M0_n
	#	arrays[ArrayMesh.ARRAY_TEX_UV] = _group.s_g
		points_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays, [], ARRAY_FLAGS)
	else: # trojans
		arrays[ArrayMesh.ARRAY_VERTEX] = _group.points_vec3ids
		arrays[ArrayMesh.ARRAY_NORMAL] = _group.d_e_i
		arrays[ArrayMesh.ARRAY_COLOR] = _group.Om_w_D_f
		arrays[ArrayMesh.ARRAY_TEX_UV2] = _group.th0
		points_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays, [], TROJAN_ARRAY_FLAGS)
	# if we needed custom_aabb... (but we don't apparently)
	var half_aabb = _group.max_apoapsis * Vector3(1.1, 1.1, 1.1)
	points_mesh.custom_aabb = AABB(-half_aabb, 2.0 * half_aabb)
	mesh = points_mesh
	var color: Color = IVGlobal.settings[_color_setting]
	material_override.set_shader_param("color", Vector3(color.r, color.g, color.b))
	material_override.set_shader_param("point_size", float(IVGlobal.settings.point_size))
	material_override.set_shader_param("fragment_range", _world_targeting[7])
	if _lp_integer >= 4: # trojans
		material_override.set_shader_param("lp_integer", _lp_integer)
		var characteristic_length := _secondary_orbit.get_characteristic_length()
		material_override.set_shader_param("characteristic_length", characteristic_length)


func _process(_delta: float) -> void:
	if !visible :
		return
	# TODO 4.0: global uniforms!
	material_override.set_shader_param("time", _times[0])
	material_override.set_shader_param("fragment_cycler", _world_targeting[8])
	material_override.set_shader_param("mouse_coord", _world_targeting[6])
	if _lp_integer == 4:
		var lp_mean_longitude := _secondary_orbit.get_mean_longitude() + PI_DIV_3
		material_override.set_shader_param("lp_mean_longitude", lp_mean_longitude)
	elif _lp_integer == 5:
		var lp_mean_longitude := _secondary_orbit.get_mean_longitude() - PI_DIV_3
		material_override.set_shader_param("lp_mean_longitude", lp_mean_longitude)


func _on_visibility_changed() -> void:
	visible = _huds_visibility.is_sbg_points_visible(_group.group_name)


func _settings_listener(setting: String, value) -> void:
	if setting == _color_setting:
		material_override.set_shader_param("color", Vector3(value.r, value.g, value.b))
	elif setting == "point_size":
		material_override.set_shader_param("point_size", float(value))
	
	
