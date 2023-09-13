# model_manager.gd
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
class_name IVModelManager
extends RefCounted

# We have a lazy_init option and culling system to keep model number low at any
# given time. We cull based on staleness of last visibility change. Use it for
# minor moons, visited asteroids, spacecraft, etc. Set project var
# 'max_lazy_models' to something larger than the max number of lazy models
# likely to be visible at a give time.

const files := preload("res://ivoyager/static/files.gd")

const DPRINT := false
const CULL_FRACTION := 0.3
const METER := IVUnits.METER

var max_lazy_models := 40
var model_too_far_radius_multiplier := 3e3
var map_search_suffixes: Array[String] = [".albedo", ".emission"]

var _times: Array = IVGlobal.times
var _SpheroidModel_: Script
var _io_manager: IVIOManager
var _fallback_albedo_map: Texture2D
var _map_paths := {}
var _model_paths := {}
var _lazy_tracker := {}
var _cull_times := []
var _cull_models := []
var _cull_size: int


func _project_init() -> void:
	IVGlobal.about_to_free_procedural_nodes.connect(_clear)
	IVGlobal.about_to_stop_before_quit.connect(_clear)
	_SpheroidModel_ = IVGlobal.script_classes._SpheroidModel_
	_io_manager = IVGlobal.program.IOManager
	_fallback_albedo_map = IVGlobal.assets.fallback_albedo_map
	_cull_size = int(max_lazy_models * CULL_FRACTION)
	_preregister_files()


func _clear() -> void:
	_lazy_tracker.clear()


func add_model(body: IVBody, lazy_init: bool) -> void: # Main thread
	var file_prefix := body.get_file_prefix()
	var m_radius := body.get_mean_radius()
	var e_radius := body.get_equatorial_radius()
	var model_basis := _get_model_basis(file_prefix, m_radius, e_radius)
	var max_dist: float
	if body.has_omni_light():
		max_dist = INF
	else:
		max_dist = m_radius * model_too_far_radius_multiplier
	body.set_model_parameters(model_basis, max_dist) # keep w/ Body for lazy init case
	if lazy_init:
		assert(!body.model_visible) # Body hasn't processed yet, so has init false
		body.model_visibility_changed.connect(_add_lazy_model.bind(body), CONNECT_ONE_SHOT)
		return
	var model_type := body.get_model_type()
	var array := [body, file_prefix, model_type, model_basis]
	_io_manager.callback(self, "_get_model_on_io_thread", "_finish_model", array)


func _add_lazy_model(is_visible: bool, body: IVBody) -> void: # Main thread
	assert(!DPRINT or IVDebug.dprint("ADD lazy model ", tr(body.name)))
	assert(is_visible)
	var file_prefix := body.get_file_prefix()
	var model_type := body.get_model_type()
	var model_basis := body.model_reference_basis
	var array := [body, file_prefix, model_type, model_basis]
	_io_manager.callback(self, "_get_model_on_io_thread", "_finish_lazy_model", array)


func _remove_lazy_model(model: Node3D) -> void: # Main thread
	var body: IVBody = model.get_parent().get_parent()
	assert(!DPRINT or IVDebug.dprint("REMOVE lazy model ", tr(body.name)))
	body.model_visibility_changed.disconnect(model.set_visible)
	body.model_visibility_changed.disconnect(_record_visibility_event)
	body.model_visibility_changed.connect(_add_lazy_model.bind(body), CONNECT_ONE_SHOT)
	body.remove_child_from_model_space(model)
	model.queue_free() # it's now up to the Engine what to cache!
	_lazy_tracker.erase(model)


func _get_model_on_io_thread(array: Array) -> void: # I/O thread
	var file_prefix: String = array[1]
	var model_basis: Basis = array[3]
	var model: Node3D
	var path: String = _model_paths.get(file_prefix, "")
	if path:
		# existing model overrides model_type table data
		var packed_scene: PackedScene = load(path)
		model = packed_scene.instantiate()
		model.transform.basis = model_basis
		array[1] = model
		return
	var model_type: int = array[2]
	# TODO: We need a fallback asteroid-like model for non-ellipsoid
	# fallthrough to constructed ellipsoid model
	var emission_map: Texture2D
	path = _map_paths.get(file_prefix + ".emission", "")
	if path:
		emission_map = load(path)
	var albedo_map: Texture2D
	path = _map_paths.get(file_prefix + ".albedo", "")
	if path:
		albedo_map = load(path)
	if !albedo_map and !emission_map:
		albedo_map = _fallback_albedo_map
	@warning_ignore("unsafe_method_access") # Possible replacement class
	model = _SpheroidModel_.new(model_type, model_basis, albedo_map, emission_map)
	array[1] = model


func _finish_model(array: Array) -> void: # Main thread
	var body: IVBody = array[0]
	var model: Node3D = array[1]
	body.add_child_to_model_space(model)
	model.visible = body.model_visible
	body.model_visibility_changed.connect(model.set_visible)


func _finish_lazy_model(array: Array) -> void: # Main thread
	var body: IVBody = array[0]
	var model: Node3D = array[1]
	body.add_child_to_model_space(model)
	model.visible = body.model_visible
	body.model_visibility_changed.connect(model.set_visible)
	body.model_visibility_changed.connect(_record_visibility_event.bind(model))
	if _lazy_tracker.size() > max_lazy_models:
		_cull_lazy_models()
	_lazy_tracker[model] = _times[1] # engine time


func _cull_lazy_models() -> void: # Main thread
	# Cull the most stale models up to '_cull_size'. Don't cull visible.
	for model in _lazy_tracker:
		if model.visible:
			continue
		var time: float = _lazy_tracker[model]
		var index := _cull_times.bsearch(time, false)
		if index < _cull_size:
			_cull_times.insert(index, time)
			_cull_models.insert(index, model)
			if _cull_times.size() > _cull_size:
				_cull_times.pop_back()
				_cull_models.pop_back()
	assert(!DPRINT or IVDebug.dprint("CULL ", _cull_times))
	for model in _cull_models:
		_remove_lazy_model(model)
	_cull_times.clear()
	_cull_models.clear()


func _record_visibility_event(_is_visible: bool, model: Node3D) -> void: # Main thread
	_lazy_tracker[model] = _times[1] # engine time


func _get_model_basis(file_prefix: String, m_radius := NAN, e_radius := NAN) -> Basis:
	# radii used only for ellipsoid
	var basis := Basis()
	var path: String = _model_paths.get(file_prefix, "")
	if path: # has model file
		var model_scale := METER
		var asset_row := IVTableData.get_row(path.get_file())
		if asset_row != -1:
			model_scale = IVTableData.get_db_float("asset_adjustments", "model_scale", asset_row)
			model_scale *= METER
		basis = basis.scaled(model_scale * Vector3.ONE)
	else: # constructed ellipsoid model
		assert(!is_nan(m_radius) and !is_inf(m_radius))
		if !is_nan(e_radius) and !is_inf(e_radius):
			var polar_radius: = 3.0 * m_radius - 2.0 * e_radius
			basis = basis.scaled(Vector3(e_radius, polar_radius, e_radius))
		else:
			basis = basis.scaled(m_radius * Vector3.ONE)
		# map rotation - we only look for *.albedo file
		path = _map_paths.get(file_prefix + ".albedo", "")
		if path:
			var asset_row := IVTableData.get_row(path.get_file())
			if asset_row != -1:
				var longitude_offset := IVTableData.get_db_float("asset_adjustments",
						"longitude_offset", asset_row)
				if !is_nan(longitude_offset):
					basis = basis.rotated(Vector3(0.0, 1.0, 0.0), -longitude_offset)
	basis = basis.rotated(Vector3(0.0, 1.0, 0.0), -PI / 2.0) # adjust for centered prime meridian
	basis = basis.rotated(Vector3(1.0, 0.0, 0.0), PI / 2.0) # z-up in astronomy!
	return basis


func _preregister_files() -> void:
	# Do this work once at project init, since file tree won't change.
	assert(!DPRINT or IVDebug.dprint("ModelManager searching for model & texture files..."))
	var models_search := IVGlobal.models_search
	var maps_search := IVGlobal.maps_search
	for table in IVGlobal.body_tables:
		var n_rows := IVTableData.get_n_rows(table)
		var row := 0
		while row < n_rows:
			var file_prefix := IVTableData.get_db_string(table, "file_prefix", row)
			assert(file_prefix)
			var path := files.find_resource_file(models_search, file_prefix)
			if path:
				_model_paths[file_prefix] = path
			assert(!DPRINT or IVDebug.dprint(path if path else "No model matching " + file_prefix))
			for suffix in map_search_suffixes:
				var file_match := file_prefix + suffix
				path = files.find_resource_file(maps_search, file_match)
				if path:
					_map_paths[file_match] = path
				assert(!DPRINT or IVDebug.dprint(path if path else "No texture matching " + file_match))
			row += 1

