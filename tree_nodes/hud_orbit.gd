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


const math := preload("res://ivoyager/static/math.gd")
const BodyFlags := IVEnums.BodyFlags

var _times: Array = IVGlobal.times
var _orbit: IVOrbit
var _body_flags: int # for color setting


func _init(orbit: IVOrbit, body_flags: int) -> void:
	_orbit = orbit
	_body_flags = body_flags


func _ready() -> void:
	if IVGlobal.state.is_started_or_about_to_start:
		_set_transform_from_orbit()
	else:
		IVGlobal.connect("about_to_start_simulator", self, "_set_transform_from_orbit")
	_orbit.connect("changed", self, "_set_transform_from_orbit")
	IVGlobal.connect("setting_changed", self, "_settings_listener")
	mesh = IVGlobal.shared.circle_mesh
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	material_override = SpatialMaterial.new() # every HUDOrbit has its own
	material_override.flags_unshaded = true
	var settings: Dictionary = IVGlobal.settings
	if _body_flags & BodyFlags.IS_MOON and _body_flags & BodyFlags.LIKELY_HYDROSTATIC_EQUILIBRIUM:
		material_override.albedo_color = settings.moon_orbit_color
	elif _body_flags & BodyFlags.IS_MOON:
		material_override.albedo_color = settings.minor_moon_orbit_color
	elif _body_flags & BodyFlags.IS_TRUE_PLANET:
		material_override.albedo_color = settings.planet_orbit_color
	elif _body_flags & BodyFlags.IS_DWARF_PLANET:
		material_override.albedo_color = settings.dwarf_planet_orbit_color
	else:
		material_override.albedo_color = settings.default_orbit_color
	hide()


func _set_transform_from_orbit(_dummy := false) -> void:
	# Converts mesh circle to an orbit ellipse!
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
	match setting:
		"planet_orbit_color":
			if _body_flags & BodyFlags.IS_TRUE_PLANET:
				material_override.albedo_color = value
		"dwarf_planet_orbit_color":
			if _body_flags & BodyFlags.IS_DWARF_PLANET:
				material_override.albedo_color = value
		"moon_orbit_color":
			if _body_flags & BodyFlags.IS_MOON \
					and _body_flags & BodyFlags.LIKELY_HYDROSTATIC_EQUILIBRIUM:
				material_override.albedo_color = value
		"minor_moon_orbit_color":
			if _body_flags & BodyFlags.IS_MOON \
					and not _body_flags & BodyFlags.LIKELY_HYDROSTATIC_EQUILIBRIUM:
				material_override.albedo_color = value
