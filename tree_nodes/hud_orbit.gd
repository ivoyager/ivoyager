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

# Visual orbit for a Body instance.

const math := preload("res://ivoyager/static/math.gd")

var _times: Array = IVGlobal.times
var _world_targeting: Array = IVGlobal.world_targeting
var _orbit: IVOrbit
var _color_setting: String
var _fragment_identifier: IVFragmentIdentifier = IVGlobal.program.get("FragmentIdentifier")
var _fragment_id: Vector3



func _init(orbit: IVOrbit, body_flags: int, body_name: String) -> void:
	_orbit = orbit
	var BodyFlags := IVEnums.BodyFlags
	if body_flags & BodyFlags.IS_MOON and body_flags & BodyFlags.LIKELY_HYDROSTATIC_EQUILIBRIUM:
		_color_setting = "moon_orbit_color"
	elif body_flags & BodyFlags.IS_MOON:
		_color_setting = "minor_moon_orbit_color"
	elif body_flags & BodyFlags.IS_TRUE_PLANET:
		_color_setting = "planet_orbit_color"
	elif body_flags & BodyFlags.IS_DWARF_PLANET:
		_color_setting = "dwarf_planet_orbit_color"
	elif body_flags & BodyFlags.IS_ASTEROID:
		_color_setting = "asteroid_orbit_color"
	elif body_flags & BodyFlags.IS_SPACECRAFT:
		_color_setting = "spacecraft_orbit_color"
	else:
		_color_setting = "default_orbit_color"
	if _fragment_identifier:
		var fragment_info := [body_name, IVFragmentIdentifier.FRAGMENT_ORBIT]
		_fragment_id = _fragment_identifier.get_new_id_as_vec3(fragment_info)


func _ready() -> void:
	if IVGlobal.state.is_started_or_about_to_start:
		_set_transform_from_orbit()
	else:
		IVGlobal.connect("about_to_start_simulator", self, "_set_transform_from_orbit")
	_orbit.connect("changed", self, "_set_transform_from_orbit")
	IVGlobal.connect("setting_changed", self, "_settings_listener")
	mesh = IVGlobal.shared.circle_mesh
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	var color: Color = IVGlobal.settings[_color_setting]
	if _fragment_identifier:
		material_override = ShaderMaterial.new()
		material_override.shader = IVGlobal.shared.orbit_shader
		material_override.set_shader_param("color", Vector3(color.r, color.g, color.b))
		material_override.set_shader_param("fragment_id", _fragment_id)
		material_override.set_shader_param("fragment_range", _world_targeting[7]) # TODO4.0: global uniform
	else:
		material_override = SpatialMaterial.new()
		material_override.flags_unshaded = true
		material_override.albedo_color = color
		set_process(false)
	hide()


func _process(_delta: float) -> void:
	# Disabled unless we have FragmentIdentifier.
	# TODO4.0: These are global uniforms, so we can do this globally!
	if !visible:
		return
	material_override.set_shader_param("fragment_cycler", _world_targeting[8])
	material_override.set_shader_param("mouse_coord", _world_targeting[6])


func _set_transform_from_orbit(_dummy := false) -> void:
	# Stretches, rotates and positions circle_mesh to make an orbit ellipse!
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


func _settings_listener(setting: String, value) -> void:
	if setting == _color_setting:
		if _fragment_identifier:
			material_override.set_shader_param("color", Vector3(value.r, value.g, value.b))
		else:
			material_override.albedo_color = value

