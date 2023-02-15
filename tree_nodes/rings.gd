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


func _init(body: IVBody, texture: Texture) -> void:
	_body = body
	_texture = texture


func _ready() -> void:
	var radius: float = _body.get_rings_radius()
	scale = Vector3(radius * 2.0, radius * 2.0, 1.0)
	cast_shadow = SHADOW_CASTING_SETTING_ON # FIXME: No shadow!
	mesh = QuadMesh.new()
	var rings_material := SpatialMaterial.new()
	rings_material.albedo_texture = _texture
	rings_material.flags_transparent = true
	rings_material.params_cull_mode = SpatialMaterial.CULL_DISABLED # both sides visible
	rings_material.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
	set_surface_material(0, rings_material)


