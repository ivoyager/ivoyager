# sbg_points.gd
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
class_name IVSBGPoints
extends MeshInstance3D

# Visual points for a SmallBodiesGroup instance. Uses one of the 'points'
# shaders ('points.x.x.gdshader', where x.x represents a shader variant).
# Point shaders maintain vertex positions using their own orbital math.
#
# Points shader variants:
#    '.l4l5.' - for lagrange points L4 & L5.
#    '.id.' - broadcasts identity for IVFragmentIdentifier.

const FRAGMENT_SBG_POINT := IVFragmentIdentifier.FRAGMENT_SBG_POINT
const PI_DIV_3 := PI / 3.0 # 60 degrees


const ARRAY_FLAGS = (
	Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	| Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
	| Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT
)


const L4L5_ARRAY_FLAGS = (
	Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	| Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
	| Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT
)


var _fragment_identifier: IVFragmentIdentifier = IVGlobal.program.get(&"FragmentIdentifier")
var _sbg_huds_state: IVSBGHUDsState = IVGlobal.program[&"SBGHUDsState"]
var _group: IVSmallBodiesGroup
var _color: Color
var _vec3ids := PackedVector3Array() # point ids for FragmentIdentifier

# Lagrange point
var _lp_integer := -1
var _secondary_orbit: IVOrbit



func _init(group: IVSmallBodiesGroup) -> void:
	_group = group
	_lp_integer = _group.lp_integer
	var shader_material := ShaderMaterial.new()
	if _lp_integer == -1: # not trojans
		shader_material.shader = IVGlobal.shared_resources[&"points_id_shader"]
	elif _lp_integer >= 4: # trojans
		_secondary_orbit = _group.secondary_body.orbit
		shader_material.shader = IVGlobal.shared_resources[&"points_l4l5_id_shader"]
	else:
		assert(false)
	material_override = shader_material
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
		process_mode = PROCESS_MODE_ALWAYS # FragmentIdentifier still processing
	_sbg_huds_state.points_visibility_changed.connect(_set_visibility)
	_sbg_huds_state.points_color_changed.connect(_set_color)
	IVGlobal.setting_changed.connect(_settings_listener)
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	_draw_points()


func _process(_delta: float) -> void:
	if !visible :
		return
	var shader_material: ShaderMaterial = material_override
	if _lp_integer == 4:
		var lp_mean_longitude := _secondary_orbit.get_mean_longitude() + PI_DIV_3
		shader_material.set_shader_parameter(&"lp_mean_longitude", lp_mean_longitude)
	elif _lp_integer == 5:
		var lp_mean_longitude := _secondary_orbit.get_mean_longitude() - PI_DIV_3
		shader_material.set_shader_parameter(&"lp_mean_longitude", lp_mean_longitude)


func _draw_points() -> void:
	var points_mesh := ArrayMesh.new()
	var arrays := [] # packed arrays
	arrays.resize(Mesh.ARRAY_MAX)
	
	if _lp_integer == -1: # not trojans
		arrays[Mesh.ARRAY_VERTEX] = _vec3ids
		arrays[Mesh.ARRAY_CUSTOM0] = _group.e_i_Om_w
		arrays[Mesh.ARRAY_CUSTOM1] = _group.a_M0_n
		arrays[Mesh.ARRAY_CUSTOM2] = _group.s_g_mag
		points_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays, [], {}, ARRAY_FLAGS)
	
	else: # trojans
		arrays[Mesh.ARRAY_VERTEX] = _vec3ids
		arrays[Mesh.ARRAY_CUSTOM0] = _group.e_i_Om_w
		arrays[Mesh.ARRAY_CUSTOM1] = _group.da_D_f_th0
		arrays[Mesh.ARRAY_CUSTOM2] = _group.s_g_mag
		points_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays, [], {}, L4L5_ARRAY_FLAGS)
	
	var half_aabb = _group.max_apoapsis * Vector3.ONE
	points_mesh.custom_aabb = AABB(-half_aabb, 2.0 * half_aabb)
	mesh = points_mesh
	var shader_material: ShaderMaterial = material_override
	shader_material.set_shader_parameter(&"point_size", float(IVGlobal.settings.point_size))
	if _lp_integer >= 4: # trojans
		shader_material.set_shader_parameter(&"lp_integer", _lp_integer)
		var characteristic_length := _secondary_orbit.get_semimajor_axis()
		shader_material.set_shader_parameter(&"characteristic_length", characteristic_length)
	_set_visibility()
	_set_color()


func _set_visibility() -> void:
	visible = _sbg_huds_state.is_points_visible(_group.sbg_alias)


func _set_color() -> void:
	var color := _sbg_huds_state.get_points_color(_group.sbg_alias)
	if _color == color:
		return
	_color = color
	var shader_material: ShaderMaterial = material_override
	shader_material.set_shader_parameter(&"color", Vector3(color.r, color.g, color.b))


func _settings_listener(setting: StringName, value: Variant) -> void:
	if setting == &"point_size":
		var shader_material: ShaderMaterial = material_override
		# setting value is int; shader parameter is float
		shader_material.set_shader_parameter(&"point_size", float(value))

