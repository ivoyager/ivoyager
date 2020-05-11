# model_manager.gd
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
# Handles rotation (TODO: and rotation precession). For star, handles dynamic
# emission and scaling (to maintain effects & visibility at great distance)
#
# TODO: Hyperion has chaotic rotation. How do we simulate that???

class_name ModelManager

var axial_tilt := 0.0
var right_ascension := -INF
var declination := -INF
var rotation_period := 0.0
var north_pole := Vector3(0.0, 0.0, 1.0)
var reference_basis := Basis() # body z shift to north_pole and rotation_0

const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["axial_tilt", "right_ascension", "declination",
	"rotation_period", "north_pole", "reference_basis"]

#var _model_ref_basis: Basis # original model rotations & scale
#var _working_ref_basis: Basis

#func init_model_basis(model_ref_basis: Basis) -> void:
#	_model_ref_basis = model_ref_basis
#	_working_ref_basis = reference_basis * _model_ref_basis

func get_rotated_basis(model_basis: Basis, time: float) -> Basis:
	var rotation_angle := wrapf(time * TAU / rotation_period, 0.0, TAU)
	return (reference_basis * model_basis).rotated(north_pole, rotation_angle)
