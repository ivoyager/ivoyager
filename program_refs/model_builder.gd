# model_builder.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
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

class_name ModelBuilder

const file_utils := preload("res://ivoyager/static/file_utils.gd")

const DEBUG_NO_3D_MODELS := false
const MODEL_TOO_FAR_RADIUS_MULTIPLIER := 1e3
const METER := UnitDefs.METER

var _table_data: Dictionary = Global.table_data
var _table_fields: Dictionary = Global.table_fields
var _globe_mesh: SphereMesh = Global.globe_mesh
var _globe_wraps_dir: String
var _fallback_globe_wrap: Texture

func project_init() -> void:
	_globe_wraps_dir = Global.asset_paths.globe_wraps_dir
	_fallback_globe_wrap = Global.assets.fallback_globe_wrap
	
func add_model(body: Body) -> void:
	var model: Spatial
	var model_type := body.model_type
	var file_prefix := body.file_prefix
	var row_data: Array = _table_data.models[model_type]
	var fields: Dictionary = _table_fields.models
	var is_ellipsoid: bool = row_data[fields.ellipsoid]
	if !is_ellipsoid and !DEBUG_NO_3D_MODELS:
		# For imported (non-ellipsoid) models, scale is derived from file
		# name: e.g., "*_1_1000.*" is understood to be in length units of 1000
		# meters. Absence of scale suffix indicates units of 1 meter.
		var models_dir: String = Global.asset_paths.models_dir
		var resource_file := file_utils.find_resource_file(models_dir, file_prefix)
#		if !resource_file:
#			resource_file = Global.asset_paths.fallback_model
			# TODO: We don't have a fallback_model yet, so fallthrough to ellipsoid...
		if resource_file:
			var resource: Resource = load(resource_file)
			var per_meter_scale := file_utils.get_scale_from_file_path(resource_file)
			if resource is PackedScene:
				model = resource.instance() # model is the base of a scene
				model.scale = Vector3.ONE * METER / per_meter_scale
				model.rotate(Vector3(1.0, 0.0, 0.0), PI / 2.0) # z-up in astronomy!
			# elif ?:
			# TODO: could we save resources by importing mesh without scene?...
	if !model:
		# fallback to ellipsoid model using the common Global.globe_mesh
		var m_radius := body.m_radius
		var e_radius := body.e_radius
		assert(m_radius > 0.0 and e_radius > 0.0)
		var polar_radius = 3.0 * m_radius - 2.0 * e_radius
		model = MeshInstance.new() # this is the return Spatial
		model.scale = Vector3(e_radius, polar_radius, e_radius)
		model.rotate(Vector3(1.0, 0.0, 0.0), PI / 2.0) # z-up in astronomy!
		model.mesh = _globe_mesh
		var albedo_texture: Texture = file_utils.find_resource(_globe_wraps_dir,
				file_prefix + ".albedo")
		if !albedo_texture:
			albedo_texture = _fallback_globe_wrap
		var surface := SpatialMaterial.new()
		model.set_surface_material(0, surface)
		surface.albedo_texture = albedo_texture
		surface.metallic = row_data[fields.metallic]
		surface.roughness = row_data[fields.roughness]
		surface.rim_enabled = row_data[fields.rim_enabled]
		surface.rim = row_data[fields.rim]
		surface.rim_tint = row_data[fields.rim_tint]
		surface.flags_unshaded = row_data[fields.unshaded]
		if row_data[fields.shadow]:
			model.cast_shadow = MeshInstance.SHADOW_CASTING_SETTING_ON
		else:
			model.cast_shadow = MeshInstance.SHADOW_CASTING_SETTING_OFF
	model.hide()
	# modify body
	body.model = model
	body.model_too_far = body.m_radius * MODEL_TOO_FAR_RADIUS_MULTIPLIER
	body.model_basis = body.reference_basis * model.transform.basis
	body.add_child(model)
