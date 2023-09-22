# environment_builder.gd
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
class_name IVEnvironmentBuilder
extends RefCounted

# It takes a while to load the environment depending on starmap size and
# system. On my low-end laptop, 8k is much more than twice as fast as 16k.

var fallback_starmap := &"starmap_8k" # IVGlobal.asset_paths index; must exist


func _project_init() -> void:
	IVGlobal.project_objects_instantiated.connect(_check_starmap_availability)
	IVGlobal.project_inited.connect(add_world_environment)


func _check_starmap_availability() -> void:
	# TODO: See what files are available and reflect that in settings.
	pass


func add_world_environment() -> void:
	var io_manager: IVIOManager = IVGlobal.program.IOManager
	io_manager.callback(_io_callback)


func _io_callback() -> void: # I/O thread!
	var start_time := Time.get_ticks_msec()
	var world_environment := WorldEnvironment.new()
	world_environment.name = &"WorldEnvironment"
	world_environment.environment = _get_environment()
	_finish.call_deferred(world_environment, start_time)


func _finish(world_environment: WorldEnvironment, start_time: int) -> void: # Main thread
	var universe: Node3D = IVGlobal.program.Universe
	universe.add_child(world_environment) # this hangs a while!
	var time := Time.get_ticks_msec() - start_time
	print("Added WorldEnvironment in ", time, " msec")
	IVGlobal.world_environment_added.emit()


func _get_environment() -> Environment: # I/O thread!
	# TODO: Read env settings from data table!
	var settings: Dictionary = IVGlobal.settings
	var asset_paths: Dictionary = IVGlobal.asset_paths
	var starmap_file: String
	match settings.starmap:
		IVEnums.StarmapSize.STARMAP_8K:
			starmap_file = asset_paths.starmap_8k
		IVEnums.StarmapSize.STARMAP_16K:
			starmap_file = asset_paths.starmap_16k
	if !IVFiles.exists(starmap_file):
		starmap_file = asset_paths[fallback_starmap]
	var starmap: Texture2D = load(starmap_file)
	var sky_material := PanoramaSkyMaterial.new()
	sky_material.panorama = starmap
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.background_energy_multiplier = 1.0
	env.ambient_light_color = Color.WHITE
	env.ambient_light_sky_contribution = 0.0
	env.ambient_light_energy = 0.01
	
#	env.sdfgi_enabled = true
	
	return env

