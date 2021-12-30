# environment_builder.gd
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
# It takes a while to load the environment depending on starmap size and
# system. On my low-end laptop, 8k is much more than twice as fast as 16k.

class_name EnvironmentBuilder

var fallback_starmap := "starmap_8k" # Global.asset_paths index; must exist


func add_world_environment() -> void:
	var io_manager: IOManager = Global.program.IOManager
	io_manager.callback(self, "_io_callback", "_io_finish")

# *****************************************************************************

func _project_init() -> void:
	Global.connect("project_objects_instantiated", self, "_check_starmap_availability")
	Global.connect("project_inited", self, "add_world_environment")

func _check_starmap_availability() -> void:
	# TODO: See what files are available and reflect that in settings.
	pass

func _io_callback(array: Array) -> void: # I/O thread!
	var start_time := OS.get_system_time_msecs()
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = _get_environment()
	array.append(world_environment)
	array.append(start_time)

func _io_finish(array: Array) -> void: # Main thread
	var world_environment: WorldEnvironment = array[0]
	var start_time: int = array[1]
	Global.program.Universe.add_child(world_environment) # this hangs a while!
	var time := OS.get_system_time_msecs() - start_time
	print("Added WorldEnvironment in ", time, " msec")
	Global.emit_signal("world_environment_added")

func _get_environment() -> Environment: # I/O thread!
	# TODO: Read env settings from data table!
	var settings: Dictionary = Global.settings
	var asset_paths: Dictionary = Global.asset_paths
	var panorama_sky := PanoramaSky.new()
	var starmap_file: String
	match settings.starmap:
		Enums.StarmapSize.STARMAP_8K:
			starmap_file = asset_paths.starmap_8k
		Enums.StarmapSize.STARMAP_16K:
			starmap_file = asset_paths.starmap_16k
	if !FileUtils.exists(starmap_file):
		starmap_file = asset_paths[fallback_starmap]
	var starmap: Texture = load(starmap_file)
	panorama_sky.panorama = starmap
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.background_sky = panorama_sky
	env.background_energy = 1.0
	env.ambient_light_color = Color.white
	env.ambient_light_sky_contribution = 0.0
	env.ambient_light_energy = 0.03
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_intensity = 0.8
	env.glow_bloom = 1.0
	env.set_glow_level(0, false)
	env.set_glow_level(1, true)
	env.set_glow_level(2, false)
	env.set_glow_level(3, true)
	env.set_glow_level(4, false)
	env.set_glow_level(5, true)
	env.set_glow_level(6, true)
	if Global.is_gles2: # GLES2 lighting is different than GLES3!
		env.ambient_light_energy = 0.15
		env.glow_hdr_threshold = 0.9
		env.glow_intensity = 0.8
		env.glow_bloom = 0.5
	elif Global.auto_exposure_enabled:
		env.auto_exposure_enabled = true
		env.auto_exposure_speed = 5.0
		env.auto_exposure_scale = 0.4
		env.auto_exposure_min_luma = 0.165 # 0.18 # bigger reduces overexposure blowout
		env.auto_exposure_max_luma = 8.0 # small values increase overexp blowout (no auto corr)
		env.glow_hdr_luminance_cap = 12.0 # can't see any effect
		env.glow_hdr_scale = 2.0 # can't see any effect
#		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 0.4 # adjust w/ auto_exposure_scale
	return env
