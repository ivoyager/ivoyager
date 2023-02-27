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

const FRAGMENT_SBG_POINT := IVFragmentIdentifier.FRAGMENT_SBG_POINT
const PI_DIV_3 := PI / 3.0 # 60 degrees
const ARRAY_FLAGS = (
		ArrayMesh.ARRAY_FORMAT_VERTEX
		| ArrayMesh.ARRAY_FORMAT_COLOR
		| ArrayMesh.ARRAY_FORMAT_NORMAL
		| ArrayMesh.ARRAY_FORMAT_TEX_UV
)
const L4_L5_ARRAY_FLAGS = (
		ArrayMesh.ARRAY_FORMAT_VERTEX
		| ArrayMesh.ARRAY_FORMAT_COLOR
		| ArrayMesh.ARRAY_FORMAT_NORMAL
		| ArrayMesh.ARRAY_FORMAT_TEX_UV
		| ArrayMesh.ARRAY_FORMAT_TEX_UV2
)

var _times: Array = IVGlobal.times
var _fragment_targeting: Array = IVGlobal.fragment_targeting
var _fragment_identifier: IVFragmentIdentifier = IVGlobal.program.get("FragmentIdentifier")
var _sbg_huds_state: IVSBGHUDsState = IVGlobal.program.SBGHUDsState
var _group: IVSmallBodiesGroup
var _color: Color
var _vec3ids := PoolVector3Array() # point ids for FragmentIdentifier

# Lagrange point
var _lp_integer := -1
var _secondary_orbit: IVOrbit



func _init(group: IVSmallBodiesGroup) -> void:
	_group = group
	_lp_integer = _group.lp_integer
	material_override = ShaderMaterial.new()
	if _lp_integer == -1: # not trojans
		material_override.shader = IVGlobal.shared.points_shader
	elif _lp_integer >= 4: # trojans
		_secondary_orbit = _group.secondary_body.orbit
		material_override.shader = IVGlobal.shared.points_l4_l5_shader
	else:
		assert(false)
	# fragment ids
	var n := group.get_number()
	_vec3ids.resize(n) # needs resize whether we use ids or not
	if _fragment_identifier:
		var i := 0
		while i < n:
			var data := group.get_fragment_data(FRAGMENT_SBG_POINT, i)
			_vec3ids[i] = _fragment_identifier.get_new_id_as_vec3(data)
			i += 1


func _ready() -> void:
	if _fragment_identifier:
		pause_mode = PAUSE_MODE_PROCESS # FragmentIdentifier still processing
	_sbg_huds_state.connect("points_visibility_changed", self, "_set_visibility")
	_sbg_huds_state.connect("points_color_changed", self, "_set_color")
	IVGlobal.connect("setting_changed", self, "_settings_listener")
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	draw_points()


func draw_points() -> void:
	var points_mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	if _lp_integer == -1: # not trojans
		arrays[ArrayMesh.ARRAY_VERTEX] = _vec3ids
		arrays[ArrayMesh.ARRAY_COLOR] = _group.e_i_Om_w
		arrays[ArrayMesh.ARRAY_NORMAL] = _group.a_M0_n
		arrays[ArrayMesh.ARRAY_TEX_UV] = _group.s_g
		points_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays, [], ARRAY_FLAGS)
	else: # trojans
		arrays[ArrayMesh.ARRAY_VERTEX] = _vec3ids
		arrays[ArrayMesh.ARRAY_COLOR] = _group.e_i_Om_w
		arrays[ArrayMesh.ARRAY_NORMAL] = _group.da_D_f
		arrays[ArrayMesh.ARRAY_TEX_UV] = _group.s_g
		arrays[ArrayMesh.ARRAY_TEX_UV2] = _group.th0_de
		points_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays, [], L4_L5_ARRAY_FLAGS)
	var half_aabb = _group.max_apoapsis * Vector3.ONE
	points_mesh.custom_aabb = AABB(-half_aabb, 2.0 * half_aabb)
	mesh = points_mesh
	material_override.set_shader_param("point_size", float(IVGlobal.settings.point_size))
	if _fragment_identifier:
		material_override.set_shader_param("fragment_range", _fragment_targeting[1])
	if _lp_integer >= 4: # trojans
		material_override.set_shader_param("lp_integer", _lp_integer)
		var characteristic_length := _secondary_orbit.get_characteristic_length()
		material_override.set_shader_param("characteristic_length", characteristic_length)
	_set_visibility()
	_set_color()


func _process(_delta: float) -> void:
	if !visible :
		return
	# TODO 4.0: global uniforms!
	material_override.set_shader_param("time", _times[0])
	if _lp_integer == 4:
		var lp_mean_longitude := _secondary_orbit.get_mean_longitude() + PI_DIV_3
		material_override.set_shader_param("lp_mean_longitude", lp_mean_longitude)
	elif _lp_integer == 5:
		var lp_mean_longitude := _secondary_orbit.get_mean_longitude() - PI_DIV_3
		material_override.set_shader_param("lp_mean_longitude", lp_mean_longitude)
	if _fragment_identifier:
		material_override.set_shader_param("mouse_coord", _fragment_targeting[0])
		material_override.set_shader_param("fragment_cycler", _fragment_targeting[2])


func _set_visibility() -> void:
	visible = _sbg_huds_state.is_points_visible(_group.group_name)


func _set_color() -> void:
	var color := _sbg_huds_state.get_points_color(_group.group_name)
	if _color == color:
		return
	_color = color
	material_override.set_shader_param("color", Vector3(color.r, color.g, color.b))


func _settings_listener(setting: String, value) -> void:
	if setting == "point_size":
		material_override.set_shader_param("point_size", float(value))

