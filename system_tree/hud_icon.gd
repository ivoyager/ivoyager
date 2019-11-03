# hud_icon.gd
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
	var icon_texture: Texture = FileHelper.find_resource(Global.hud_icons_dir, file_prefix)
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

