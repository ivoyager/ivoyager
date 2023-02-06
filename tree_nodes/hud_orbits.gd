# hud_orbit.gd
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
class_name IVHUDOrbits
extends MultiMeshInstance

# Visual orbits for a SmallBodiesGroup instance. If FragmentIdentifier exists,
# then a shader is used to allow screen identification of the orbit loops.

const math := preload("res://ivoyager/static/math.gd")

var _huds_visibility: IVHUDsVisibility = IVGlobal.program.HUDsVisibility
var _fragment_identifier: IVFragmentIdentifier = IVGlobal.program.get("FragmentIdentifier")
var _world_targeting: Array = IVGlobal.world_targeting

var _group: IVSmallBodiesGroup
var _color_setting: String



func _init(group: IVSmallBodiesGroup, color_setting: String) -> void:
	_group = group
	_color_setting = color_setting


func _ready() -> void:
	_huds_visibility.connect("sbg_orbits_visibility_changed", self, "_on_visibility_changed")
	IVGlobal.connect("setting_changed", self, "_settings_listener")
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = IVGlobal.shared.circle_mesh_low_res
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	var color: Color = IVGlobal.settings[_color_setting]
	if _fragment_identifier: # use self-identifying fragment shader
		multimesh.custom_data_format = MultiMesh.CUSTOM_DATA_FLOAT # orbit ids
		material_override = ShaderMaterial.new()
		material_override.shader = IVGlobal.shared.orbits_shader
		material_override.set_shader_param("color", Vector3(color.r, color.g, color.b))
		material_override.set_shader_param("fragment_range", _world_targeting[7]) # TODO4.0: global uniform
	else:
		material_override = SpatialMaterial.new()
		material_override.flags_unshaded = true
		material_override.albedo_color = color
		set_process(false)
	_set_transforms_and_ids()
	hide()


func _process(_delta: float) -> void:
	# Disabled unless we have FragmentIdentifier.
	if !visible:
		return
	# TODO4.0: These are global uniforms, so we can do this globally!
	material_override.set_shader_param("fragment_cycler", _world_targeting[8])
	material_override.set_shader_param("mouse_coord", _world_targeting[6])


func _set_transforms_and_ids() -> void:
	var n := _group.get_number()
	multimesh.instance_count = n
	var index := 0
	while index < n:
		# currently assumes ecliptic reference
		var elements := _group.get_orbit_elements(index)
		var a: float = elements[0]
		var e: float = elements[1]
		var b: = sqrt(a * a * (1.0 - e * e)) # simi-minor axis
		var orbit_basis := Basis().scaled(Vector3(a, b, 1.0))
		orbit_basis = math.get_rotation_matrix(elements) * orbit_basis
		var orbit_transform := Transform(orbit_basis, -e * orbit_basis.x)
		multimesh.set_instance_transform(index, orbit_transform)
		if _fragment_identifier:
			var vec3id := _group.get_orbits_vec3id(index)
			multimesh.set_instance_custom_data(index, Color(vec3id.x, vec3id.y, vec3id.z, 0.0))
		index += 1


func _on_visibility_changed() -> void:
	visible = _huds_visibility.is_sbg_orbits_visible(_group.group_name)


func _settings_listener(setting: String, value) -> void:
	if setting == _color_setting:
		if _fragment_identifier:
			material_override.set_shader_param("color", Vector3(value.r, value.g, value.b))
		else:
			material_override.albedo_color = value
