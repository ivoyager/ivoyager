# model.gd
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
# TODO: body_type characteristic from external data table

extends MeshInstance
class_name Model

const TOO_FAR_RADIUS_MULTIPLIER := 1e3

var is_spheroid: bool # if so, shape defined by m_radius & e_radius only
var surface := SpatialMaterial.new()

func init(body_type: int, file_prefix: String) -> void:
	var data: Dictionary = Global.table_data.body_data[body_type]
	is_spheroid = data.spheroid
	if is_spheroid:
		mesh = Global.globe_mesh
		var globe_wraps_dir: String = Global.globe_wraps_dir
		var albedo_texture: Texture = FileHelper.find_resource(globe_wraps_dir, file_prefix + ".albedo")
		if !albedo_texture:
			albedo_texture = Global.assets.fallback_globe_wrap
		surface.albedo_texture = albedo_texture
	else: # TODO: Model import
		assert(false)
	surface.metallic = data.metallic
	surface.roughness = data.roughness
	surface.rim_enabled = data.rim_enabled
	surface.rim = data.rim
	surface.rim_tint = data.rim_tint
	surface.flags_unshaded = data.unshaded
	cast_shadow = SHADOW_CASTING_SETTING_ON if data.shadow else SHADOW_CASTING_SETTING_OFF
	set_surface_material(0, surface)
	hide()
