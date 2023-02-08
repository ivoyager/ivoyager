# orbit.gd
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
class_name IVOrbit
extends Reference

# Orbit info is kept in standardized arrays of fixed size. reference_normal is
# normal to the reference plane (ecliptic, equatorial or specified Laplace
# plane; many moons use the latter two); the "orbit normal" precesses around
# the reference_normal.
#
# The standard orbital 'elements' array:
#   [0] a, semi-major axis
#   [1] e, eccentricity
#   [2] i, inclination
#   [3] Om, longitude of the ascending node
#   [4] w, argument of periapsis
#   [5] M0, mean anomaly at epoch
#   [6] n, mean motion
#
# Position is determined by time, reference_normal and current_elements;
# current_elements is determined by time, elements_at_epoch, element_rates
# and m_modifiers (if exists). element_rates and m_modifiers represent
# perturbations "endongenous" to the orbital system (e.g., oblateness of parent
# body). A rocket engine "perturbs" the system by directly affecting
# current orbital elements. However, we will apply such effects by back-
# calculating and applying changes to elements_at_epoch (and then updating
# endongenous purturbations if needed based on new orbital configuration). 
#
# See static/units.gd for base units.
#
# TODO: This is by far the largest CPU hog. Here is a data-oriented fix: 
#   - SystemOrbits will house all orbit data in packed arrays, and have all
#     existing methods here with leading orbit_id arg.
#   - IVBody will have orbit_id only, and call SystemOrbits directly.
#   - Depreciate this class.
#   - GDNative version of SystemOrbits

signal changed(is_scheduled) # is_scheduled == false triggers network sync

const math := preload("res://ivoyager/static/math.gd") # =IVMath when issue #37529 fixed

const DPRINT := false
const PIdiv2 := PI / 2.0
const ECLIPTIC_UP := Vector3(0.0, 0.0, 1.0)
const T_3000BCE := -50.0 * IVUnits.CENTURY # 3000 BCE
const T_3000CE := 10.0 * IVUnits.CENTURY # 3000 CE
const UPDATE_TOLERANCE := 0.0002
const UPDATE_LIMITER := IVUnits.HOUR # up to -10% to avoid schedular clumping

const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL
const PERSIST_PROPERTIES := [
	"reference_normal",
	"elements_at_epoch",
	"element_rates",
	"m_modifiers",
]

# persisted
var reference_normal := ECLIPTIC_UP # moons are often different
var elements_at_epoch := [] # [a, e, i, Om, w, M0, n]; required
var element_rates := [] # [a, e, i, Om, w]; optional
var m_modifiers := [] # [b, c, s, f]; planets Jupiter to Pluto only

# read-only
var current_elements := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

# private
var _times: Array = IVGlobal.times
var _scheduler: IVScheduler = IVGlobal.program.Scheduler
var _update_interval := 0.0
var _begin_current := INF
var _end_current := -INF


# TODO:
func perturb(_delta_v: Vector3, _at_time := NAN) -> void:
	# See comments above. We're perturbing our current orbital elements, but we
	# back-calculate and apply changes to elements_at_epoch that will give us
	# needed change in current_elements.
	# Based on context, we may need to recalculate element_rates or even
	# m_modifiers.
	pass


# information about orbit

func get_semimajor_axis(time := NAN) -> float:
	var elements := current_elements
	if !is_nan(time) and (time > _end_current or time < _begin_current):
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	return elements[0]


func get_eccentricity(time := NAN) -> float:
	var elements := current_elements
	if !is_nan(time) and (time > _end_current or time < _begin_current):
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	return elements[1]


func get_inclination(time := NAN) -> float:
	var elements := current_elements
	if !is_nan(time) and (time > _end_current or time < _begin_current):
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	return elements[2]


func get_longitude_of_ascending_node(time := NAN) -> float:
	var elements := current_elements
	if !is_nan(time) and (time > _end_current or time < _begin_current):
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	return elements[3]


func get_argument_of_periapsis(time := NAN) -> float:
	var elements := current_elements
	if !is_nan(time) and (time > _end_current or time < _begin_current):
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	return elements[4]


func get_mean_anomaly_at_epoch(time := NAN) -> float:
	var elements := current_elements
	if !is_nan(time) and (time > _end_current or time < _begin_current):
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	return elements[5]


func get_mean_motion(time := NAN) -> float:
	var elements := current_elements
	if !is_nan(time) and (time > _end_current or time < _begin_current):
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	return elements[6]


func get_orbit_period(time := NAN) -> float:
	var elements := current_elements
	if !is_nan(time) and (time > _end_current or time < _begin_current):
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	return TAU / elements[6]


func get_semiminor_axis(time := NAN) -> float:
	var elements := current_elements
	if !is_nan(time) and (time > _end_current or time < _begin_current):
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	var a: float = elements[0]
	var e: float = elements[1]
	return sqrt(a * a * (1.0 - e * e))


func get_characteristic_length(time := NAN) -> float:
	# For lagrange point calculation. I'm not 100% sure this is right.
	var elements := current_elements
	if !is_nan(time) and (time > _end_current or time < _begin_current):
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	var a: float = elements[0]
	var e: float = elements[1]
	return a * (1.0 - e)


func get_inclination_to_ecliptic(time := NAN) -> float:
	if reference_normal == ECLIPTIC_UP:
		return get_inclination(time)
	var orbit_normal := get_normal(time)
	return orbit_normal.angle_to(ECLIPTIC_UP)


func get_apoapsis(time := NAN) -> float:
	var elements := current_elements
	if !is_nan(time) and (time > _end_current or time < _begin_current):
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	return (1.0 + elements[1]) * elements[0] # (1 + e) * a


func get_periapsis(time := NAN) -> float:
	var elements := current_elements
	if !is_nan(time) and (time > _end_current or time < _begin_current):
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	return (1.0 - elements[1]) * elements[0] # (1 - e) * a


func is_retrograde(time := NAN) -> bool:
	var elements := current_elements
	if !is_nan(time) and (time > _end_current or time < _begin_current):
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	return elements[2] > PIdiv2 # inclination > 90 degrees


func get_orbital_perioid(time := NAN) -> float:
	var elements := current_elements
	if !is_nan(time) and (time > _end_current or time < _begin_current):
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	return TAU / elements[6]


func get_average_orbital_speed(time := NAN) -> float:
	var elements := current_elements
	if !is_nan(time) and (time > _end_current or time < _begin_current):
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	# https://en.wikipedia.org/wiki/Orbital_speed; error << 1%
	var ave_orbit_speed: float = elements[0] * elements[6] # a * n
	var e: float = elements[1]
	if e > 0.05:
		var e2 := e * e
		var e4 := e2 * e2
		var e6 := e4 * e2
		var e8 := e4 * e4
		ave_orbit_speed *= 1.0 - 0.25 * e2 - 0.046875 * e4 - 0.01953125 * e6 - 0.01068115 * e8
	return ave_orbit_speed


func get_normal(time := NAN, flip_retrograde := false) -> Vector3:
	var elements := current_elements
	if !is_nan(time) and (time > _end_current or time < _begin_current):
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	# Orbit normal is defined by Om & i. This vector precesses around the
	# reference_normal.
	var relative_normal := math.convert_spherical2(
			elements[3] + PIdiv2, elements[2] + PIdiv2) # Om, i
	var orbit_normal: Vector3
	if elements[2] > PIdiv2: # retrograde
		orbit_normal = math.rotate_vector_z(relative_normal, reference_normal)
		if flip_retrograde:
			orbit_normal *= -1.0
	else:
		orbit_normal = math.rotate_vector_z(reference_normal, relative_normal)
	return orbit_normal


# information about current position or velocity

func get_mean_anomaly(time := NAN) -> float:
	var elements := current_elements
	if is_nan(time):
		time = _times[0]
	elif time > _end_current or time < _begin_current:
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	return wrapf(elements[6] * time + elements[5], -PI, PI) # M = n * time + M0


func get_true_anomaly(time := NAN) -> float:
	var elements := current_elements
	if is_nan(time):
		time = _times[0]
	elif time > _end_current or time < _begin_current:
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	var e: float = elements[1]  # eccentricity
	var M0: float = elements[5] # mean anomaly at epoch
	var n: float = elements[6]  # mean motion
	var M := wrapf(M0 + n * time, -PI, PI) # mean anomaly
	var EA := M + e * sin(M) # eccentric anomaly
	var dEA := (EA - M - e * sin(EA)) / (1.0 - e * cos(EA))
	EA -= dEA
	while abs(dEA) > 1e-5:
		dEA = (EA - M - e * sin(EA)) / (1.0 - e * cos(EA))
		EA -= dEA
	return 2.0 * atan(sqrt((1.0 + e) / (1.0 - e)) * tan(EA / 2.0)) # nu


func get_mean_longitude(time := NAN) -> float:
	var elements := current_elements
	if is_nan(time):
		time = _times[0]
	elif time > _end_current or time < _begin_current:
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	var M: float = elements[6] * time + elements[5]
	return wrapf(M + elements[3] + elements[4], -PI, PI) # M + Om + w


func get_true_longitude(time := NAN) -> float:
	var elements := current_elements
	if is_nan(time):
		time = _times[0]
	elif time > _end_current or time < _begin_current:
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	var e: float = elements[1]  # eccentricity
	var M0: float = elements[5] # mean anomaly at epoch
	var n: float = elements[6]  # mean motion
	var M := wrapf(M0 + n * time, -PI, PI) # mean anomaly
	var EA := M + e * sin(M) # eccentric anomaly
	var dEA := (EA - M - e * sin(EA)) / (1.0 - e * cos(EA))
	EA -= dEA
	while abs(dEA) > 1e-5:
		dEA = (EA - M - e * sin(EA)) / (1.0 - e * cos(EA))
		EA -= dEA
	var nu := 2.0 * atan(sqrt((1.0 + e) / (1.0 - e)) * tan(EA / 2.0)) # nu
	return wrapf(nu + elements[3] + elements[4], -PI, PI) # nu + Om + w


func get_position(time := NAN) -> Vector3:
	var elements := current_elements
	if is_nan(time):
		time = _times[0]
	elif time > _end_current or time < _begin_current:
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	var R := get_position_from_elements(elements, time)
	if reference_normal != ECLIPTIC_UP:
		R = math.rotate_vector_z(R, reference_normal)
	return R


func get_position_velocity(time := NAN) -> Array:
	# returns [Vector3(x, y, z), Vector3(vx, vy, vz)]
	# NOT TESTED!
	var elements := current_elements
	if is_nan(time):
		time = _times[0]
	elif time > _end_current or time < _begin_current:
		elements = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_set_elements(time, elements)
	var RV := get_vectors_from_elements(elements, time)
	if reference_normal != ECLIPTIC_UP:
		RV[0] = math.rotate_vector_z(RV[0], reference_normal)
		RV[1] = math.rotate_vector_z(RV[1], reference_normal)
	return RV


func get_elements(time := NAN) -> Array:
	if !is_nan(time) and (time > _end_current or time < _begin_current):
		var elements := IVUtils.init_array(7)
		_set_elements(time, elements)
		return elements
	return current_elements.duplicate() # safe


static func get_position_from_elements(elements: Array, time: float) -> Vector3:
	# Derived from https://ssd.jpl.nasa.gov/txt/aprx_pos_planets.pdf. However,
	# we use M modifiers (b, c, s, f) to modify M0 in our dynamic orbital
	# elements (see _set_elements function) rather than modifying M here.
	# Thus, position is strictly a function of time and orbital elements.
	var a: float = elements[0]  # semi-major axis
	var e: float = elements[1]  # eccentricity
	var i: float = elements[2]  # inclination
	var Om: float = elements[3] # longitude of the ascending node
	var w: float = elements[4]  # argument of periapsis
	var M0: float = elements[5] # mean anomaly at epoch
	var n: float = elements[6]  # mean motion
	var M := wrapf(M0 + n * time, -PI, PI) # mean anomaly
	var EA := M + e * sin(M) # eccentric anomaly
	var dEA := (EA - M - e * sin(EA)) / (1.0 - e * cos(EA))
	EA -= dEA
	while abs(dEA) > 1e-5:
		dEA = (EA - M - e * sin(EA)) / (1.0 - e * cos(EA))
		EA -= dEA
	var nu := 2.0 * atan(sqrt((1.0 + e) / (1.0 - e)) * tan(EA / 2.0)) # true anomaly
	var r := a * (1.0 - e * cos(EA))
	var cos_i := cos(i)
	var sin_i := sin(i)
	var sin_Om := sin(Om)
	var cos_Om := cos(Om)
	var sin_w_nu := sin(w + nu)
	var cos_w_nu := cos(w + nu)
	var x := r * (cos_Om * cos_w_nu - sin_Om * sin_w_nu * cos_i)
	var y := r * (sin_Om * cos_w_nu + cos_Om * sin_w_nu * cos_i)
	var z := r * (sin_w_nu * sin_i)
	return Vector3(x, y, z)


static func get_vectors_from_elements(elements: Array, time: float) -> Array:
	# NOT TESTED!!!
	# returns R, V vectors
	var a: float = elements[0]  # semi-major axis
	var e: float = elements[1]  # eccentricity
	var i: float = elements[2]  # inclination
	var Om: float = elements[3] # longitude of the ascending node
	var w: float = elements[4]  # argument of periapsis
	var M0: float = elements[5] # mean anomaly at epoch
	var n: float = elements[6]  # mean motion
	var M := wrapf(M0 + n * time, -PI, PI) # mean anomaly
	var EA := M + e * sin(M) # eccentric anomaly
	var dEA := (EA - M - e * sin(EA)) / (1.0 - e * cos(EA))
	EA -= dEA
	while abs(dEA) > 1e-5:
		dEA = (EA - M - e * sin(EA)) / (1.0 - e * cos(EA))
		EA -= dEA
	var nu := 2.0 * atan(sqrt((1.0 + e) / (1.0 - e)) * tan(EA / 2.0)) # true anomaly
	var r := a * (1.0 - e * cos(EA))
	var cos_i := cos(i)
	var sin_i := sin(i)
	var sin_Om := sin(Om)
	var cos_Om := cos(Om)
	var sin_w_nu := sin(w + nu)
	var cos_w_nu := cos(w + nu)
	var x := r * (cos_Om * cos_w_nu - sin_Om * sin_w_nu * cos_i)
	var y := r * (sin_Om * cos_w_nu + cos_Om * sin_w_nu * cos_i)
	var z := r * (sin_w_nu * sin_i)
	# above copied from position function; below velocity
	var mu := n * n * a * a * a # is this exactly correct if it is a proper orbit???
	var p := a * (1.0 - e * e)
	var h := sqrt(mu * p) # specific angular momentum
	var c1 := h * e * sin(nu) / (r * p)
	var c2 := h / r
	var vx := c1 * x - c2 * (cos_Om * sin_w_nu + sin_Om * cos_w_nu * cos_i)
	var vy := c1 * y - c2 * (sin_Om * sin_w_nu - cos_Om * cos_w_nu * cos_i)
	var vz := c1 * z - c2 * (cos_w_nu * sin_i)
	return [Vector3(x, y, z), Vector3(vx, vy, vz)]


static func get_elements_from_vectors(R: Vector3, V: Vector3, mu: float, time: float) -> Array:
	# returns an elements array
	# NOT TESTED!!!
	var h_bar: Vector3 = R.cross(V)
	var h := h_bar.length()
	var r := R.length()
	var v_sq := V.length_squared()
	var En := v_sq / 2.0 - mu / r # specific energy
	var a := -mu / (2.0 * En)
	var e_sq := 1.0 - h * h / (a * mu)
	var e := sqrt(e_sq) if e_sq > 0.0 else 0.0
	var i := acos(h_bar.z / h)
	var p := a * (1.0 - e * e)
	var nu := atan2(sqrt(p / mu) * R.dot(V), p - r)
	var Om: float
	var w: float
	if i > 0.000001:
		Om = atan2(h_bar.x, -h_bar.y)
		if e > 0.000001:
			w = atan2(R.z / sin(i), R.x * Om + R.y * Om) - nu
		else:
			w = 0.0
	else:
		Om = 0.0
		if e > 0.000001:
			var e_vec = ((v_sq - mu / r) * R - R.dot(V) * V) / mu
			w = atan2(e_vec.y, e_vec.x)
			if R.cross(V).z < 0:
				w = TAU - w
		else:
			w = 0.0
	var n := sqrt(mu / a / a / a)
	var EA := 2.0 * atan(sqrt((1.0 - e) / (1.0 + e)) * tan(nu / 2.0))
	var M0 := EA - e * sin(EA) - n * time
	return [a, e, i, Om, w, M0, n]


# *****************************************************************************
# ivoyager internal mechanics & private

func disconnect_interval_update() -> void:
	if _update_interval:
		_scheduler.interval_disconnect(_update_interval, self, "_scheduler_update")


func reset_elements_and_interval_update() -> void:
	# Sets current_elements, calculates update interval for element_rates, and
	# connects or disconnects/connects to Schedular for updating.
	var time: float = _times[0]
	if !element_rates: # no update scheduling
		_set_elements(time, current_elements)
		_begin_current = -INF
		_end_current = INF
		return
	# Set _update_interval based on fastest element rate. We normalize to
	# values that are (very!) roughly analogous to "parts per second".
	var a_pps: float = abs(element_rates[0]) / IVUnits.AU
	var e_pps: float = abs(element_rates[1]) / 0.1 # arbitrary
	var i_pps: float = abs(element_rates[2]) / TAU
	var Om_pps: float = abs(element_rates[3]) / TAU
	var w_pps: float = abs(element_rates[4]) / TAU
	var max_pps: float = [a_pps, e_pps, i_pps, Om_pps, w_pps].max()
	var interval := UPDATE_TOLERANCE / max_pps
	if interval < UPDATE_LIMITER:
		# Allow up to -10% below limiter to avoid IVScheduler clumping
		interval = interval / 10.0 + UPDATE_LIMITER * 0.9
	_begin_current = time
	_end_current = time + interval * 1.1
	_set_elements(time + interval / 2.0, current_elements)
	if _update_interval != interval:
		if _update_interval: # already has a Schedular connection
			_scheduler.interval_disconnect(_update_interval, self, "_scheduler_update")
		_scheduler.interval_connect(interval, self, "_scheduler_update")
		_update_interval = interval


func orbit_sync(reference_normal_: Vector3, elements_at_epoch_: Array,
		element_rates_: Array, m_modifiers_: Array) -> void:
	reference_normal = reference_normal_
	elements_at_epoch = elements_at_epoch_
	m_modifiers = m_modifiers_
	if element_rates == element_rates_: # content test as of Godot 3.2.3!
		_set_elements(_times[0] + _update_interval / 2.0, current_elements)
	else:
		element_rates = element_rates_
		reset_elements_and_interval_update()


func _scheduler_update() -> void:
	var time: float = _times[0]
	_begin_current = time
	_end_current = time + _update_interval * 1.1
	_set_elements(time + _update_interval / 2.0, current_elements)
	emit_signal("changed", true)


func _set_elements(time: float, elements: Array) -> void:
	# elements must be size 7.
	# Based on https://ssd.jpl.nasa.gov/txt/aprx_pos_planets.pdf (time range
	# 3000 BCE - 3000 CE) except we apply Jupiter to Pluto M modifiers to
	# adjust M0 here rather than adjusting M in position calculation.
	if !element_rates: # no rates for this body or dynamic_orbits == false
		var index := 0
		while index < 7:
			elements[index] = elements_at_epoch[index]
			index += 1
		return
	# Create new elements from endogenous perturbations. We clamp time to stay
	# in the valid 3000 BCE - 3000 CE range for adjustments that are not cyclic.
	var t_clamped := clamp(time, T_3000BCE, T_3000CE)
	var a: float = elements_at_epoch[0] + element_rates[0] * t_clamped
	var e: float = elements_at_epoch[1] + element_rates[1] * t_clamped
	var i: float = elements_at_epoch[2] + element_rates[2] * t_clamped
	var Om: float = elements_at_epoch[3] + element_rates[3] * time
	var w: float = elements_at_epoch[4] + element_rates[4] * time
	# adjust M0 for Om & w to give correct M at time
	var M0: float
	if elements_at_epoch[2] > PIdiv2:
		M0 = elements_at_epoch[5] + (element_rates[3] + element_rates[4]) * time
	else:
		M0 = elements_at_epoch[5] - (element_rates[3] + element_rates[4]) * time
	var n: float = elements_at_epoch[6] # does not change
	if m_modifiers: # Jupiter, Saturn, Uranus, Neptune & Pluto only
		var b: float = m_modifiers[0]
		var c: float = m_modifiers[1]
		var s: float = m_modifiers[2]
		var f: float = m_modifiers[3]
		M0 += b * t_clamped * t_clamped # clamp this due to square
		if c != 0.0: # if so, we also have non-zero s & f
			M0 += c * cos(f * time) + s * sin(f * time) # safe unclamped
	# standardize wrap range
	i = wrapf(i, -PI, PI)
	Om = wrapf(Om, 0.0, TAU)
	w = wrapf(w, 0.0, TAU)
	M0 = wrapf(M0, 0.0, TAU)
	elements[0] = a
	elements[1] = e
	elements[2] = i
	elements[3] = Om
	elements[4] = w
	elements[5] = M0
	elements[6] = n
