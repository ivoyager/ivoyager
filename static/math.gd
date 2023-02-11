# math.gd
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
class_name IVMath
extends Object

# Call directly using IVMath, or better, localize in your class header area.
# Issue #37529 prevents localization of global class_name to const. Use:
# const math := preload("res://ivoyager/static/math.gd")
#
# WIP -
# Spherical coordinates are ALWAYS either:
#   right_ascension, declination, distance (= longitude, latitude, distance)
#   right_ascension, declination (= longitude, latitude)
# Elsewhere in code these might be ecliptic2, equatorial2, geographic2, etc.

const IDENTITY_BASIS := Basis.IDENTITY
const Z_VECTOR := Vector3(0.0, 0.0, 1.0)
const VECTOR2_ZERO := Vector2.ZERO
const VECTOR3_ZERO := Vector3.ZERO
const LOG_OF_10 := log(10.0)



static func get_rotation_vector(basis: Basis) -> Vector3:
	# Axis & angle can be obtained by vector.normalized() & vector.length().
	# Identity basis will result in Vector3.ZERO.
	var u := Vector3(
		basis[1][2] - basis[2][1],
		basis[2][0] - basis[0][2],
		basis[0][1] - basis[1][0]
	)
	var trace := basis[0][0] + basis[1][1] + basis[2][2]
	if !u:
		if trace > 2.5: # 0.0 rotation
			return VECTOR3_ZERO
		else: # PI rotation
			return(Vector3(PI, 0.0, 0.0)) # axis is arbitrary
	var th := acos((trace - 1.0) / 2.0)
	return u.normalized() * th


static func rotate_vector_z(vector: Vector3, new_z: Vector3) -> Vector3:
	# Uses Rodrigues Rotation Formula to rotate vector to a new basis defined
	# by new_z; new_z must be a unit vector. Use for N Pole rotations.
	if vector == Z_VECTOR:
		return new_z
	if new_z == Z_VECTOR:
		return vector
	var cos_th := Z_VECTOR.dot(new_z)
	var X := Z_VECTOR.cross(new_z)
	var sin_th := X.length()
	var k := X / sin_th # normalized cross product
	return vector * cos_th + k.cross(vector) * sin_th + k * k.dot(vector) * (1.0 - cos_th)


static func unrotate_vector_z(vector: Vector3, old_z: Vector3) -> Vector3:
	# converse of above function
	if old_z == Z_VECTOR:
		return vector
	var cos_th := Z_VECTOR.dot(old_z)
	var X := -Z_VECTOR.cross(old_z) # flip the cross-product for converse
	var sin_th := X.length()
	var k := X / sin_th # normalized cross product
	return vector * cos_th + k.cross(vector) * sin_th + k * k.dot(vector) * (1.0 - cos_th)


static func rotate_basis_z(basis: Basis, new_z: Vector3) -> Basis:
	if new_z == Z_VECTOR:
		return basis
	var cos_th := Z_VECTOR.dot(new_z)
	var X := Z_VECTOR.cross(new_z)
	var sin_th := X.length()
	var k := X / sin_th # normalized cross product
	var c1 := 1.0 - cos_th
	basis.x = basis.x * cos_th + k.cross(basis.x) * sin_th + k * k.dot(basis.x) * c1
	basis.y = basis.y * cos_th + k.cross(basis.y) * sin_th + k * k.dot(basis.y) * c1
	basis.z = basis.z * cos_th + k.cross(basis.z) * sin_th + k * k.dot(basis.z) * c1
	return basis


static func get_rotation_matrix(keplerian_elements: Array) -> Basis:
	var i: float = keplerian_elements[2]
	var Om: float = keplerian_elements[3]
	var w: float = keplerian_elements[4]
	var sin_i := sin(i)
	var cos_i := cos(i)
	var sin_Om := sin(Om)
	var cos_Om := cos(Om)
	var sin_w := sin(w)
	var cos_w := cos(w)
	return Basis(
		Vector3(
			cos_Om * cos_w - sin_Om * cos_i * sin_w,
			sin_Om * cos_w + cos_Om * cos_i * sin_w,
			sin_i * sin_w
		),
		Vector3(
			-cos_Om * sin_w - sin_Om * cos_i * cos_w,
			-sin_Om * sin_w + cos_Om * cos_i * cos_w,
			sin_i * cos_w
		),
		Vector3(
			sin_i * sin_Om,
			-sin_i * cos_Om,
			cos_i
		)
	)


# Obliquity of the ecliptic (=23.439 deg) is rotation around the x-axis
static func get_x_rotation_matrix(th: float) -> Basis:
	return Basis(
		Vector3(1, 0, 0),
		Vector3(0, cos(th), -sin(th)),
		Vector3(0, sin(th), cos(th))
	)


static func get_y_rotation_matrix(th: float) -> Basis:
	return Basis(
		Vector3(cos(th), 0, sin(th)),
		Vector3(0, 1, 0),
		Vector3(-sin(th), 0, cos(th))
	)


static func get_z_rotation_matrix(th: float) -> Basis:
	return Basis(
		Vector3(cos(th), -sin(th), 0),
		Vector3(sin(th), cos(th), 0),
		Vector3(0, 0, 1)
	)


static func get_euler_rotation_matrix(Om: float, i: float, w: float) -> Basis:
	# WIP - I started this and didn't finish. Never tested.
	# Om, i, w are Euler angles alpha, beta, gamma (intrinsic rotations)
	var x1 = cos(Om) * cos(w) - sin(Om) * cos(i) * sin(w)
	var x2 = sin(Om) * cos(w) + cos(w) * cos(i) * sin(w)
	var x3 = sin(i) * sin(w)
	var y1 = -cos(Om) * sin(w) - sin(Om) * cos(i) * cos(w)
	var y2 = -sin(Om) * sin(w) + cos(Om) * cos(i) * cos(w)
	var y3 = sin(i) * cos(w)
	var z1 = sin(i) * sin(Om)
	var z2 = -sin(i) * cos(Om)
	var z3 = cos(i)
	return Basis(
		Vector3(x1, x2, x3),
		Vector3(y1, y2, y3),
		Vector3(z1, z2, z3)
	)


# Spherical
static func get_spherical2(translation: Vector3) -> Vector2:
	var r := translation.length()
	if r == 0.0:
		return VECTOR2_ZERO
	var right_ascension := fposmod(atan2(translation.y, translation.x), TAU) # 0,0 safe
	var declination := asin(translation.z / r)
	return Vector2(right_ascension, declination)


static func convert_spherical2(right_ascension: float, declination: float) -> Vector3:
	# returns translation with r = 1.0
	var cos_decl := cos(declination)
	return Vector3(
		cos(right_ascension) * cos_decl,
		sin(right_ascension) * cos_decl,
		sin(declination)
	)


static func get_spherical3(translation: Vector3) -> Vector3:
	var r := translation.length()
	if r == 0.0:
		return VECTOR3_ZERO
	var right_ascension := fposmod(atan2(translation.y, translation.x), TAU)
	var declination := asin(translation.z / r)
	return Vector3(right_ascension, declination, r)


static func convert_spherical3(spherical3: Vector3) -> Vector3:
	var right_ascension: float = spherical3[0]
	var declination: float = spherical3[1]
	var r: float = spherical3[2]
	var cos_decl := cos(declination)
	return Vector3(
		r * cos(right_ascension) * cos_decl,
		r * sin(right_ascension) * cos_decl,
		r * sin(declination)
	)


static func get_rotated_spherical3(translation: Vector3, rotation := IDENTITY_BASIS) -> Vector3:
	translation = rotation.xform_inv(translation)
	return get_spherical3(translation)


static func convert_rotated_spherical3(spherical3: Vector3, rotation := IDENTITY_BASIS) -> Vector3:
	var translation := convert_spherical3(spherical3)
	return rotation.xform(translation)


static func wrap_spherical3(spherical3: Vector3) -> Vector3:
	var ra: float = spherical3[0] # make this 0 to TAU
	var dec: float = spherical3[1] # make this -PI/2 to PI/2
	dec = wrapf(dec, -PI, PI)
	if dec > (PI / 2.0): # pole traversal
		dec = PI - dec
		ra += PI
	elif dec < (-PI / 2.0): # pole traversal
		dec = PI + dec
		ra += PI
	ra = fposmod(ra, TAU)
	spherical3[0] = ra
	spherical3[1] = dec
	return spherical3


static func get_latitude_longitude(translation: Vector3) -> Vector2:
	# Convinience function; order & wrapping differ from spherical2 
	var spherical := get_spherical2(translation)
	return Vector2(spherical[1], wrapf(spherical[0], -PI, PI))


# Misc
static func acosh(x: float) -> float:
	# from https://en.wikipedia.org/wiki/Hyperbolic_function
	assert(x >= 1.0)
	return log(x + sqrt(x * x - 1.0))


static func get_fov_from_focal_length(focal_length: float) -> float:
	# This is for photography buffs who think in focal lengths (of full-frame
	# sensor) rather than fov. Godot sets fov to fit horizonal screen height by
	# default, so we use horizonal height of a full-frame sensor (11.67mm)
	# to calculate: fov = 2 * arctan(sensor_size / focal_length).
	return rad2deg(2.0 * atan(11.67 / focal_length))


static func get_focal_length_from_fov(fov: float) -> float:
	return 11.67 / tan(deg2rad(fov) / 2.0)


static func get_fov_scaling_factor(fov: float) -> float:
	# This polynomial was empirically determined (with a tape measure!) to
	# correct icon size on the screen for fov changes (more or less). Icons
	# werer depreciated, but it may be more generally useful for scale
	# corrections after fov change.
	return 0.00005 * fov * fov + 0.0001 * fov + 0.0816


# Quadratic fit and transformation

static func quadratic_fit(x_array: Array, y_array: Array) -> Array:
	# Returns [a, b, c] where y = ax^2 + bx + c is least-squares fit,
	# or [0.0, 0.0, 0.0] if indeterminant or nearly indeterminant.
	var n := x_array.size()
	assert(n == y_array.size())
	var sum_x := 0.0
	var sum_x2 := 0.0
	var sum_x3 := 0.0
	var sum_x4 := 0.0
	var sum_y := 0.0
	var sum_xy := 0.0
	var sum_x2y := 0.0
	for i in n:
		var x: float = x_array[i]
		var x2 := x * x
		var x3 := x2 * x
		var x4 := x3 * x
		var y: float = y_array[i]
		var xy := x * y
		var x2y := x2 * y
		sum_x += x
		sum_x2 += x2
		sum_x3 += x3
		sum_x4 += x4
		sum_y += y
		sum_xy += xy
		sum_x2y += x2y
	var mean_x := sum_x / n
	var mean_x2 := sum_x2 / n
	var mean_y := sum_y / n
	var S11 := sum_x2 - sum_x * mean_x
	var S12 := sum_x3 - sum_x * mean_x2
	var S22 := sum_x4 - sum_x2 * mean_x2
	var Sy1 := sum_xy - sum_y * mean_x
	var Sy2 := sum_x2y - sum_y * mean_x2
	var divisor := S22 * S11 - S12 * S12
	if is_zero_approx(divisor):
		return [0.0, 0.0, 0.0]
	var b := (Sy1 * S22 - Sy2 * S12) / divisor
	var a := (Sy2 * S11 - Sy1 * S12) / divisor
	var c := mean_y - b * mean_x - a * mean_x2
	return [a, b, c]


static func quadratic(x: float, coefficients: Array) -> float:
	var a: float = coefficients[0]
	var b: float = coefficients[1]
	var c: float = coefficients[2]
	return a * x * x + b * x + c

	
















