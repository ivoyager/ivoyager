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

const MODEL_TOO_FAR_RADIUS_MULTIPLIER := 1e3
const METER := UnitDefs.METER

enum {
	ASSET_MODEL,
	ASSET_MAP,
}

# project vars
var max_lazy := 20
var star_grow_dist := 2.0 * UnitDefs.AU # grow to stay visible at greater range
var star_grow_exponent := 0.6
var star_energy_ref_dist := 3.8e6 * UnitDefs.KM # ~4x radius works
var star_energy_near := 10.0 # energy at _star_energy_ref_dist
var star_energy_exponent := 1.9

# private
var _times: Array = Global.times
var _models_search := Global.models_search
var _maps_search := Global.maps_search
var _globe_mesh: SphereMesh
var _table_reader: TableReader
var _fallback_albedo_map: Texture
var _memoized_and_preloaded := {}
var _lazy_tracker := {}
var _n_lazy := 0
var _material_fields := {
	metallic = "metallic",
	roughness = "roughness",
	rim_enabled = "rim_enabled",
	rim = "rim",
	rim_tint = "rim_tint",
}

func project_init() -> void:
	Global.connect("about_to_free_procedural_nodes", self, "_clear_procedural")
	_globe_mesh = Global.shared_resources.globe_mesh
	_table_reader = Global.program.TableReader
	_fallback_albedo_map = Global.assets.fallback_albedo_map

func add_model(body: Body, lazy_init: bool) -> void:
	var properties := body.properties
	var model_geometry := body.model_geometry
	var file_prefix: String = body.file_info[0]
	var model: Spatial
	if lazy_init:
		# make a simple Spatial placeholder
		model = get_model_or_placeholder(body.model_type, file_prefix, properties.m_radius,
				properties.e_radius, true)
		model.hide()
		model.connect("visibility_changed", self, "_lazy_init", [body], CONNECT_ONESHOT)
	else:
		model = get_model_or_placeholder(body.model_type, file_prefix, properties.m_radius,
				properties.e_radius)
		model.hide()
	model_geometry.set_model(model)
	if body.light_type == -1:
		body.model_too_far = properties.m_radius * MODEL_TOO_FAR_RADIUS_MULTIPLIER
	else:
		body.model_too_far = INF
		var star_surface := _get_star_surface(file_prefix)
		if star_surface:
			model_geometry.set_dynamic_star(star_surface, star_grow_dist,
					star_grow_exponent, star_energy_ref_dist,
					star_energy_near, star_energy_exponent)
	body.add_child(model)

func get_model_or_placeholder(model_type: int, file_prefix: String, m_radius: float,
		 e_radius: float, is_placeholder := false) -> Spatial:
	# Radii used only for ellipsoid.
	# We need correct scale and rotation even if it is a placeholder Spatial!
	var model: Spatial
	var resource_file := _get_resource_file(file_prefix, _models_search)
	var is_ellipsoid: bool = _table_reader.get_bool("models", "ellipsoid", model_type)
	if !resource_file and !is_ellipsoid:
		# TODO: fallback_model for non-ellipsoid (for now, we fallthrough to ellipsoid)
		pass
	if resource_file:
		var resource: Resource = _get_resource(file_prefix, _models_search)
		if resource is PackedScene:
			if is_placeholder:
				model = Spatial.new()
			else:
				model = resource.instance() # model is the base of a scene
		# TODO: models that are not PackedScene???
		var file_name := resource_file.get_file()
		_set_model_scale(model, file_name)
		_set_rotations(model, file_name)
		return model
		
	# fallthrough to ellipsoid model using the common Global.globe_mesh
	assert(m_radius > 0.0)
	var albedo_map_file: String = _get_resource_file(file_prefix + ".albedo", _maps_search)
	var albedo_map: Texture = _get_resource(file_prefix + ".albedo", _maps_search)
	var emission_map: Texture = _get_resource(file_prefix + ".emission", _maps_search)
	if is_placeholder:
		model = Spatial.new()
	else:
		model = MeshInstance.new() # this is the return Spatial
		model.mesh = _globe_mesh
		var surface := SpatialMaterial.new()
		model.set_surface_material(0, surface)
		if !albedo_map and !emission_map:
			albedo_map = _fallback_albedo_map
		_table_reader.build_object(surface, "models", model_type, _material_fields)
		if albedo_map:
			surface.albedo_texture = albedo_map
		if emission_map:
			surface.emission_enabled = true
			surface.emission_texture = emission_map
		if _table_reader.get_bool("models", "starlight", model_type):
			model.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
			_save_star_surface(file_prefix, surface)
		else:
			model.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON
			# FIXME! Should cast shadows, but it doesn't...!
	var file_name := albedo_map_file.get_file()
	_set_ellipsoid_scale(model, m_radius, e_radius)
	_set_rotations(model, file_name)
	return model

func _set_model_scale(model: Spatial, file_name: String) -> void:
	var asset_row := _table_reader.get_row("asset_adjustments", file_name)
	if asset_row != -1 and _table_reader.has_value("asset_adjustments", "model_scale", asset_row):
		var model_scale := _table_reader.get_real("asset_adjustments", "model_scale", asset_row)
		model.scale = model_scale * Vector3.ONE
	else:
		model.scale = METER * Vector3.ONE

func _set_ellipsoid_scale(model: Spatial, m_radius := -INF, e_radius := -INF) -> void:
	if !is_inf(e_radius):
		var polar_radius: = 3.0 * m_radius - 2.0 * e_radius
		model.scale = Vector3(e_radius, polar_radius, e_radius)
	else:
		model.scale = m_radius * Vector3.ONE

func _set_rotations(model: Spatial, file_name: String) -> void:
	var asset_row := _table_reader.get_row("asset_adjustments", file_name)
	if asset_row != -1:
		var longitude_offset := _table_reader.get_real("asset_adjustments",
				"longitude_offset", asset_row)
		if longitude_offset != -INF:
			model.rotate(Vector3(0.0, 1.0, 0.0), -longitude_offset)
	model.rotate(Vector3(0.0, 1.0, 0.0), PI) # adjust for centered prime meridian
	model.rotate(Vector3(1.0, 0.0, 0.0), PI / 2.0) # z-up in astronomy!

func _clear_procedural() -> void:
	_memoized_and_preloaded.clear()
	_lazy_tracker.clear()
	_n_lazy = 0

func _lazy_init(body: Body) -> void:
	var properties := body.properties
	var model_geometry := body.model_geometry
	var placeholder := model_geometry.model
	assert(placeholder.visible)
	placeholder.queue_free()
	var file_prefix: String = body.file_info[0]
	var model := get_model_or_placeholder(body.model_type, file_prefix, properties.m_radius, properties.e_radius)
	model.connect("visibility_changed", self, "_update_lazy", [model])
	model_geometry.replace_model(model)
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
	var model_geometry := body.model_geometry
	var placeholder := Spatial.new()
	placeholder.hide()
	placeholder.connect("visibility_changed", self, "_lazy_init", [body], CONNECT_ONESHOT)
	model_geometry.replace_model(placeholder)
	body.add_child(placeholder)
	model.queue_free()

func _update_lazy(model: Spatial) -> void:
	_lazy_tracker[model] = _times[1] # engine time

func _cull_lazy() -> void:
	# we cull for < average update time (quicker than median)
	var update_cutoff := 0.0
	var tracker_keys := _lazy_tracker.keys()
	for model in tracker_keys:
		update_cutoff += _lazy_tracker[model]
	update_cutoff /= max_lazy
	for model in tracker_keys:
		if _lazy_tracker[model] < update_cutoff:
			_lazy_uninit(model)

func _get_resource_file(file_prefix: String, dir_paths: Array) -> String:
	# memoized & preloaded to prevent file searching and loading at runtime
	if _memoized_and_preloaded.has(file_prefix):
		return _memoized_and_preloaded[file_prefix]
	var file_str: String = file_utils.find_resource_file(dir_paths, file_prefix)
	_memoized_and_preloaded[file_prefix] = file_str # could be ""
	if file_str:
		_memoized_and_preloaded[file_str] = load(file_str)
	return file_str

func _get_resource(file_prefix: String, dir_paths: Array) -> Resource:
	var file_str := _get_resource_file(file_prefix, dir_paths)
	if file_str:
		return _memoized_and_preloaded[file_str]
	return null

func _save_star_surface(file_prefix: String, surface: SpatialMaterial) -> void:
	_memoized_and_preloaded[file_prefix + "*"] = surface

func _get_star_surface(file_prefix: String) -> SpatialMaterial:
	if _memoized_and_preloaded.has(file_prefix + "*"):
		return _memoized_and_preloaded[file_prefix + "*"]
	return null
