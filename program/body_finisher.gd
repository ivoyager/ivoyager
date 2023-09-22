# body_finisher.gd
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
class_name IVBodyFinisher
extends RefCounted

# Decorates Body (and its parent) with Body-associated unpersisted elements,
# such as HUD elements, rings, omni light, etc. Everything here happens
# whether we are building a new system or loading from gamesave file.


signal system_build_finished()


const files := preload("res://ivoyager/static/files.gd")
const BodyFlags := IVEnums.BodyFlags

# project vars
var min_click_radius := 20.0
var max_hud_dist_orbit_radius_multiplier := 100.0
var min_hud_dist_radius_multiplier := 500.0
var min_hud_dist_star_multiplier := 20.0 # combines w/ above

 # read-only! 
var progress := 0 # TODO: Re-implement the progress bar

# private
#var _ModelController_: Script
var _BodyLabel_: Script
var _BodyOrbit_: Script
var _Rings_: Script

var _model_manager: IVModelManager
var _bodies_2d_search := IVGlobal.bodies_2d_search
var _fallback_body_2d: Texture2D

var _io_manager: IVIOManager

var _is_building_system := false
var _started_count: int
var _finished_count: int
var _system_build_start_msec := 0


func _project_init() -> void:
	IVGlobal.get_tree().node_added.connect(_on_node_added)
	_model_manager = IVGlobal.program[&"ModelManager"]
	_io_manager = IVGlobal.program[&"IOManager"]
	_BodyLabel_ = IVGlobal.procedural_classes[&"_BodyLabel_"]
	_BodyOrbit_ = IVGlobal.procedural_classes[&"_BodyOrbit_"]
	_Rings_ = IVGlobal.procedural_classes[&"_Rings_"]
	_fallback_body_2d = IVGlobal.assets[&"fallback_body_2d"]


func init_system_build() -> void:
	# Called by IVSystemBuilder if this is system build for new or loaded game.
	progress = 0
	_is_building_system = true
	_started_count = 0
	_finished_count = 0


func _on_node_added(node: Node) -> void:
	var body := node as IVBody
	if !body:
		return
	if _is_building_system and _started_count == 0:
		_system_build_start_msec = Time.get_ticks_msec()
	_started_count += 1
	_build_unpersisted(body)


func _build_unpersisted(body: IVBody) -> void: # Main thread
	# This is after IVBody._enter_tree(), but before IVBody._ready()
	# Don't defer this call; children need their parent to have this done already.
	body.reset_orientation_and_rotation() # here so children can obtain positive pole
	
	body.min_click_radius = min_click_radius
	body.max_hud_dist_orbit_radius_multiplier = max_hud_dist_orbit_radius_multiplier
	body.min_hud_dist_radius_multiplier = min_hud_dist_radius_multiplier
	body.min_hud_dist_star_multiplier = min_hud_dist_star_multiplier
	
	if body.get_model_type() != -1:
		var lazy_init: bool = body.flags & BodyFlags.IS_MOON  \
				and not body.flags & BodyFlags.IS_NAVIGATOR_MOON
		_model_manager.add_model(body, lazy_init)
	if body.has_omni_light():
		var omni_light_type := body.get_omni_light_type()
		var omni_light := OmniLight3D.new()
		# set properties entirely from table
		IVTableData.db_build_object_all_fields(omni_light, &"omni_lights", omni_light_type)
		body.add_child(omni_light)
	if body.orbit:
		@warning_ignore("unsafe_method_access") # possible replacement class
		var body_orbit: Node3D = _BodyOrbit_.new(body)
		body.get_parent().add_child(body_orbit)
	@warning_ignore("unsafe_method_access") # possible replacement class
	var body_label: Node3D = _BodyLabel_.new(body)
	body.add_child(body_label)
	var file_prefix := body.get_file_prefix()
	var is_star := bool(body.flags & BodyFlags.IS_STAR)
	var rings_file_prefix := body.get_rings_file_prefix()
	_io_manager.callback(_load_textures_on_io_thread.bind(body, file_prefix, is_star,
			rings_file_prefix))


func _load_textures_on_io_thread(body: IVBody, file_prefix: String, is_star: bool,
		rings_file_prefix: String) -> void: # I/O thread
	var texture_2d: Texture2D = files.find_and_load_resource(_bodies_2d_search, file_prefix)
	if !texture_2d:
		texture_2d = _fallback_body_2d
	var texture_slice_2d: Texture2D
	if is_star:
		var slice_name = file_prefix + "_slice"
		texture_slice_2d = files.find_and_load_resource(_bodies_2d_search, slice_name)
	var rings_images: Array[Image]
	if rings_file_prefix:
		var rings_search: Array = IVGlobal.rings_search
		var backscatter: Texture2D = files.find_and_load_resource(rings_search,
				rings_file_prefix + ".backscatter")
		var forwardscatter: Texture2D = files.find_and_load_resource(rings_search,
				rings_file_prefix + ".forwardscatter")
		var unlitside: Texture2D = files.find_and_load_resource(rings_search,
				rings_file_prefix + ".unlitside")
		if !backscatter or !forwardscatter or !unlitside:
			print("WARNING! Could not find all 3 rings textures for prefix ", rings_file_prefix)
		else:
			rings_images = [backscatter.get_image(), forwardscatter.get_image(), unlitside.get_image()]
	_finish_on_main_thread.call_deferred(body, texture_2d, texture_slice_2d, rings_images)


func _finish_on_main_thread(body: IVBody, texture_2d: Texture2D, texture_slice_2d: Texture2D,
		rings_images: Array[Image]) -> void: # main thread
	body.texture_2d = texture_2d
	if texture_slice_2d:
		body.texture_slice_2d = texture_slice_2d
	if rings_images:
		var sunlight_source := body.get_parent_node_3d() # assumes no moon rings!
		@warning_ignore("unsafe_method_access") # possible replacement class
		var rings: Node3D = _Rings_.new(body, sunlight_source, rings_images)
		body.add_child_to_model_space(rings)
	_finished_count += 1
	if _is_building_system:
		@warning_ignore("integer_division")
		progress = 100 * _finished_count / _started_count
		if _finished_count == _started_count:
			_finish_system_build()


func _finish_system_build() -> void: # Main thread
	_is_building_system = false
	var msec :=  Time.get_ticks_msec() - _system_build_start_msec
	print("Added %s solar system bodies (IVBody) in %s msec" % [_finished_count, msec])
	system_build_finished.emit()

