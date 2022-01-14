# model_builder.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2022 Charlie Whitfield
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
class_name IVModelBuilder

# We have a lazy_init option and culling system to keep model number low at any
# given time. We cull based on staleness of last visibility change. Use it for
# minor moons, visited asteroids, spacecraft, etc. Project var max_lazy should
# be set to something larger than the max number of lazy models likely to be
# visible at a give time (however, a small value helps on low end systems).

const files := preload("res://ivoyager/static/files.gd")
const METER := IVUnits.METER

var max_lazy := 20
var model_too_far_radius_multiplier := 1e3
var model_tables := ["stars", "planets", "moons"]
var map_search_suffixes := [".albedo", ".emission"]
var star_grow_dist := 2.0 * IVUnits.AU # grow to stay visible at greater range
var star_grow_exponent := 0.6
var star_energy_ref_dist := 3.8e6 * IVUnits.KM # ~4x radius works
var star_energy_near := 10.0 # energy at _star_energy_ref_dist
var star_energy_exponent := 1.9
var material_fields := ["metallic", "roughness", "rim_enabled", "rim", "rim_tint"]

var _times: Array = IVGlobal.times
var _table_reader: IVTableReader
var _io_manager: IVIOManager
var _globe_mesh: SphereMesh
var _fallback_albedo_map: Texture
var _map_files := {}
var _model_files := {}
var _lazy_tracker := {}
var _n_lazy := 0
var _recycled_placeholders := [] # unmodified, un-treed Spatials


func _project_init() -> void:
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_clear")
	IVGlobal.connect("about_to_stop_before_quit", self, "_clear")
	_table_reader = IVGlobal.program.TableReader
	_io_manager = IVGlobal.program.IOManager
	_globe_mesh = IVGlobal.shared_resources.globe_mesh
	_fallback_albedo_map = IVGlobal.assets.fallback_albedo_map
	_preregister_files()


func add_model(body: IVBody, lazy_init: bool) -> void: # Main thread
	var file_prefix := body.get_file_prefix()
	var model_controller := body.model_controller
	var m_radius := body.get_mean_radius()
	var e_radius := body.get_equatorial_radius()
	body.max_model_dist = m_radius * model_too_far_radius_multiplier
	var model_basis := _get_model_basis(file_prefix, m_radius, e_radius)
	model_controller.set_model_reference_basis(model_basis)
	if lazy_init:
		_add_placeholder(body, model_controller)
		return
	var model_type := body.get_model_type()
	var array := [body, model_controller, file_prefix, model_type, model_basis]
	_io_manager.callback(self, "_get_model_on_io_thread", "_finish_model", array)


func _preregister_files() -> void:
	var models_search := IVGlobal.models_search
	var maps_search := IVGlobal.maps_search
	for table in model_tables:
		var n_rows := _table_reader.get_n_rows(table)
		var row := 0
		while row < n_rows:
			var file_prefix := _table_reader.get_string(table, "file_prefix", row)
			assert(file_prefix)
			var model_file := files.find_resource_file(models_search, file_prefix)
			if model_file:
				_model_files[file_prefix] = model_file
			for suffix in map_search_suffixes:
				var file_match := file_prefix + (suffix as String)
				var map_file := files.find_resource_file(maps_search, file_match)
				if map_file:
					_map_files[file_match] = map_file
			row += 1


func _clear() -> void:
	while _recycled_placeholders:
		_recycled_placeholders.pop_back().queue_free()
	_lazy_tracker.clear()
	_n_lazy = 0


func _add_placeholder(body: IVBody, model_controller: IVModelController) -> void: # Main thread
	var placeholder: Spatial
	if _recycled_placeholders:
		placeholder = _recycled_placeholders.pop_back()
	else:
		placeholder = Spatial.new()
	placeholder.hide()
	placeholder.connect("visibility_changed", self, "_lazy_init", [body], CONNECT_ONESHOT)
	model_controller.set_model(placeholder, false)
	body.add_child(placeholder)


func _lazy_init(body: IVBody) -> void: # Main thread
	var file_prefix := body.get_file_prefix()
	var model_type := body.get_model_type()
	var model_controller := body.model_controller
	var model_basis: Basis = model_controller.model_reference_basis
	var array := [body, model_controller, file_prefix, model_type, model_basis]
	_io_manager.callback(self, "_get_model_on_io_thread", "_finish_lazy_model", array)


func _get_model_on_io_thread(array: Array) -> void: # I/O thread
	var file_prefix: String = array[2]
	var model_basis: Basis = array[4]
	var model: Spatial
	var model_file: String = _model_files.get(file_prefix, "")
	if model_file:
		var packed_scene: PackedScene = load(model_file)
		model = packed_scene.instance()
		model.transform.basis = model_basis
		model.hide()
		array.append(model)
		return
	var model_type: int = array[3]
	# TODO: We need a fallback asteroid-like model for non-ellipsoid
	# fallthrough to constructed ellipsoid model
	var emission_map: Texture
	var map_file: String = _map_files.get(file_prefix + ".emission", "")
	if map_file:
		emission_map = load(map_file)
	var albedo_map: Texture
	map_file = _map_files.get(file_prefix + ".albedo", "")
	if map_file:
		albedo_map = load(map_file)
	if !albedo_map and !emission_map:
		albedo_map = _fallback_albedo_map
	model = MeshInstance.new()
	model.transform.basis = model_basis
	model.hide()
	array.append(model)
	model.mesh = _globe_mesh
	var surface := SpatialMaterial.new()
	model.set_surface_material(0, surface)
	_table_reader.build_object(surface, material_fields, "models", model_type)
	if albedo_map:
		surface.albedo_texture = albedo_map
	if emission_map:
		surface.emission_enabled = true
		surface.emission_texture = emission_map
	if _table_reader.get_bool("models", "starlight", model_type):
		model.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		array.append(surface) # dynamic star surface
	else:
		model.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON
		# FIXME! Should cast shadows, but it doesn't...!


func _finish_model(array: Array) -> void: # Main thread
	var body: IVBody = array[0]
	var model_controller: IVModelController = array[1]
	var model: Spatial = array[5]
	model_controller.set_model(model, false)
	if body.get_light_type() != -1: # is a star
		body.max_model_dist = INF
		if array.size() > 6: # has dynamic star surface
			var surface: SpatialMaterial = array[6]
			model_controller.set_dynamic_star(surface, star_grow_dist, star_grow_exponent,
					star_energy_ref_dist, star_energy_near, star_energy_exponent)
	body.add_child(model)


func _finish_lazy_model(array: Array) -> void: # Main thread
	var body: IVBody = array[0]
	var model_controller: IVModelController = array[1]
	var model: Spatial = array[5]
	var placeholder := model_controller.model
	body.remove_child(placeholder)
	_recycled_placeholders.append(placeholder)
	model.connect("visibility_changed", self, "_record_lazy_event", [model])
	model_controller.set_model(model, false)
	body.add_child(model)
	_n_lazy += 1
	if _n_lazy > max_lazy:
		_cull_lazy()
	_lazy_tracker[model] = _times[1] # engine time


func _cull_lazy() -> void: # Main thread
	# Cull models w/ last view earlier than average (easier than median)
	var time_cutoff := 0.0
	var tracker_keys := _lazy_tracker.keys()
	for model in tracker_keys:
		time_cutoff += _lazy_tracker[model]
	time_cutoff /= max_lazy
	for model in tracker_keys:
		if _lazy_tracker[model] < time_cutoff:
			_lazy_uninit(model)


func _lazy_uninit(model: Spatial) -> void: # Main thread
	if model.visible:
		return
	# swap back to a placeholder again
	model.disconnect("visibility_changed", self, "_record_lazy_event")
	_lazy_tracker.erase(model)
	_n_lazy -= 1
	var body: IVBody = model.get_parent_spatial()
	var model_controller := body.model_controller
	_add_placeholder(body, model_controller)
	model.queue_free() # it's now up to the Engine what to cache!


func _record_lazy_event(model: Spatial) -> void: # Main thread
	_lazy_tracker[model] = _times[1] # engine time


func _get_model_basis(file_prefix: String, m_radius := NAN, e_radius := NAN) -> Basis:
	# radii used only for ellipsoid
	var basis := Basis()
	var model_file: String = _model_files.get(file_prefix, "")
	if model_file:
		var model_scale := NAN
		var asset_row := _table_reader.get_row("asset_adjustments", model_file.get_file())
#		prints(file_prefix, asset_row, model_file)
		if asset_row != -1:
			model_scale = _table_reader.get_real("asset_adjustments", "model_scale", asset_row)
#			prints(file_prefix, model_scale)
		if !is_nan(model_scale):
			basis = basis.scaled(model_scale * Vector3.ONE)
#			prints(file_prefix, basis.scaled(1e12 * Vector3.ONE))
		else:
			basis = basis.scaled(METER * Vector3.ONE)
	else: # constructed ellipsoid model
		assert(!is_nan(m_radius) and !is_inf(m_radius))
		if !is_nan(e_radius) and !is_inf(e_radius):
			var polar_radius: = 3.0 * m_radius - 2.0 * e_radius
			basis = basis.scaled(Vector3(e_radius, polar_radius, e_radius))
		else:
			basis = basis.scaled(m_radius * Vector3.ONE)
		# map rotation - we only look for *.albedo file
		var map_file: String = _map_files.get(file_prefix + ".albedo", "")
		if map_file:
			var asset_row := _table_reader.get_row("asset_adjustments", map_file.get_file())
			if asset_row != -1:
				var longitude_offset := _table_reader.get_real("asset_adjustments",
						"longitude_offset", asset_row)
				if !is_nan(longitude_offset):
					basis = basis.rotated(Vector3(0.0, 1.0, 0.0), -longitude_offset)
	basis = basis.rotated(Vector3(0.0, 1.0, 0.0), -PI / 2.0) # adjust for centered prime meridian
	basis = basis.rotated(Vector3(1.0, 0.0, 0.0), PI / 2.0) # z-up in astronomy!
	return basis
