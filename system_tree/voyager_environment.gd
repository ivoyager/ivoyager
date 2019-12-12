# voyager_environment.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2019 Charlie Whitfield
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
# Project can replace this class with another WorldEnvironment. We build the
# environment by code to allow web depoloyment (uses different assets dir) and
# for future modding capability via text files.

extends WorldEnvironment
class_name VoyagerEnvironment

const PERSIST_AS_PROCEDURAL_OBJECT := true

func _ready():
	var panorama_sky := PanoramaSky.new()
	panorama_sky.panorama = Global.assets.starfield
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.background_sky = panorama_sky
	env.background_energy = 5.0
	env.ambient_light_color = Color.white
	env.ambient_light_energy = 0.02 # adjust up for web?
	env.ambient_light_sky_contribution = 0.0
	environment = env
