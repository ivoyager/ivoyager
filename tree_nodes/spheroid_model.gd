# spheroid_model.gd
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
class_name IVSpheroidModel
extends MeshInstance3D

# A generic spheroid model that uses a shared sphere mesh. IVModelBuilder will
# scale instances for appropriate oblateness.
#
# If is_dynamic_star, the model will grow with great distances to stay visible
# and appropriately prominent relative to the star field. The grow settings are
# currently subjective.

# TODO: materials.tsv to use all fields
const MATERIAL_FIELDS := ["metallic", "roughness", "rim_enabled", "rim", "rim_tint"]
const DYNAMIC_STAR_GROW_DIST := 2.0 * IVUnits.AU
const DYNAMIC_STAR_GROW_FACTOR := 0.5

var is_dynamic_star := false

var _world_targeting: Array = IVGlobal.world_targeting
var _reference_basis: Basis


func _init(model_type: int, reference_basis: Basis, albedo_map: Texture2D,
		emission_map: Texture2D) -> void:
	var table_reader: IVTableReader = IVGlobal.program.TableReader
	_reference_basis = reference_basis
	transform.basis = _reference_basis # z up, possibly oblate
	mesh = IVGlobal.shared.sphere_mesh
	var surface := StandardMaterial3D.new()
	set_surface_override_material(0, surface)
	table_reader.build_object(surface, MATERIAL_FIELDS, "models", model_type)
	if albedo_map:
		surface.albedo_texture = albedo_map
	if emission_map:
		surface.emission_enabled = true
		surface.emission_texture = emission_map
	if table_reader.get_bool("models", "starlight", model_type):
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		is_dynamic_star = true
	else:
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _ready() -> void:
	set_process(is_dynamic_star)


func _process(_delta: float) -> void:
	var camera: Camera3D = _world_targeting[2]
	if !camera:
		return
	var camera_dist := global_position.distance_to(camera.global_position)
	if camera_dist < DYNAMIC_STAR_GROW_DIST:
		transform.basis = _reference_basis
		return
	var excess := camera_dist / DYNAMIC_STAR_GROW_DIST - 1.0
	var factor := DYNAMIC_STAR_GROW_FACTOR * excess + 1.0
	transform.basis = _reference_basis.scaled(Vector3(factor, factor, factor))

