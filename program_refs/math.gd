# math.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2019 Charlie Whitfield
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

extends Reference
class_name Math

const ECLIPTIC_NORTH := Vector3(0.0, 0.0, 1.0)

func project_init():
	pass

static func cartesian2spherical(R: Vector3) -> Vector3:
	var r := R.length()
	var th := acos(R.z / r) # polar angle [0, PI]
	var ph := atan2(R.y, R.x) # azimuthal angle [0, TAU]
	return Vector3(r, th, ph)

static func spherical2cartesian(S: Vector3) -> Vector3:
	var r := S[0]
	var th := S[1]
	var ph := wrapf(S[2], 0.0, TAU)
	assert(th >= 0 and th <= PI)
	var sin_th := sin(th)
	return Vector3(
		r * sin_th * cos(ph), # x
		r * sin_th * sin(ph), # y
		r * cos(th) # z
		)

static func rotate_vector_pole(vector: Vector3, new_pole: Vector3) -> Vector3:
	# Uses Rodrigues Formula to rotate vector from ecliptic (z up) orientation to
	# provided new_pole; new_pole assumed to be a unit vector.
	if vector == ECLIPTIC_NORTH:
		return new_pole
	if new_pole == ECLIPTIC_NORTH:
		return vector
	var cos_th := ECLIPTIC_NORTH.dot(new_pole)
	var X := ECLIPTIC_NORTH.cross(new_pole)
	var sin_th := X.length()
	var k := X / sin_th # normalized cross product
	return vector * cos_th + k.cross(vector) * sin_th + k * k.dot(vector) * (1.0 - cos_th)

static func rotate_basis_pole(basis: Basis, new_pole: Vector3) -> Basis:
	# From ecliptic as above - NOT TESTED !!!
	if new_pole == ECLIPTIC_NORTH:
		return basis
	var cos_th := ECLIPTIC_NORTH.dot(new_pole)
	var X := ECLIPTIC_NORTH.cross(new_pole)
	var sin_th := X.length()
	var k := X / sin_th # normalized cross product
	var one_minus_cos_th := 1.0 - cos_th
	basis.x = basis.x * cos_th + k.cross(basis.x) * sin_th + k * k.dot(basis.x) * one_minus_cos_th
	basis.y = basis.y * cos_th + k.cross(basis.y) * sin_th + k * k.dot(basis.y) * one_minus_cos_th
	basis.z = basis.z * cos_th + k.cross(basis.z) * sin_th + k * k.dot(basis.z) * one_minus_cos_th
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


#static func get_circle_to_orbit_transform(keplerian_elements, fudge):
#	# Returned transform applied to a unit circle makes it an orbit.
#	# fudge pushes the vertecies out a bit to account for orbit granularity
#	# so that body is roughly equally outside and inside of line segments.
#	var a = keplerian_elements[0]
#	var e = keplerian_elements[1]
#	var b = a * sqrt(1.0 - e * e)
#	var rot = get_rotation_matrix(keplerian_elements)
#	var basis = Basis( # Strech to ellipse with semi-major, -minor = a, b
#		Vector3(a * (fudge + 1.0), 0.0, 0.0),
#		Vector3(0.0, b * (fudge + 1.0), 0.0),
#		Vector3(0.0, 0.0, 1.0)
#	)
#	basis = rot * basis # Rotate for i, Om, w
#	var origin = rot * Vector3(-a * e, 0.0, 0.0) # Shift from center to focus
#	return Transform(basis, origin)



static func batch_interval(max_interval: float, batch_size: int, total_size: int) -> float:
	# Div up max_interval such that total_size can be done in batch_size
	# items without violating max_interval for any item.
	# Expects max_interval float; others int.
	if total_size > batch_size:
		#warning-ignore:integer_division
		return max_interval / ((total_size - 1) / batch_size + 1)
	else:
		return max_interval


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

# RA, dec are spherical coordinates except dec is from equator rather than pole
static func convert_equatorial_coordinates(right_ascension: float, declination: float) -> Vector3:
	return Vector3(
		cos(right_ascension) * cos(declination),
		sin(right_ascension) * cos(declination),
		sin(declination)
	)

static func get_equatorial_coordinates(cartesian_position: Vector3) -> Vector2:
	var r := cartesian_position.length()
	return Vector2(
		fposmod(atan2(cartesian_position.y, cartesian_position.x), TAU), # RA
		asin(cartesian_position.z / r) # dec
	)

# Misc
static func acosh(x: float) -> float:
	# from https://en.wikipedia.org/wiki/Hyperbolic_function
	assert(x >= 1.0)
	return log(x + sqrt(x * x - 1))

# Camera
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
	# correct icon size on the screen for fov changes (more or less). It may
	# be more generally useful for scale corrections after fov change.
	return 0.00005 * fov * fov + 0.0001 * fov + 0.0816

# Conversions
static func srgb2linear(color: Color) -> Color:
	if color.r <= 0.04045:
		color.r /= 12.92
	else:
		color.r = pow((color.r + 0.055) / 1.055, 2.4)
	if color.g <= 0.04045:
		color.g /= 12.92
	else:
		color.g = pow((color.g + 0.055) / 1.055, 2.4)
	if color.b <= 0.04045:
		color.b /= 12.92
	else:
		color.b = pow((color.b + 0.055) / 1.055, 2.4)
	return color
		
static func linear2srgb(x: float) -> float:
	if x <= 0.0031308:
		return x * 12.92
	else:
		return pow(x, 1.0 / 2.4) * 1.055 - 0.055

static func au2km(x: float) -> float:
	return x * 149597870.0

static func km2au(x: float) -> float:
	return x / 149597870.0

static func au2megameter(x: float) -> float:
	return x * 149597.87
	
static func second2day(x: float) -> float:
	return x / 86400.0
	
static func year2day(x: float) -> float:
	return x * 365.25 # This is exactly correct for Julian year.
	
static func day2year(x: float) -> float:
	return x / 365.25 # This is exactly correct for Julian year.

static func conv_si_speed(x: float) -> float:
	# m/s to Mm/day
	# 86400/1e6 = 0.0864
	return x * 0.0864


# Simple linear regression
static func get_annual_estimate(yrs, yr_fraction):
	# Assumes yrs is array with element [0] being current partial year and additional elements being
	# past years going back in time. Discard older elements if you don't want them used in estimates.
	# https://math.stackexchange.com/questions/204020/what-is-the-equation-used-to-calculate-a-linear-trendline
	var n = yrs.size() - 1
	var sum_x = 0
	var sum_x_sq = 0
	var sum_y = 0
	var sum_x_y = 0
	for x in range(n):
		sum_x += x
		sum_x_sq += x * x
		sum_y += yrs[n - x] # from oldest element [size - 1] to last full year [1]
		sum_x_y += x * yrs[n - x]
	var slope = (n * sum_x_y - sum_x * sum_y) / (n * sum_x_sq - sum_x * sum_x)
	var offset = (sum_y - slope * sum_x) / n
	var trend_prediction = slope * (n + 1) + offset
	# suppliment current partial year by predition based on time left in year
	var estimate = yrs[0] + trend_prediction * (1.0 - yr_fraction)
	return [sum_y / n, estimate] # [ave of past years, current yr estimate]


static func get_quarter_estimate(qtrs, fraction_of_quarter):
	# Assumes qtrs is array with elements [1-4] being past quarters going back in time
	# and [0] being the current, partial quarter
	# simple linear regression with x= 0,1,2,3; calculate at x=4
	# https://math.stackexchange.com/questions/204020/what-is-the-equation-used-to-calculate-a-linear-trendline
	# n = 4
	# sum(x) = 6
	# sum(x^2) = 14
	# sum(x)^2 = 36
	# n sum(x^2) - sum(x)^2 = 4 * 14 - 36 = 20
	var sum_y = qtrs[4] + qtrs[3] + qtrs[2] + qtrs[1]
	var slope = (4.0 * (qtrs[3] + 2.0 * qtrs[2] + 3.0 * qtrs[1]) - 6.0 * sum_y) / 20.0
	var offset = (sum_y - slope * 6.0) / 4.0
	var trend_prediction = slope * 4.0 + offset
	# suppliment current partial quarter by predition based on time left in quarter
	var estimate = 4.0 * (qtrs[0] + trend_prediction * (1.0 - fraction_of_quarter))

	return [sum_y, estimate]

