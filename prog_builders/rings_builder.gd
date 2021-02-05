# rings_builder.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# "I, Voyager" is a registered trademark of Charlie Whitfield
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
# TODO: We need a rings shader! What we have now is a QuadMesh & Texture.

class_name RingsBuilder

const math := preload("res://ivoyager/static/math.gd") # =Math when issue #37529 fixed
const file_utils := preload("res://ivoyager/static/file_utils.gd")

const RINGS_TOO_FAR_RADIUS_MULTIPLIER := 2e3
const METER := UnitDefs.METER

var _rings_search: Array = Global.rings_search

func project_init() -> void:
	pass

func add_rings(body: Body) -> void:
	var rings_file: String = body.file_info[2] + "_temp"
	var radius: float = body.file_info[3]
	var texture: Texture = file_utils.find_and_load_resource(_rings_search, rings_file)
	assert(texture, "Could not find rings texture (no fallback!)")
	var rings := MeshInstance.new()
	var rings_material := SpatialMaterial.new()
	rings_material.albedo_texture = texture
	rings_material.flags_transparent = true
	rings_material.params_cull_mode = SpatialMaterial.CULL_DISABLED
	rings_material.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
	rings.scale = Vector3(radius * 2.0, radius * 2.0, 1.0)
	var basis := math.rotate_basis_z(rings.transform.basis, body.model_geometry.north_pole)
	rings.transform.basis = basis
	rings.cast_shadow = MeshInstance.SHADOW_CASTING_SETTING_ON
	rings.mesh = QuadMesh.new()
	rings.set_surface_material(0, rings_material)
	rings.hide()
	# modify body
	body.aux_graphic = rings
	body.aux_graphic_too_far = radius * RINGS_TOO_FAR_RADIUS_MULTIPLIER
	body.add_child(rings)
	# FIXME! Should cast shadows, but it doesn't...
#	prints(rings.cast_shadow, rings_material.flags_do_not_receive_shadows)
