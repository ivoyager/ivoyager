# model_controller.gd
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
# Handles rotation (TODO: and rotation precession). For star, handles dynamic
# emission and scaling (to maintain effects & visibility at great distance)
#
# TODO: North pole precession. We will need an ave_north_pole for rotation. 
# TODO: Hyperion has chaotic rotation & precession. How do we simulate that???
#
# For astronomical bodies, we set rotation_vector to match "north". See
# comments under Body.get_north().

class_name ModelController

const math := preload("res://ivoyager/static/math.gd") # =IVMath when issue #37529 fixed

signal changed() # public properties; whoever changes must emit


# Body
var rotation_vector := Vector3(0.0, 0.0, 1.0)
var rotation_rate := 0.0
var rotation_at_epoch := 0.0
var basis_at_epoch := Basis.IDENTITY
# Model
var model: Spatial # program-built MeshInstance or imported Spatial scene
var model_reference_basis := Basis.IDENTITY # z up

var _times: Array = IVGlobal.times
var _dynamic_star: Array
var _working_basis: Basis
var _is_visible := false


func get_ground_ref_basis(time := NAN) -> Basis:
	if is_nan(time):
		time = _times[0]
	var rotation_angle := wrapf(time * rotation_rate, 0.0, TAU)
	return basis_at_epoch.rotated(rotation_vector, rotation_angle)

func set_body_parameters(rotation_vector_: Vector3, rotation_rate_: float,
		rotation_at_epoch_: float) -> void:
	rotation_vector = rotation_vector_
	rotation_rate = rotation_rate_
	rotation_at_epoch = rotation_at_epoch_
	var basis := math.rotate_basis_z(Basis(), rotation_vector)
	basis_at_epoch = basis.rotated(rotation_vector, rotation_at_epoch_)
	_working_basis = basis_at_epoch * model_reference_basis

func set_model_reference_basis(model_basis_: Basis) -> void:
	model_reference_basis = model_basis_
	_working_basis = basis_at_epoch * model_reference_basis

func set_model(model_: Spatial, use_basis_as_reference := true) -> void:
	model = model_
	model.visible = _is_visible
	if use_basis_as_reference:
		set_model_reference_basis(model.transform.basis)

func set_dynamic_star(surface: SpatialMaterial, grow_dist: float, grow_exponent: float,
		energy_ref_dist: float, energy_near: float, energy_exponent: float) -> void:
	# TODO: When star map is a shader, we can depreciate this dynamic scaling
	_dynamic_star = [
		surface,
		grow_dist,
		grow_exponent,
		energy_ref_dist,
		energy_near,
		energy_exponent
	]

func process_visible(time: float, camera_dist: float) -> void:
	if !model:
		return
	var rotation_angle := wrapf(time * rotation_rate, 0.0, TAU)
	if !_dynamic_star:
		model.transform.basis = _working_basis.rotated(rotation_vector, rotation_angle)
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
			model.transform.basis = scaled_basis.rotated(rotation_vector, rotation_angle)
		else:
			model.transform.basis = _working_basis.rotated(rotation_vector, rotation_angle)
		# dynamic emission energy
		var dist_ratio := camera_dist / emission_ref_dist
		if dist_ratio < 1.0:
			dist_ratio = 1.0
		surface.emission_energy = emission_near * pow(dist_ratio, emission_exponent)

func change_visibility(is_visible: bool) -> void:
	_is_visible = is_visible
	if model:
		model.visible = is_visible
