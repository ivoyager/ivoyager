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
# We have a lazy_init option and culling system to keep model number low at any
# given time. We cull based on staleness of last visibility change. Use it for
# minor moons, visited asteroids, spacecraft, etc. Project var max_lazy should
# be set to something larger than the max number of lazy models likely to be
# visible at a give time (however, a small value REALLY HELPS A LOT on low end
# systems).

class_name ModelBuilder

const file_utils := preload("res://ivoyager/static/file_utils.gd")

const DEBUG_NO_3D_MODELS := false
const MODEL_TOO_FAR_RADIUS_MULTIPLIER := 1e3
const METER := UnitDefs.METER

# project var
var max_lazy := 20

# private
var _times: Array = Global.times
var _globe_mesh: SphereMesh = Global.globe_mesh
var _table_helper: TableHelper
var _globe_wraps_dir: String
var _models_dir: String
var _fallback_globe_wrap: Texture
var _memoized := {}
var _lazy_tracker := {}
var _n_lazy := 0
var _material_fields := {
	metallic = "metallic",
	roughness = "roughness",
	rim_enabled = "rim_enabled",
	rim = "rim",
	rim_tint = "rim_tint",
	flags_unshaded = "unshaded",
}


func project_init() -> void:
	Global.connect("about_to_free_procedural_nodes", self, "_clear_procedural")
	_table_helper = Global.program.TableHelper
	_globe_wraps_dir = Global.asset_paths.globe_wraps_dir
	_models_dir = Global.asset_paths.models_dir
	_fallback_globe_wrap = Global.assets.fallback_globe_wrap

func add_model(body: Body, lazy_init: bool) -> void:
	var model: Spatial
	if lazy_init:
		# make a simple Spatial placeholder
		model = get_model(body.model_type, body.file_prefix, body.properties.m_radius,
				body.properties.e_radius, true)
		model.hide()
		model.connect("visibility_changed", self, "_lazy_init", [body], CONNECT_ONESHOT)
	else:
		model = get_model(body.model_type, body.file_prefix, body.properties.m_radius,
				body.properties.e_radius)
		model.hide()
	body.model = model
	body.model_too_far = body.properties.m_radius * MODEL_TOO_FAR_RADIUS_MULTIPLIER
	body.model_basis = body.reference_basis * model.transform.basis
	body.add_child(model)

func get_model(model_type: int, file_prefix: String, m_radius: float, e_radius: float,
		is_placeholder := false) -> Spatial:
	# radii used only for ellipsoid
	var model: Spatial
	var is_ellipsoid: bool = _table_helper.get_bool("models", "ellipsoid", model_type)
	if !is_ellipsoid and !DEBUG_NO_3D_MODELS:
		# For imported (non-ellipsoid) models, scale is derived from file
		# name: e.g., "*_1_1000.*" is understood to be in length units of 1000
		# meters. Absence of scale suffix indicates units of 1 meter.
		var resource_file := _find_and_load_resource_file(_models_dir, file_prefix)
		# TODO: fallback_model (for now, we fallthrough to ellipsoid)
		if resource_file:
			var resource: Resource = _memoized[resource_file]
			if resource is PackedScene:
				if is_placeholder:
					model = Spatial.new()
				else:
					model = resource.instance() # model is the base of a scene
				var per_meter_scale := file_utils.get_scale_from_file_path(resource_file)
				model.scale = Vector3.ONE * METER / per_meter_scale
				model.rotate(Vector3(1.0, 0.0, 0.0), PI / 2.0) # z-up in astronomy!
			# TODO: models that are not PackedScene???
	if !model:
		# fallback to ellipsoid model using the common Global.globe_mesh
		assert(m_radius > 0.0)
#		if is_inf(e_radius):
#			e_radius = m_radius
		var albedo_texture: Texture = _find_resource(_globe_wraps_dir, file_prefix + ".albedo")
		if is_placeholder:
			model = Spatial.new()
		else:
			model = MeshInstance.new() # this is the return Spatial
			model.mesh = _globe_mesh
			var surface := SpatialMaterial.new()
			model.set_surface_material(0, surface)
			if !albedo_texture:
				albedo_texture = _fallback_globe_wrap
			surface.albedo_texture = albedo_texture
			_table_helper.build_object(surface, "models", model_type, _material_fields)
			if _table_helper.get_bool("models", "shadow", model_type):
				model.cast_shadow = MeshInstance.SHADOW_CASTING_SETTING_ON
			else:
				model.cast_shadow = MeshInstance.SHADOW_CASTING_SETTING_OFF
		if !is_inf(e_radius):
			var polar_radius: = 3.0 * m_radius - 2.0 * e_radius
			model.scale = Vector3(e_radius, polar_radius, e_radius)
		else:
			model.scale = Vector3(m_radius, m_radius, m_radius)
		model.rotate(Vector3(1.0, 0.0, 0.0), PI / 2.0) # z-up in astronomy!
	return model

func _clear_procedural() -> void:
	# we keep _memoized since the file system won't change
	_lazy_tracker.clear()
	_n_lazy = 0

func _lazy_init(body: Body) -> void:
	var placeholder := body.model
	assert(placeholder.visible)
	placeholder.queue_free()
	var model := get_model(body.model_type, body.file_prefix, body.properties.m_radius,
		body.properties.e_radius)
	model.connect("visibility_changed", self, "_update_lazy", [model])
	body.model = model
	body.add_child(model)
	_n_lazy += 1
	if _n_lazy > max_lazy:
		_cull_lazy()
	_lazy_tracker[model] = _times[1] # engine time

func _lazy_uninit(model: Spatial) -> void:
	if model.visible:
		return
	# swap back to a placeholder again
	model.disconnect("visibility_changed", self, "_update_lazy")
	_lazy_tracker.erase(model)
	_n_lazy -= 1
	var body: Body = model.get_parent_spatial()
	var placeholder := Spatial.new()
	placeholder.hide()
	placeholder.connect("visibility_changed", self, "_lazy_init", [body], CONNECT_ONESHOT)
	body.model = placeholder
	body.add_child(placeholder)
	model.queue_free()

func _update_lazy(model: Spatial) -> void:
	_lazy_tracker[model] = _times[1] # engine time

func _cull_lazy() -> void:
	# we cull for below average update time; someone's gotta be below average!
	var update_cutoff := 0.0
	var tracker_keys := _lazy_tracker.keys()
	for model in tracker_keys:
		update_cutoff += _lazy_tracker[model]
	update_cutoff /= max_lazy
	for model in tracker_keys:
		if _lazy_tracker[model] < update_cutoff:
			_lazy_uninit(model)

# below memoized to prevent file searching and loading at runtime...
func _find_resource(dir_path: String, file_prefix: String) -> Resource:
	var key := dir_path + file_prefix
	if _memoized.has(key):
		return _memoized[key]
	var resource: Resource = file_utils.find_resource(dir_path, file_prefix)
	_memoized[key] = resource # could be null
	return resource

func _find_and_load_resource_file(dir_path: String, file_prefix: String) -> String:
	var key := dir_path + file_prefix
	if _memoized.has(key):
		return _memoized[key]
	var file_str: String = file_utils.find_resource_file(dir_path, file_prefix)
	_memoized[key] = file_str # could be ""
	if file_str:
		_memoized[file_str] = load(file_str)
	return file_str

