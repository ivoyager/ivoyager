# model.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2020 Charlie Whitfield
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

extends Spatial
class_name Model

const file_utils := preload("res://ivoyager/static/file_utils.gd")
const unit_defs := preload("res://ivoyager/static/unit_defs.gd")

const TOO_FAR_RADIUS_MULTIPLIER := 1e3

var is_ellipsoidal: bool # if so, shape defined by m_radius & e_radius only
var mesh_instance: MeshInstance
var surface: SpatialMaterial

func init(body_type: int, file_prefix: String, m_radius := 0.0, e_radius := 0.0) -> void:
	# m_radius & e_radius used only for ellipsoidal.
	# model_scale used for non-ellipsoidal; default 1.0 assumes model in km.
	var data: Dictionary = Global.tables.body_data[body_type]
	is_ellipsoidal = data.ellipsoidal
	if is_ellipsoidal:
		assert(m_radius > 0.0 and e_radius > 0.0)
		var polar_radius = 3.0 * m_radius - 2.0 * e_radius
		mesh_instance = MeshInstance.new()
		mesh_instance.scale = Vector3(e_radius, polar_radius, e_radius)
		mesh_instance.mesh = Global.globe_mesh
		var globe_wraps_dir: String = Global.asset_paths.globe_wraps_dir
		var albedo_texture: Texture = file_utils.find_resource(globe_wraps_dir, file_prefix + ".albedo")
		if !albedo_texture:
			albedo_texture = Global.assets.fallback_globe_wrap
		surface = SpatialMaterial.new()
		mesh_instance.set_surface_material(0, surface)
		surface.albedo_texture = albedo_texture
		surface.metallic = data.metallic
		surface.roughness = data.roughness
		surface.rim_enabled = data.rim_enabled
		surface.rim = data.rim
		surface.rim_tint = data.rim_tint
		surface.flags_unshaded = data.unshaded
		mesh_instance.cast_shadow = MeshInstance.SHADOW_CASTING_SETTING_ON if data.shadow \
				else MeshInstance.SHADOW_CASTING_SETTING_OFF
		add_child(mesh_instance)
	else:
		var models_dir: String = Global.asset_paths.models_dir
		var resource_file := file_utils.find_resource_file(models_dir, file_prefix)
		if !resource_file:
			resource_file = Global.asset_paths.fallback_model
		var resource: Resource = load(resource_file)
		var model_scale := file_utils.get_scale_from_file_path(resource_file)
		if resource is PackedScene:
			var model_spatial: Spatial = resource.instance()
			model_spatial.scale = Vector3.ONE * model_scale * unit_defs.KM
			add_child(model_spatial)
		# TODO: could we save resources by importing mesh without scene?...
#		elif resource is ArrayMesh:
#			var model_spatial := MeshInstance.new()
#			model_spatial.mesh = resource
#			model_spatial.scale = Vector3.ONE * model_scale * Global.scale
#			add_child(model_spatial)	
	hide()
