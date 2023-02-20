# rings.gd
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
class_name IVRings
extends MeshInstance

# Visual planetary rings. Not persisted so added by BodyFinisher.
#
# TODO: A shader rings would be visually superior. 
# See: https://bjj.mmedia.is/data/s_rings

var _body: IVBody
var _texture: Texture
var _rings_material := ShaderMaterial.new()


func _init(body: IVBody, texture: Texture) -> void:
	_body = body
	_texture = texture


func _ready() -> void:
	var outer_radius: float = _body.get_rings_outer_radius()
	var inner_radius: float = _body.get_rings_inner_radius()
	var inner_fraction := inner_radius / outer_radius
	scale = Vector3(outer_radius, outer_radius, outer_radius)

	cast_shadow = SHADOW_CASTING_SETTING_ON # FIXME: No shadow!
	mesh = PlaneMesh.new()
	
	_rings_material.shader = IVGlobal.shared.rings_shader
	_rings_material.set_shader_param("ring_texture", _texture)
	_rings_material.set_shader_param("inner_fraction", inner_fraction)
	set_surface_material(0, _rings_material)
	rotate_x(PI / 2.0)


func _process(_delta: float) -> void:
	var sun := get_parent_spatial().get_parent_spatial().get_parent_spatial()
	var sun_global_translation := sun.global_translation
	var is_sun_above := to_local(sun_global_translation).y > 0.0
	_rings_material.set_shader_param("is_sun_above", is_sun_above)
	_rings_material.set_shader_param("sun_translation", sun_global_translation)


