# rings_builder.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield
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
# TODO: a rings shader! See: https://bjj.mmedia.is/data/s_rings
# What we have now is a QuadMesh & Texture.


class_name RingsBuilder

const math := preload("res://ivoyager/static/math.gd") # =Math when issue #37529 fixed
const file_utils := preload("res://ivoyager/static/file_utils.gd")

var rings_too_far_radius_multiplier := 2e3


func add_rings(body: Body) -> void:
	var file_prefix: String = body.get_rings_file_prefix()
	var radius: float = body.get_rings_radius()
	var north: Vector3 = body.get_north_pole()
	var array := [body, file_prefix, radius, north]
	var io_manager: IOManager = Global.program.IOManager
	io_manager.callback(self, "_make_rings_on_io_thread", "_io_finish", array)

# *****************************************************************************

func _make_rings_on_io_thread(array: Array) -> void: # I/O thread
	var file_prefix: String = array[1]
	var radius: float = array[2]
	var north: Vector3 = array[3]
	var rings_search: Array = Global.rings_search
	var texture: Texture = file_utils.find_and_load_resource(rings_search, file_prefix)
	assert(texture, "Could not find rings texture (no fallback!)")
	var rings := MeshInstance.new()
	var rings_material := SpatialMaterial.new()
	rings_material.albedo_texture = texture
	rings_material.flags_transparent = true
	rings_material.params_cull_mode = SpatialMaterial.CULL_DISABLED
	rings_material.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
	rings.scale = Vector3(radius * 2.0, radius * 2.0, 1.0)
	var basis := math.rotate_basis_z(rings.transform.basis, north)
	rings.transform.basis = basis
	rings.cast_shadow = MeshInstance.SHADOW_CASTING_SETTING_ON
	rings.mesh = QuadMesh.new()
	rings.set_surface_material(0, rings_material)
	rings.hide()
	array.append(rings)

func _io_finish(array: Array) -> void: # Main thread
	var body: Body = array[0]
	var radius: float = array[2]
	var rings: MeshInstance = array[4]
	body.max_aux_graphic_dist = radius * rings_too_far_radius_multiplier
	body.aux_graphic = rings
	body.add_child(rings)
	# FIXME! Should cast shadows, but it doesn't...
#	prints(rings.cast_shadow, rings_material.flags_do_not_receive_shadows)
