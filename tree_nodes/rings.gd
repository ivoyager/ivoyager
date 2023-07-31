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
extends MeshInstance3D

# Visual planetary rings that uses rings.gdshader. Not persisted so added by
# BodyFinisher.

var _body: IVBody
var _texture: Texture2D
var _main_light_source: Node3D # for phase-angle effects
var _rings_material := ShaderMaterial.new()

var _is_sun_above := false;


func _init(body: IVBody, texture: Texture2D, main_light_source: Node3D) -> void:
	_body = body
	_texture = texture
	_main_light_source = main_light_source


func _ready() -> void:
	var outer_radius: float = _body.get_rings_outer_radius()
	var inner_radius: float = _body.get_rings_inner_radius()
	var inner_fraction := inner_radius / outer_radius
	scale = Vector3(outer_radius, outer_radius, outer_radius)
	cast_shadow = SHADOW_CASTING_SETTING_ON # FIXME: No shadow!
	mesh = PlaneMesh.new()
	_rings_material.shader = IVGlobal.shared.rings_shader
	_rings_material.set_shader_parameter("rings_texture", _texture)
	_rings_material.set_shader_parameter("inner_fraction", inner_fraction)
	var width := float(_texture.get_width())
	_rings_material.set_shader_parameter("pixel_number", width)
	_rings_material.set_shader_parameter("pixel_size", 1.0 / width)
	set_surface_override_material(0, _rings_material)
	rotate_x(PI / 2.0)


func _process(_delta: float) -> void:
	var sun_global_translation := _main_light_source.global_position
	var is_sun_above := to_local(sun_global_translation).y > 0.0
	if _is_sun_above != is_sun_above:
		_is_sun_above = is_sun_above
		_rings_material.set_shader_parameter("is_sun_above", is_sun_above)
	# TODO4.0: Make below a global uniform.
	_rings_material.set_shader_parameter("sun_translation", sun_global_translation)
