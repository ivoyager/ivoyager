# model.gd
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
		var globe_wraps_dir: String = Global.asset_paths.globe_wraps_dir
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
