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
extends Reference

# Decorates Body (and its parent) with Body-associated unpersisted elements,
# such as ModelControler, various HUD elements, rings, light, etc. Everything
# here happens whether we are building from table or loading from gamesave
# file.
#
# Since I/O threaded resource loading is rate-limiting, this object evokes
# the IVGlobal 'system_tree_ready' signal. We also hook up the progress bar
# for user feedback (only works if threading enabled).


const files := preload("res://ivoyager/static/files.gd")
const BodyFlags := IVEnums.BodyFlags

# project vars
var min_click_radius := 20.0
var max_hud_dist_orbit_radius_multiplier := 100.0
var min_hud_dist_radius_multiplier := 500.0
var min_hud_dist_star_multiplier := 20.0 # combines w/ above

 # read-only! 
var progress := 0 # for external progress bar

# private
var _ModelController_: Script
var _HUDLabel_: Script
var _HUDOrbit_: Script

var _model_builder: IVModelBuilder
var _rings_builder: IVRingsBuilder
var _light_builder: IVLightBuilder
var _bodies_2d_search: Array = IVGlobal.bodies_2d_search
var _fallback_body_2d: Texture

var _io_manager: IVIOManager
var _main_prog_bar: IVMainProgBar

var _settings: Dictionary = IVGlobal.settings

var _is_building_system := false
var _system_build_count: int
var _system_finished_count: int
var _system_build_start_msec := 0


func _project_init() -> void:
	IVGlobal.connect("about_to_build_system_tree", self, "init_system_build")
	IVGlobal.connect("game_load_started", self, "init_system_build")
	IVGlobal.get_tree().connect("node_added", self, "_on_node_added")
	_model_builder = IVGlobal.program.ModelBuilder
	_rings_builder = IVGlobal.program.RingsBuilder
	_light_builder = IVGlobal.program.LightBuilder
	_io_manager = IVGlobal.program.IOManager
	_main_prog_bar = IVGlobal.program.get("MainProgBar") # safe if doesn't exist
	_ModelController_ = IVGlobal.script_classes._ModelController_
	_HUDLabel_ = IVGlobal.script_classes._HUDLabel_
	_HUDOrbit_ = IVGlobal.script_classes._HUDOrbit_
	_fallback_body_2d = IVGlobal.assets.fallback_body_2d


func init_system_build() -> void:
	# Track when Bodies are completely finished (including I/O threaded
	# resource loading) to signal "system_ready" and run the progress bar.
	progress = 0
	_is_building_system = true
	_system_build_count = 0
	_system_finished_count = 0
	_io_manager.callback(self, "_start_system_build_msec") # after existing I/O jobs
	if _main_prog_bar:
		_main_prog_bar.start(self)


func _on_node_added(node: Node) -> void:
	var body := node as IVBody
	if body:
		_build_unpersisted(body)


func _build_unpersisted(body: IVBody) -> void: # Main thread
	# This is after IVBody._enter_tree(), but before IVBody._ready()
	body.min_click_radius = min_click_radius
	body.max_hud_dist_orbit_radius_multiplier = max_hud_dist_orbit_radius_multiplier
	body.min_hud_dist_radius_multiplier = min_hud_dist_radius_multiplier
	body.min_hud_dist_star_multiplier = min_hud_dist_star_multiplier
	
	# Note: many builders called here ask for IVIOManager.callback. These are
	# processed in order, so the last callback at the end of this function will
	# have the last "finish" callback.
	if body.get_model_type() != -1:
		body.model_controller = _ModelController_.new()
		var lazy_init: bool = body.flags & BodyFlags.IS_MOON  \
				and not body.flags & BodyFlags.IS_NAVIGATOR_MOON
		_model_builder.add_model(body, lazy_init)
		body.reset_orientation_and_rotation()
	if body.has_rings():
		_rings_builder.add_rings(body)
	if body.get_light_type() != -1:
		_light_builder.add_omni_light(body)
	if body.orbit:
		var hud_orbit: IVHUDOrbit = _HUDOrbit_.new(body)
		body.get_parent().add_child(hud_orbit)
	var hud_label: IVHUDLabel = _HUDLabel_.new(body)
	body.add_child(hud_label)
	var file_prefix := body.get_file_prefix()
	var is_star := bool(body.flags & BodyFlags.IS_STAR)
	if _is_building_system:
		_system_build_count += 1
	var array := [body, file_prefix, is_star]
	_io_manager.callback(self, "_load_textures_on_io_thread", "_io_finish", array)


func _load_textures_on_io_thread(array: Array) -> void: # I/O thread
	var file_prefix: String = array[1]
	var is_star: bool = array[2]
	var texture_2d: Texture = files.find_and_load_resource(_bodies_2d_search, file_prefix)
	if !texture_2d:
		texture_2d = _fallback_body_2d
	array.append(texture_2d)
	if is_star:
		var slice_name = file_prefix + "_slice"
		var texture_slice_2d: Texture = files.find_and_load_resource(_bodies_2d_search, slice_name)
		array.append(texture_slice_2d)


func _io_finish(array: Array) -> void: # Main thread
	var body: IVBody = array[0]
	var is_star: bool = array[2]
	var texture_2d: Texture = array[3]
	body.texture_2d = texture_2d
	if is_star:
		var texture_slice_2d: Texture = array[4]
		body.texture_slice_2d = texture_slice_2d
	if _is_building_system:
		_system_finished_count += 1
		# warning-ignore:integer_division
		progress = 100 * _system_finished_count / _system_build_count
		if _system_finished_count == _system_build_count:
			_finish_system_build()


func _start_system_build_msec(_array: Array) -> void: # I/O thread
	_system_build_start_msec = Time.get_ticks_msec()


func _finish_system_build() -> void: # Main thread
		_is_building_system = false
		var msec :=  Time.get_ticks_msec() - _system_build_start_msec
		print("Built %s solar system bodies in %s msec" % [_system_build_count, msec])
		var is_new_game: bool = !IVGlobal.state.is_loaded_game
		IVGlobal.verbose_signal("system_tree_ready", is_new_game)
		if _main_prog_bar:
			_main_prog_bar.stop()

