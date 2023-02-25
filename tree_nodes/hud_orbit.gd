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
class_name IVHUDOrbit
extends MeshInstance

# Visual orbit for a Body instance. If FragmentIdentifier exists, then a shader
# is used to allow screen identification of the orbit loop.

const math := preload("res://ivoyager/static/math.gd")


var _fragment_identifier: IVFragmentIdentifier = IVGlobal.program.get("FragmentIdentifier") # opt
var _body_huds_visibility: IVBodyHUDsVisibility = IVGlobal.program.BodyHUDsVisibility
var _times: Array = IVGlobal.times
var _world_targeting: Array = IVGlobal.world_targeting
# instance info
var _body: IVBody
var _orbit: IVOrbit
var _body_flags: int
var _visibility_flag: int
var _color: Color
# visibility control
var _is_orbit_group_visible: bool
var _body_huds_visible: bool # too close / too far
var _body_visible: bool # this HUD node is sibling (nut child) of its Body
var _needs_transform := true



func _init(body: IVBody) -> void:
	_body = body
	_orbit = body.orbit
	_body_flags = body.flags
	_visibility_flag = _body_flags & _body_huds_visibility.visibility_flags
	assert(_visibility_flag and !(_visibility_flag & (_visibility_flag - 1)),
			"_visibility_flag failed single bit test")


func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS # FragmentIdentifier still processing
	_orbit.connect("changed", self, "_set_transform_from_orbit")
	_body_huds_visibility.connect("visibility_changed", self, "_on_global_huds_changed")
	_body.connect("huds_visibility_changed", self, "_on_body_huds_changed")
	_body.connect("visibility_changed", self, "_on_body_visibility_changed")
	IVGlobal.connect("setting_changed", self, "_settings_listener")
	mesh = IVGlobal.shared.circle_mesh
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	if _fragment_identifier: # use self-identifying fragment shader
		var fragment_info := [_body.name, _fragment_identifier.FRAGMENT_ORBIT]
		var fragment_id := _fragment_identifier.get_new_id_as_vec3(fragment_info)
		material_override = ShaderMaterial.new()
		material_override.shader = IVGlobal.shared.orbit_shader
#		material_override.set_shader_param("color", Vector3(color.r, color.g, color.b))
		material_override.set_shader_param("fragment_id", fragment_id)
		material_override.set_shader_param("fragment_range", _world_targeting[7]) # TODO4.0: global uniform
	else:
		material_override = SpatialMaterial.new()
		material_override.flags_unshaded = true
#		material_override.albedo_color = color
		set_process(false)
	_set_color(IVGlobal.settings.body_orbit_colors)
	_body_huds_visible = _body.huds_visible
	_body_visible = _body.visible
	_on_global_huds_changed()


func _process(_delta: float) -> void:
	# Disabled unless we have FragmentIdentifier.
	if !visible:
		return
	# TODO4.0: These are global uniforms, so we can do this globally!
	material_override.set_shader_param("fragment_cycler", _world_targeting[8])
	material_override.set_shader_param("mouse_coord", _world_targeting[6])


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
	_is_orbit_group_visible = _body_huds_visibility.is_orbit_visible(_body_flags)
	_set_visual_state()


func _on_body_huds_changed(is_visible: bool) -> void:
	_body_huds_visible = is_visible
	_set_visual_state()


func _on_body_visibility_changed() -> void:
	_body_visible = _body.visible
	_set_visual_state()


func _set_visual_state() -> void:
	visible = _is_orbit_group_visible and _body_huds_visible and _body_visible
	if visible and _needs_transform:
		_set_transform_from_orbit()


func _set_color(orbit_colors: Dictionary) -> void:
	var new_color: Color
	if orbit_colors.has(_visibility_flag):
		new_color = orbit_colors[_visibility_flag]
	else:
		new_color = IVGlobal.settings.body_orbit_default_color
	if _color == new_color:
		return
	_color = new_color
	if _fragment_identifier:
		material_override.set_shader_param("color", Vector3(new_color.r, new_color.g, new_color.b))
	else:
		material_override.albedo_color = new_color


func _settings_listener(setting: String, value) -> void:
	if setting == "body_orbit_colors":
		_set_color(value)

