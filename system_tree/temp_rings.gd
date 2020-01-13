# temp_rings.gd
# This file is part of I, Voyager
# https://ivoyager.dev
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
#
# TODO: Make a rings shader!

extends MeshInstance
class_name TempRings

const TOO_FAR_RADIUS_MULTIPLIER := 2e3

var _rings_material := SpatialMaterial.new()

func init(rings_file: String, radius: float) -> void:
	var texture: Texture = FileHelper.find_resource(Global.asset_paths.rings_dir, rings_file)
	assert(texture) # no fallback!
	_rings_material.albedo_texture = texture
	_rings_material.flags_transparent = true
	_rings_material.params_cull_mode = SpatialMaterial.CULL_DISABLED
	_rings_material.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
	scale = Vector3(radius * 2.0, radius * 2.0, 1.0)
	cast_shadow = SHADOW_CASTING_SETTING_ON
	hide()

func _ready() -> void:
	_on_ready()

func _on_ready():
	mesh = QuadMesh.new()
	set_surface_material(0, _rings_material)
	
	