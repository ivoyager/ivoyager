# model_controller.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield
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
# FIXME: Recode for standard lat/long origin definitions. For tidally locked, 0
# longitude is parent facing (mean). For others, it's an arbitrary landmark. We
# need a longitude_offset_at_epoch and a model_longitude_offset. 

class_name ModelController

const math := preload("res://ivoyager/static/math.gd") # =Math when issue #37529 fixed

signal changed() # public properties; whoever changes must emit

const ECLIPTIC_X := Vector3(1.0, 0.0, 0.0)

var axial_tilt := 0.0
var right_ascension := NAN
var declination := NAN
var rotation_period := 0.0
var north_pole := Vector3(0.0, 0.0, 1.0)
var basis_at_epoch := Basis.IDENTITY # north_pole and longitude_at_epoch rotations

const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["axial_tilt", "right_ascension", "declination",
	"rotation_period", "north_pole", "basis_at_epoch"]

# unpersisted (rebuilt on load)
var model: Spatial # program-built MeshInstance or imported Spatial scene
var model_reference_basis := Basis.IDENTITY

var _times: Array = Global.times
var _dynamic_star: Array
var _working_basis: Basis
var _is_visible := false


func get_latitude_longitude(translation: Vector3, time := NAN) -> Vector2:
	# Order is flipped from standard spherical (RA, Dec), and we wrap longitude
	# from -PI (West) to PI (East).
	var ground_basis := get_ground_ref_basis(time)
	var spherical := math.get_rotated_spherical3(translation, ground_basis)
	var latitude: float = spherical[1]
	var longitude: float = wrapf(spherical[0], -PI, PI)
	return Vector2(latitude, longitude)

func get_ground_ref_basis(time := NAN) -> Basis:
	if is_nan(time):
		time = _times[0]
	var rotation_angle := wrapf(time * TAU / rotation_period, 0.0, TAU)
	return basis_at_epoch.rotated(north_pole, rotation_angle)

func set_model(model_: Spatial, use_basis_as_reference := true) -> void:
	model = model_
	model.visible = _is_visible
	if use_basis_as_reference:
		set_model_reference_basis(model.transform.basis)

func set_model_reference_basis(model_basis_: Basis) -> void:
	model_reference_basis = model_basis_
	_working_basis = basis_at_epoch * model_reference_basis

func set_basis_at_epoch(basis_at_epoch_: Basis) -> void:
	basis_at_epoch = basis_at_epoch_
	_working_basis = basis_at_epoch * model_reference_basis

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
		surface.emission_energy = emission_near * pow(dist_ratio, emission_exponent)

func change_visibility(is_visible: bool) -> void:
	_is_visible = is_visible
	if model:
		model.visible = is_visible
