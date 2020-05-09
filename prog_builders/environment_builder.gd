# environment_builder.gd
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
# It takes a while to load the environment depending on starmap size. 8k is
# twice as fast as 16k, at least on my laptop.

class_name EnvironmentBuilder

var fallback_starmap := "starmap_8k" # Global.asset_paths index; must exist

var _settings: Dictionary = Global.settings
var _asset_paths: Dictionary = Global.asset_paths

func project_init() -> void:
	pass

func add_world_environment(env_type := 0) -> void:
	print("Adding WorldEnvironment...")
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = get_environment(env_type)
	Global.program.universe.add_child(world_env)

func get_environment(_env_type: int) -> Environment:
	# TODO: Read env settings from data table!
	var panorama_sky := PanoramaSky.new()
	var starmap_file: String
	match _settings.starmap:
		Enums.StarmapSizes.STARMAP_8K:
			starmap_file = _asset_paths.starmap_8k
		Enums.StarmapSizes.STARMAP_16K:
			starmap_file = _asset_paths.starmap_16k
	if !FileUtils.exists(starmap_file):
		starmap_file = _asset_paths[fallback_starmap]
	var starmap: Texture = load(starmap_file)
	panorama_sky.panorama = starmap
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.background_sky = panorama_sky
	env.glow_enabled = true
	env.background_energy = 1.0
	env.ambient_light_color = Color.white
	env.ambient_light_energy = 0.03 # adjust up for web?
	env.ambient_light_sky_contribution = 0.0
	if Global.is_gles2: # GLES2 lighting is different than GLES3!
		env.ambient_light_energy = 0.2
	return env
