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

const FRAGMENT_SBG_ORBIT := IVFragmentIdentifier.FRAGMENT_SBG_ORBIT

var _fragment_targeting: Array = IVGlobal.fragment_targeting
var _fragment_identifier: IVFragmentIdentifier = IVGlobal.program.get("FragmentIdentifier")
var _sbg_huds_state: IVSBGHUDsState = IVGlobal.program.SBGHUDsState

var _group: IVSmallBodiesGroup
var _color: Color
var _vec3ids := PoolVector3Array() # orbit ids for FragmentIdentifier



func _init(group: IVSmallBodiesGroup) -> void:
	_group = group
	# fragment ids
	if _fragment_identifier:
		var n := group.get_number()
		_vec3ids.resize(n)
		var i := 0
		while i < n:
			var data := group.get_fragment_data(FRAGMENT_SBG_ORBIT, i)
			_vec3ids[i] = _fragment_identifier.get_new_id_as_vec3(data)
			i += 1


func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS # FragmentIdentifier still processing
	_sbg_huds_state.connect("orbits_visibility_changed", self, "_set_visibility")
	_sbg_huds_state.connect("orbits_color_changed", self, "_set_color")
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = IVGlobal.shared.circle_mesh_low_res
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	if _fragment_identifier: # use self-identifying fragment shader
		multimesh.custom_data_format = MultiMesh.CUSTOM_DATA_FLOAT # orbit ids
		material_override = ShaderMaterial.new()
		material_override.shader = IVGlobal.shared.orbits_shader
		material_override.set_shader_param("fragment_range", _fragment_targeting[1]) # TODO4.0: global uniform
	else:
		material_override = SpatialMaterial.new()
		material_override.flags_unshaded = true
		set_process(false)
	_set_transforms_and_ids()
	_set_visibility()
	_set_color()


func _process(_delta: float) -> void:
	# Disabled unless we have FragmentIdentifier.
	if !visible:
		return
	# TODO4.0: These are global uniforms, so we can do this globally!
	material_override.set_shader_param("mouse_coord", _fragment_targeting[0])
	material_override.set_shader_param("fragment_cycler", _fragment_targeting[2])


func _set_transforms_and_ids() -> void:
	var n := _group.get_number()
	multimesh.instance_count = n
	var i := 0
	while i < n:
		# currently assumes ecliptic reference
		var elements := _group.get_orbit_elements(i)
		var a: float = elements[0]
		var e: float = elements[1]
		var b: = sqrt(a * a * (1.0 - e * e)) # simi-minor axis
		var orbit_basis := Basis().scaled(Vector3(a, b, 1.0))
		orbit_basis = math.get_rotation_matrix(elements) * orbit_basis
		var orbit_transform := Transform(orbit_basis, -e * orbit_basis.x)
		multimesh.set_instance_transform(i, orbit_transform)
		if _fragment_identifier:
			var vec3id := _vec3ids[i]
			multimesh.set_instance_custom_data(i, Color(vec3id.x, vec3id.y, vec3id.z, 0.0))
		i += 1


func _set_visibility() -> void:
	visible = _sbg_huds_state.is_orbits_visible(_group.group_name)


func _set_color() -> void:
	var color := _sbg_huds_state.get_orbits_color(_group.group_name)
	if _color == color:
		return
	_color = color
	if _fragment_identifier:
		material_override.set_shader_param("color", Vector3(color.r, color.g, color.b))
	else:
		material_override.albedo_color = color

