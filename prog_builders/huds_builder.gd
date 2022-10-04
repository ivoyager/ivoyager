# huds_builder.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2022 Charlie Whitfield
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
class_name IVHUDsBuilder


const BodyFlags := IVEnums.BodyFlags
const IS_TRUE_PLANET := BodyFlags.IS_TRUE_PLANET
const IS_DWARF_PLANET := BodyFlags.IS_DWARF_PLANET
const IS_MOON := BodyFlags.IS_MOON
const LIKELY_HYDROSTATIC_EQUILIBRIUM := BodyFlags.LIKELY_HYDROSTATIC_EQUILIBRIUM
const ORBIT_ARRAY_FLAGS := VisualServer.ARRAY_FORMAT_VERTEX & VisualServer.ARRAY_FORMAT_NORMAL

var _settings: Dictionary = IVGlobal.settings
var _HUDLabel_: Script
var _HUDOrbit_: Script
var _huds_manager: IVHUDsManager
var _world_controller: Control
var _orbit_ellipse_shader: Shader
var _orbit_mesh_arrays := []


func _project_init() -> void:
	_HUDLabel_ = IVGlobal.script_classes._HUDLabel_
	_HUDOrbit_ = IVGlobal.script_classes._HUDOrbit_
	_huds_manager = IVGlobal.program.HUDsManager
	_world_controller = IVGlobal.program.WorldController
	_orbit_ellipse_shader = IVGlobal.shared_resources.orbit_ellipse_shader
	_build_orbit_mesh_arrays(IVGlobal.vertecies_per_orbit)


func add_label(body: IVBody) -> void:
	var hud_label: IVHUDLabel = _HUDLabel_.new()
	hud_label.set_body_name(body.get_hud_name())
	hud_label.set_body_symbol(body.get_symbol())
	hud_label.hide()
	body.hud_label = hud_label
	body.add_child(hud_label)


func add_orbit(body: IVBody) -> void:
	if !body.orbit:
		return
	var hud_orbit: IVHUDOrbit = _HUDOrbit_.new()
	var color: Color
	var flags := body.flags
	if flags & IS_MOON and flags & LIKELY_HYDROSTATIC_EQUILIBRIUM:
		color = _settings.moon_orbit_color
	elif flags & IS_MOON:
		color = _settings.minor_moon_orbit_color
	elif flags & IS_TRUE_PLANET:
		color = _settings.planet_orbit_color
	elif flags & IS_DWARF_PLANET:
		color = _settings.dwarf_planet_orbit_color
	else:
		color = _settings.default_orbit_color
	hud_orbit.orbit = body.orbit
	hud_orbit.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	hud_orbit.shader_material.shader = _orbit_ellipse_shader
	hud_orbit.material_override = hud_orbit.shader_material
	hud_orbit.orbit_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_LOOP,
			_orbit_mesh_arrays, [], ORBIT_ARRAY_FLAGS)
	hud_orbit.mesh = hud_orbit.orbit_mesh
	hud_orbit.orbit.connect("changed", hud_orbit, "draw_orbit")
	hud_orbit.change_color(color)
	hud_orbit.draw_orbit(false)
	hud_orbit.hide()
	body.hud_orbit = hud_orbit
	var parent: Spatial = body.get_parent()
	parent.call_deferred("add_child", hud_orbit)


func _build_orbit_mesh_arrays(n_vertecies: int) -> void:
	var verteces := PoolVector3Array()
	var normals := PoolVector3Array()
	verteces.resize(n_vertecies)
	normals.resize(n_vertecies)
	var angle_increment := TAU / n_vertecies
	var i := 0
	while i < n_vertecies:
		var angle: float = i * angle_increment
		verteces[i] = Vector3(sin(angle), cos(angle), 0.0) # circle if shader doesn't work
		normals[i] = Vector3(angle, angle, 0.0) # E, nu, e in orbit_ellipse.shader
		i += 1
	_orbit_mesh_arrays.resize(ArrayMesh.ARRAY_MAX)
	_orbit_mesh_arrays[ArrayMesh.ARRAY_VERTEX] = verteces
	_orbit_mesh_arrays[ArrayMesh.ARRAY_NORMAL] = normals
