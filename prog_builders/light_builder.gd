# light_builder.gd
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
# Only a star's OmniLight for now.

class_name LightBuilder

const METER := UnitDefs.METER

var omni_fields := {
	omni_range = "omni_range",
}

var _table_reader: TableReader

func project_init() -> void:
	_table_reader = Global.program.TableReader

func add_omnilight(body: Body) -> void:
	if body.light_type == -1:
		return
	var omnilight := OmniLight.new()
	var light_type: int = body.light_type
	_table_reader.build_object(omnilight, "lights", light_type, omni_fields)
	omnilight.shadow_enabled = true # FIXME: No shadows. Why not?
#	omnilight.shadow_bias = 0.01 # Can't even generate shadow artifacts
	omnilight.light_energy = 1.5
	omnilight.omni_attenuation = 8.0
	if Global.is_gles2:
		omnilight.light_energy = 1.2
		omnilight.omni_attenuation = 3.0
	body.add_child(omnilight)
