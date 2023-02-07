# dynamic_star_model.gd
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
class_name DynamicStarModel
extends MeshInstance

# Grows a star model with camera distance to stay visible at great distances,
# for example, the Sun from Pluto. Grow effect occurs only at distances greater
# than 'grow_dist'.


var grow_dist := 6.0 * IVUnits.AU
var a := 0.01
var b := 0.01

var _world_targeting: Array = IVGlobal.world_targeting
var _reference_scale: float


func _init(reference_scale: float) -> void:
	_reference_scale = reference_scale


func _process(_delta: float) -> void:
	var camera: Camera = _world_targeting[2]
	var camera_dist := global_translation.distance_to(camera.global_translation)
	if camera_dist < grow_dist:
		scale = Vector3.ONE * _reference_scale
		return
	var excess := camera_dist / grow_dist - 1.0
	var grow_factor := a * excess * excess + b * excess + 1.0
	scale = Vector3.ONE * _reference_scale * grow_factor
	
	
	
	
