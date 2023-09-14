# shared_initializer.gd
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
class_name SharedInitializer
extends RefCounted

# Adds constructed items to IVGlobal.shared.


func _init() -> void:
	_make_shared_resources()


func _project_init() -> void:
	IVGlobal.program.erase(&"SharedInitializer") # frees self


func _make_shared_resources() -> void:
	IVGlobal.shared[&"sphere_mesh"] = _make_sphere_mesh()
	IVGlobal.shared[&"circle_mesh"] = _make_circle_mesh(IVGlobal.vertecies_per_orbit)
	IVGlobal.shared[&"circle_mesh_low_res"] = _make_circle_mesh(IVGlobal.vertecies_per_orbit_low_res)


func _make_sphere_mesh() -> SphereMesh:
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 1.0
	sphere_mesh.height = 2.0
	return sphere_mesh


func _make_circle_mesh(n_vertecies: int) -> ArrayMesh:
	# All orbits (e < 1.0) are shared circle mesh with modified basis.
	var verteces := PackedVector3Array()
	verteces.resize(n_vertecies + 1)
	var angle_increment := TAU / n_vertecies
	var i := 0
	while i < n_vertecies:
		var angle: float = i * angle_increment
		verteces[i] = Vector3(sin(angle), cos(angle), 0.0) # radius = 1.0
		i += 1
	verteces[i] = verteces[0] # complete the loop
	var mesh_arrays := []
	mesh_arrays.resize(ArrayMesh.ARRAY_MAX)
	mesh_arrays[ArrayMesh.ARRAY_VERTEX] = verteces
	var circle_mesh := ArrayMesh.new()
	circle_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, mesh_arrays, [], {},
			ArrayMesh.ARRAY_FORMAT_VERTEX)
	return circle_mesh

