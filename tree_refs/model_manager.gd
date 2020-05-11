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
var body_ref_basis := Basis() # rotated for north_pole and rotation_0

const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["axial_tilt", "right_ascension", "declination",
	"rotation_period", "north_pole", "body_ref_basis"]

# unpersisted (rebuilt on load)
var model: Spatial # program-built MeshInstance or imported Spatial scene
var model_ref_basis := Basis() # original model rotations & scale

var _dynamic_star: Array
var _working_basis: Basis

func set_model(model_: Spatial) -> void:
	model = model_
	set_model_ref_basis(model.transform.basis)

func replace_model(model_: Spatial) -> void:
	# assumes model_ref_basis is correct
	model = model_

func set_dynamic_star(surface: SpatialMaterial, grow_dist: float, grow_exponent: float,
		energy_ref_dist: float, energy_near: float, energy_exponent: float) -> void:
	_dynamic_star = [
		surface,
		grow_dist,
		grow_exponent,
		energy_ref_dist,
		energy_near,
		energy_exponent
	]

func set_body_ref_basis(body_ref_basis_: Basis) -> void:
	body_ref_basis = body_ref_basis_
	_working_basis = body_ref_basis * model_ref_basis

func set_model_ref_basis(model_ref_basis_: Basis) -> void:
	model_ref_basis = model_ref_basis_
	_working_basis = body_ref_basis * model_ref_basis

func process_visible(time: float, camera_dist: float) -> void:
	var rotation_angle := wrapf(time * TAU / rotation_period, 0.0, TAU)
	if !_dynamic_star:
		model.transform.basis = _working_basis.rotated(north_pole, rotation_angle)
	else:
		var surface: SpatialMaterial = _dynamic_star[0]
		var grow_dist: float = _dynamic_star[1]
		var emission_ref_dist: float = _dynamic_star[3]
		var emission_near: float = _dynamic_star[4]
		var emission_exponent: float = _dynamic_star[5]
		# dynamic scaling
		if camera_dist > grow_dist:
			var grow_exponent: float = _dynamic_star[2]
			var scale := pow(camera_dist / grow_dist, grow_exponent)
			var scaled_basis := _working_basis.scaled(Vector3(scale, scale, scale))
			model.transform.basis = scaled_basis.rotated(north_pole, rotation_angle)
		else:
			model.transform.basis = _working_basis.rotated(north_pole, rotation_angle)
		# dynamic emission energy
		var dist_ratio := camera_dist / emission_ref_dist
		if dist_ratio < 1.0:
			dist_ratio = 1.0
		surface.emission_energy = emission_near * \
				pow(dist_ratio, emission_exponent)

func change_visibility(is_visible: bool) -> void:
	model.visible = is_visible
