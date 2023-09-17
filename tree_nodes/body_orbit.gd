# body_orbit.gd
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
class_name IVBodyOrbit
extends MeshInstance3D

# Visual orbit for a Body instance. If FragmentIdentifier exists, then a shader
# is used to allow screen identification of the orbit loop.

const math := preload("res://ivoyager/static/math.gd")

const FRAGMENT_BODY_ORBIT := IVFragmentIdentifier.FRAGMENT_BODY_ORBIT

var _fragment_identifier: IVFragmentIdentifier = IVGlobal.program.get(&"FragmentIdentifier") # opt
var _body_huds_state: IVBodyHUDsState = IVGlobal.program.BodyHUDsState
var _times: Array[float] = IVGlobal.times

var _body: IVBody
var _orbit: IVOrbit
var _body_flags: int
var _visibility_flag: int
var _color: Color

var _is_orbit_group_visible: bool
var _body_huds_visible: bool # too close / too far
var _body_visible: bool # this HUD node is sibling (not child) of its Body
var _needs_transform := true


func _init(body: IVBody) -> void:
	_body = body
	_orbit = body.orbit
	_body_flags = body.flags
	_visibility_flag = _body_flags & _body_huds_state.all_flags
	assert(_visibility_flag and !(_visibility_flag & (_visibility_flag - 1)),
			"_visibility_flag failed single bit test")


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS # FragmentIdentifier still processing
	_orbit.changed.connect(_set_transform_from_orbit)
	_body_huds_state.visibility_changed.connect(_on_global_huds_changed)
	_body_huds_state.color_changed.connect(_set_color)
	_body.huds_visibility_changed.connect(_on_body_huds_changed)
	_body.visibility_changed.connect(_on_body_visibility_changed)
	mesh = IVGlobal.shared_resources[&"circle_mesh"]
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	if _fragment_identifier: # use self-identifying fragment shader
		var data := _body.get_fragment_data(FRAGMENT_BODY_ORBIT)
		var fragment_id := _fragment_identifier.get_new_id_as_vec3(data)
		var shader_material := ShaderMaterial.new()
		shader_material.shader = IVGlobal.shared_resources[&"orbit_id_shader"]
		shader_material.set_shader_parameter(&"fragment_id", fragment_id)
		material_override = shader_material
	else:
		var standard_material := StandardMaterial3D.new()
		standard_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material_override = standard_material
	_set_color()
	_body_huds_visible = _body.huds_visible
	_body_visible = _body.visible
	_on_global_huds_changed()


func _set_transform_from_orbit(_is_scheduled := false) -> void:
	# Stretches, rotates and positions circle_mesh to make an orbit ellipse!
	if !visible:
		_needs_transform = true
		return
	_needs_transform = false
	var reference_normal := _orbit.reference_normal
	var elements := _orbit.get_elements(_times[0])
	var a: float = elements[0]
	var e: float = elements[1]
	var b: = sqrt(a * a * (1.0 - e * e)) # simi-minor axis
	var orbit_basis := Basis().scaled(Vector3(a, b, 1.0))
	orbit_basis = math.get_rotation_matrix(elements) * orbit_basis
	orbit_basis = math.rotate_basis_z(orbit_basis, reference_normal)
	transform.basis = orbit_basis
	transform.origin = -e * orbit_basis.x


func _on_global_huds_changed() -> void:
	_is_orbit_group_visible = _body_huds_state.is_orbit_visible(_body_flags)
	_set_visual_state()


func _on_body_huds_changed(is_visible_: bool) -> void:
	_body_huds_visible = is_visible_
	_set_visual_state()


func _on_body_visibility_changed() -> void:
	_body_visible = _body.visible
	_set_visual_state()


func _set_visual_state() -> void:
	visible = _is_orbit_group_visible and _body_huds_visible and _body_visible
	if visible and _needs_transform:
		_set_transform_from_orbit()


func _set_color() -> void:
	var color := _body_huds_state.get_orbit_color(_body_flags)
	if _color == color:
		return
	_color = color
	if _fragment_identifier:
		var shader_material: ShaderMaterial = material_override
		shader_material.set_shader_parameter(&"color", color)
	else:
		var standard_material: StandardMaterial3D = material_override
		standard_material.albedo_color = color

