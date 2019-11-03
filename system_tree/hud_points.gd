# orbit_points.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2019 Charlie Whitfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# *****************************************************************************
#
# This node constitutes many (up to 100000s of) display points as shaders that
# maintain their own orbit.
extends MeshInstance
class_name HUDPoints

const ORBIT_FLAGS = VisualServer.ARRAY_FORMAT_VERTEX & VisualServer.ARRAY_FORMAT_NORMAL \
		& VisualServer.ARRAY_FORMAT_COLOR
const TROJAN_FLAGS = VisualServer.ARRAY_FORMAT_VERTEX & VisualServer.ARRAY_FORMAT_NORMAL \
		& VisualServer.ARRAY_FORMAT_COLOR

var group: AsteroidGroup
var color: Color

var _timekeeper: Timekeeper = Global.objects.Timekeeper
var _orbit_points := ShaderMaterial.new()

func init(group_: AsteroidGroup, color_: Color) -> void:
	group = group_
	color = color_
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	if !group.is_trojans:
		_orbit_points.shader = Global.orbit_points_shader
	else:
		_orbit_points.shader = Global.orbit_points_lagrangian_shader
	material_override = _orbit_points

func draw_points() -> void:
	var points_mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = group.dummy_translations
	if !group.is_trojans:
		arrays[ArrayMesh.ARRAY_NORMAL] = group.a_e_i
		arrays[ArrayMesh.ARRAY_COLOR] = group.Om_w_M0_n
	#	arrays[ArrayMesh.ARRAY_TEX_UV] = group.s_g
		points_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays, [], ORBIT_FLAGS)
	else: # trojans
		arrays[ArrayMesh.ARRAY_NORMAL] = group.d_e_i
		arrays[ArrayMesh.ARRAY_COLOR] = group.Om_w_D_f
		arrays[ArrayMesh.ARRAY_TEX_UV2] = group.th0
		points_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays, [], TROJAN_FLAGS)
	var half_aabb = group.max_apoapsis * Vector3(1.1, 1.1, 1.1)
	points_mesh.custom_aabb = AABB(-half_aabb, 2.0 * half_aabb)
	mesh = points_mesh
	_orbit_points.set_shader_param("color", Vector3(color.r, color.g, color.b))
	_orbit_points.set_shader_param("point_size", 3.0)

func show() -> void:
	if !_timekeeper.is_connected("processed", self, "_timekeeper_process"):
		_timekeeper.connect("processed", self, "_timekeeper_process")
		_timekeeper_process(_timekeeper.time, 0.0)
	.show()
	
func hide() -> void:
	if _timekeeper.is_connected("processed", self, "_timekeeper_process"):
		_timekeeper.disconnect("processed", self, "_timekeeper_process")
	.hide()

func _ready() -> void:
	hide()

func _timekeeper_process(time: float, _delta: float) -> void:
	if group.lagrange_point:
		var langrange_elements: Array = group.lagrange_point.dynamic_elements
		var lagrange_a: float = langrange_elements[0]
		var lagrange_M: float = langrange_elements[5] + langrange_elements[6] * time
		var lagrange_L: float = lagrange_M + langrange_elements[4] + langrange_elements[3] # L = M + w + Om
		_orbit_points.set_shader_param("frame_data", Vector3(time, lagrange_a, lagrange_L))
	else:
		_orbit_points.set_shader_param("time", time)
