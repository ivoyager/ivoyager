# rotating_space.gd
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
class_name IVRotatingSpace
extends Node3D

# Created and maintained by IVBody instance only when needed. This is the
# rotating reference frame in which Lagrange points are embeded. In
# RotatingSpace, the primary body (P1) is maintained at constant position
# (-characteristic_length, 0, 0). The secondary body (P2) will be near the
# origin, but ocillating along the x-axis in proportion to orbit eccentricity.
#
# Note: Lagrange point calculations assume "large" mass ratio (> ~25) and
# "small" eccentricity. I'm not sure exactly what small eccentricity means.


const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL # free & rebuild on load
const PERSIST_PROPERTIES := [
	&"mass_ratio",
	&"characteristic_length",
	&"characteristic_time",
	&"lagrange_point_vectors",
	&"_LagrangePoints",
]

# lagrange parameters
var mass_ratio: float
var characteristic_length: float 
var characteristic_time: float
var lagrange_point_vectors: Array[Vector3] = [] # in rotating frame; index = lp_integer - 1

# private - use API to get LagrangePoint instances
var _LagrangePoints := [] # index = lp_integer - 1



func init(mass_ratio_: float, characteristic_length_: float, characteristic_time_: float) -> void:
	mass_ratio = mass_ratio_
	characteristic_length = characteristic_length_
	characteristic_time = characteristic_time_
	lagrange_point_vectors.resize(5)
	var r := characteristic_length * pow(1.0 / (3.0 * mass_ratio), 1.0 / 3.0) # Hill sphere radius
	lagrange_point_vectors[0] = Vector3(-r, 0.0, 0.0) # L1
	lagrange_point_vectors[1] = Vector3(r, 0.0, 0.0) # L2
	var r3 := characteristic_length * 7.0 / (12.0 * mass_ratio)
	lagrange_point_vectors[2] = Vector3(r3 - 2.0 * characteristic_length, 0.0, 0.0) # L3
	var x45 := -characteristic_length / 2.0
	var y4 := characteristic_length * (sqrt(3.0) / 2.0)
	lagrange_point_vectors[3] = Vector3(x45, y4, 0.0) # L4
	lagrange_point_vectors[4] = Vector3(x45, -y4, 0.0) # L5


func get_lagrange_point_local_space(lp_integer: int) -> Vector3:
	var l_point_vector: Vector3 = lagrange_point_vectors[lp_integer - 1]
	return transform.basis * l_point_vector


func get_lagrange_point_global_space(lp_integer: int) -> Vector3:
	var l_point_vector: Vector3 = lagrange_point_vectors[lp_integer - 1]
	return global_transform.basis * l_point_vector


func get_lagrange_point_node3d(lp_integer: int) -> IVLagrangePoint:
	if !_LagrangePoints:
		_LagrangePoints.resize(5)
	if !_LagrangePoints[lp_integer]:
		var _LagrangePoint_: GDScript = IVGlobal.script_classes._LagrangePoint_
		var lagrange_point: IVLagrangePoint = _LagrangePoint_.new()
		lagrange_point.init(lp_integer)
		lagrange_point.position = lagrange_point_vectors[lp_integer - 1]
		_LagrangePoints[lp_integer] = lagrange_point
		add_child(lagrange_point)
	return _LagrangePoints[lp_integer]

