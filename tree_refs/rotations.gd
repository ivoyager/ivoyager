# rotations.gd
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
# Handles rotation and rotation precession.
# TODO: Rotation precession.
# TODO: Hyperion has chaotic rotation. How do we simulate that???

class_name Rotations

var axial_tilt := 0.0
var right_ascension := -INF
var declination := -INF
var rotation_period := 0.0
var north_pole := Vector3(0.0, 0.0, 1.0)

const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["axial_tilt", "right_ascension", "declination",
	"rotation_period", "north_pole"]

func get_basis(time: float, model_basis: Basis) -> Basis:
	var rotation_angle := wrapf(time * TAU / rotation_period, 0.0, TAU)
	return model_basis.rotated(north_pole, rotation_angle)


