# hud_icon.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2019 Charlie Whitfield
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
class_name HUDIcon

const ICON_TRANSFORM = Transform(Vector3(100, 0, 0),
	Vector3(0, 100, 0),
	Vector3(0, 0, 100),
	Vector3(0, 0, 0)
)

# private
var _icon_quad_mesh: QuadMesh # mesh shared by all icons
var _icon_material := SpatialMaterial.new()

func init(file_prefix: String, fallback_icon_texture: Texture) -> void:
	_icon_quad_mesh = Global.icon_quad_mesh
	var icon_texture: Texture = FileHelper.find_resource(Global.asset_paths.hud_icons_dir, file_prefix)
	if !icon_texture:
		icon_texture = fallback_icon_texture
	_icon_material.albedo_texture = icon_texture
	_icon_material.flags_transparent = true
	_icon_material.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
	_icon_material.flags_unshaded = true
	_icon_material.flags_fixed_size = true
	_icon_material.flags_albedo_tex_force_srgb = true
	_icon_material.params_billboard_mode = SpatialMaterial.BILLBOARD_ENABLED
	hide()

func _ready():
	_on_ready()

func _on_ready():
	transform = ICON_TRANSFORM
	mesh = _icon_quad_mesh
	material_override = _icon_material

