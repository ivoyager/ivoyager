# hud_orbit.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2020 Charlie Whitfield
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
#
# Reconstructed on load. Visibility controled by TreeManager.

extends MeshInstance
class_name HUDOrbit

const ARRAY_FLAGS := VisualServer.ARRAY_FORMAT_VERTEX & VisualServer.ARRAY_FORMAT_NORMAL

# private
var _orbit: Orbit
var _orbit_mesh := ArrayMesh.new()
var _orbit_graphic := ShaderMaterial.new()
var _global_time_array: Array = Global.time_date

# shader params
var _reference_normal: Vector3
var _shape_elements: Vector2 # a, e
var _rotation_elements: Vector3 # i, Om, w

static func make_mesh_arrays() -> Array:
	var vertecies_per_orbit: int = Global.vertecies_per_orbit
	var verteces := PoolVector3Array()
	var normals := PoolVector3Array()
	verteces.resize(vertecies_per_orbit)
	normals.resize(vertecies_per_orbit)
	var angle_increment := TAU / vertecies_per_orbit
	var i := 0
	while i < vertecies_per_orbit:
		var angle: float = i * angle_increment
		verteces[i] = Vector3(sin(angle), cos(angle), 0.0) # circle if shader doesn't work
		normals[i] = Vector3(angle, angle, 0.0) # E, nu, e in orbit_ellipse.shader
		i += 1
	var orbit_mesh_arrays := []
	orbit_mesh_arrays.resize(ArrayMesh.ARRAY_MAX)
	orbit_mesh_arrays[ArrayMesh.ARRAY_VERTEX] = verteces
	orbit_mesh_arrays[ArrayMesh.ARRAY_NORMAL] = normals
	return orbit_mesh_arrays # shared by all HUDOrbit instances

func init(orbit: Orbit, color: Color, orbit_mesh_arrays: Array) -> void:
	hide()
	_orbit = orbit
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	_orbit_graphic.shader = Global.shaders.orbit_ellipse
	material_override = _orbit_graphic
	_orbit_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_LOOP, orbit_mesh_arrays, [], ARRAY_FLAGS)
	mesh = _orbit_mesh
	_orbit_graphic.set_shader_param("color", Vector3(color.r, color.g, color.b))
	_orbit.connect("changed_for_graphics", self, "_draw_orbit")
	_draw_orbit()

func change_color(new_color: Color) -> void:
	_orbit_graphic.set_shader_param("color", Vector3(new_color.r, new_color.g, new_color.b))

func _draw_orbit() -> void:
	var reference_normal = _orbit.reference_normal
	if _reference_normal != reference_normal:
		_reference_normal = reference_normal
		_orbit_graphic.set_shader_param("reference_normal", _orbit.reference_normal)
	var orbital_elements := _orbit.get_elements(_global_time_array[0])
	var a: float = orbital_elements[0]
	var e: float = orbital_elements[1]
	var shape_elements := Vector2(a, e)
	if _shape_elements != shape_elements:
		_shape_elements = shape_elements
		_orbit_graphic.set_shader_param("shape", shape_elements)
		var apoapsis := a * (1.0 + e)
		var half_aabb := 3.0 * apoapsis * Vector3(1.0, 1.0, 1.0)
		_orbit_mesh.custom_aabb = AABB(-half_aabb, 2.0 * half_aabb)
	var rotation_elements := Vector3(orbital_elements[2], orbital_elements[3], orbital_elements[4]) # i, Om, w
	if _rotation_elements != rotation_elements:
		_rotation_elements = rotation_elements
		_orbit_graphic.set_shader_param("rotation", rotation_elements)
	
	
