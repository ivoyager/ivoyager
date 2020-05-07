# orbit.gd
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
# Orbit info is kept in standardized arrays of fixed size. reference_normal is
# normal to the reference plane (ecliptic, equatorial or specified Laplace
# plane; many moons use the latter two); the "orbit normal" precesses around
# the reference_normal. See orbit_builder.gd for construction.
#
# See static/unit_defs.gd for base units.
#
# This is our first candidate for porting to GDNative!

class_name Orbit

const math := preload("res://ivoyager/static/math.gd") # =Math when issue #37529 fixed

signal changed_for_graphics() # does not signal if no one is looking!

const DPRINT := false
const FLUSH_AT_N_MEMOIZED := 200
const ECLIPTIC_UP := Vector3(0.0, 0.0, 1.0)
const T_3000BCE := -50.0 * UnitDefs.CENTURY # 3000 BCE
const T_3000CE := 10.0 * UnitDefs.CENTURY # 3000 CE

# persisted
var reference_normal := ECLIPTIC_UP # moons are often different
var elements_at_epoch: Array # [a, e, i, Om, w, M0, n]; required
var element_rates: Array # [a, e, i, Om, w]; optional
var m_modifiers: Array # [b, c, s, f] for planets Jupiter to Pluto only
var update_frequency: float # based on fastest changing element_rates

# persistence
const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["reference_normal", "elements_at_epoch", "element_rates",
	"m_modifiers", "update_frequency"]
const PERSIST_OBJ_PROPERTIES := []

# vars below are for memoization
var _times: Array = Global.times
var _present_time_index := -INF
var _present_elements := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _future_elements := {}
var _flush_indexes := []

func get_semimajor_axis(time: float) -> float:
	# returns scaled value, not km!
	var elements := _get_elements(time)
	return elements[0]

func get_inclination(time: float) -> float:
	var elements := _get_elements(time)
	return elements[2]

func get_mean_motion(time: float) -> float:
	var elements := _get_elements(time)
	return elements[6]

func is_retrograde(time: float) -> bool:
	var elements := _get_elements(time)
	return elements[2] > PI / 2.0 # inclination > 90 degrees

func get_normal(time: float) -> Vector3:
	# Orbit normal is specified by "rotation" elements Om & i. This vector
	# precesses around the reference_normal.
	var elements := _get_elements(time)
	var relative_normal := math.convert_equatorial_coordinates2(
			elements[3] + PI / 2.0, elements[2] + PI / 2.0) # Om, i
	var orbit_normal: Vector3
	if elements[2] > PI / 2.0: # retrograde
		orbit_normal = -math.rotate_vector_pole(relative_normal, reference_normal)
	else:
		orbit_normal = math.rotate_vector_pole(reference_normal, relative_normal)
	return orbit_normal

func get_mean_anomaly(time: float) -> float:
	var elements := _get_elements(time)
	return wrapf(elements[6] * time + elements[5], -PI, PI) # M = n * time + M0
	
func get_anomaly_for_camera(time: float) -> float:
	var elements := _get_elements(time)
	var M: float = elements[6] * time + elements[5] # M = n * time + M0
	var Om: float = elements[3]
	var w: float = elements[4]
	var anomaly := wrapf(M + Om + w, -PI, PI)
	if elements[2] > PI / 2.0:
		return -anomaly
	return anomaly

func get_position(time: float) -> Vector3:
	# returns Vector3(x, y, z)
	var elements := _get_elements(time)
	var R := get_position_from_elements(elements, time)
	if reference_normal != ECLIPTIC_UP:
		R = math.rotate_vector_pole(R, reference_normal)
	return R

func get_vectors(time: float) -> Array:
	# returns [Vector3(x, y, z), Vector3(vx, vy, vz)]
	# NOT TESTED!
	var elements := _get_elements(time)
	var RV := get_vectors_from_elements(elements, time)
	if reference_normal != ECLIPTIC_UP:
		RV[0] = math.rotate_vector_pole(RV[0], reference_normal)
		RV[1] = math.rotate_vector_pole(RV[1], reference_normal)
	return RV

func get_elements(time: float) -> Array:
	var elements := _get_elements(time)
	return elements.duplicate() # safe

static func get_position_from_elements(elements: Array, time: float) -> Vector3:
	# Derived from https://ssd.jpl.nasa.gov/txt/aprx_pos_planets.pdf. However,
	# we use M modifiers (b, c, s, f) to modify M0 in our dynamic orbital
	# elements (see _get_elements function) rather than modifying M here. Thus,
	# position is strictly a function of time and orbital elements.
	var a: float = elements[0]  # semi-major axis
	var e: float = elements[1]  # eccentricity
	var i: float = elements[2]  # inclination
	var Om: float = elements[3] # longitude of the ascending node
	var w: float = elements[4]  # argument of periapsis
	var M0: float = elements[5] # mean anomaly at epoch
	var n: float = elements[6]  # mean motion
	var M := wrapf(M0 + n * time, -PI, PI) # mean anomaly
	var E := M + e * sin(M) # eccentric anomaly
	var dE := (E - M - e * sin(E)) / (1.0 - e * cos(E))
	E -= dE
	while abs(dE) > 1e-5:
		dE = (E - M - e * sin(E)) / (1.0 - e * cos(E))
		E -= dE
	var nu := 2.0 * atan(sqrt((1.0 + e) / (1.0 - e)) * tan(E / 2.0)) # true anomaly
	var r := a * (1.0 - e * cos(E))
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
	# first part copied from above for speed
	var a: float = elements[0]  # semi-major axis
	var e: float = elements[1]  # eccentricity
	var i: float = elements[2]  # inclination
	var Om: float = elements[3] # longitude of the ascending node
	var w: float = elements[4]  # argument of periapsis
	var M0: float = elements[5] # mean anomaly at epoch
	var n: float = elements[6]  # mean motion
	var M := wrapf(M0 + n * time, -PI, PI) # mean anomaly
	var E := M + e * sin(M) # eccentric anomaly
	var dE := (E - M - e * sin(E)) / (1.0 - e * cos(E))
	E -= dE
	while abs(dE) > 1e-5:
		dE = (E - M - e * sin(E)) / (1.0 - e * cos(E))
		E -= dE
	var nu := 2.0 * atan(sqrt((1.0 + e) / (1.0 - e)) * tan(E / 2.0)) # true anomaly
	var r := a * (1.0 - e * cos(E))
	var cos_i := cos(i)
	var sin_i := sin(i)
	var sin_Om := sin(Om)
	var cos_Om := cos(Om)
	var sin_w_nu := sin(w + nu)
	var cos_w_nu := cos(w + nu)
	var x := r * (cos_Om * cos_w_nu - sin_Om * sin_w_nu * cos_i)
	var y := r * (sin_Om * cos_w_nu + cos_Om * sin_w_nu * cos_i)
	var z := r * (sin_w_nu * sin_i)
	# non-copied code below
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
	var E := 2.0 * atan(sqrt((1.0 - e) / (1.0 + e)) * tan(nu / 2.0))
	var M0 := E - e * sin(E) - n * time
	return [a, e, i, Om, w, M0, n]

func _get_elements(time: float) -> Array:
	# WARNING! This function returns the same array (modified) on subsequent
	# calls! Duplicate it if you need a stable result.
	#
	# Also, THIS FUNCTION HAS SIDE-EFFECTS! We take advantage of the knowledge
	# that *someone is looking* to signal "changed_for_graphics" (intended for
	# graphic hookup only!) if we are changing present-time elements.
	#
	# Based on https://ssd.jpl.nasa.gov/txt/aprx_pos_planets.pdf (time range
	# 3000 BCE - 3000 CE) except we apply Jupiter to Pluto M modifiers to
	# adjust M0 here rather than adjusting M in position calculation.
	if !element_rates: # no rates for this body or dynamic_orbits == false
		return elements_at_epoch
	# Return memoized result if we have it.
	var time_index := round(time * update_frequency) # rounded float!
	if time_index == _present_time_index:
		return _present_elements # this is the vast majority of calls!
	var present_time_index := round(_times[0] * update_frequency)
	var is_present := time_index == present_time_index # time is close to current 
	if is_present:
		_present_time_index = present_time_index
	if _future_elements.has(time_index):
		if is_present:
			_present_elements = _future_elements[time_index]
			_future_elements.erase(time_index)
			emit_signal("changed_for_graphics") # may cause repeat call!
			return _present_elements
		else:
			return _future_elements[time_index] # caller not asking for "now"
	# Create new elements for this time index. We clamp time to stay in the
	# valid 3000 BCE - 3000 CE range for adjustments that are not precessions.
	var t := time_index / update_frequency # indexed time
	var t_clamped := clamp(t, T_3000BCE, T_3000CE)
	var a: float = elements_at_epoch[0] + element_rates[0] * t_clamped
	var e: float = elements_at_epoch[1] + element_rates[1] * t_clamped
	var i: float = elements_at_epoch[2] + element_rates[2] * t_clamped
	var Om: float = elements_at_epoch[3] + element_rates[3] * t
	var w: float = elements_at_epoch[4] + element_rates[4] * t
	# M is relative to Om & w, so we need to deduct Om & w changes from M0
	var M0: float = elements_at_epoch[5] - (element_rates[3] + element_rates[4]) * t
	var n: float = elements_at_epoch[6] # does not change
	if m_modifiers: # Jupiter, Saturn, Uranus, Neptune & Pluto only
		var b: float = m_modifiers[0]
		var c: float = m_modifiers[1]
		var s: float = m_modifiers[2]
		var f: float = m_modifiers[3]
		M0 += b * t_clamped * t_clamped # clamp this due to square
		if c != 0.0: # if so, we also have non-zero s & f
			M0 += c * cos(f * t) + s * sin(f * t) # safe unclamped
	i = wrapf(i, -PI, PI)
	Om = wrapf(Om, 0.0, TAU)
	w = wrapf(w, 0.0, TAU)
	M0 = wrapf(M0, 0.0, TAU)
	# if present time, adjust and return _present_elements
	if is_present:
		_present_elements[0] = a
		_present_elements[1] = e
		_present_elements[2] = i
		_present_elements[3] = Om
		_present_elements[4] = w
		_present_elements[5] = M0
		_present_elements[6] = n
		emit_signal("changed_for_graphics") # may trigger repeat call!
		return _present_elements
	# Non-extended I, Voyager never reaches code below. We get here if we are
	# asking for elements from non-present time. If future, we memoize in
	# _future_elements.
	var elements := [a, e, i, Om, w, M0, n]
	if time_index < present_time_index: # past, don't memoize
		return elements
	# flush _future_elements if needed
	if _future_elements.size() > FLUSH_AT_N_MEMOIZED: # this is rare
		for key in _future_elements:
			if key < present_time_index:
				_flush_indexes.append(key)
		# warning-ignore:integer_division
		if _flush_indexes.size() > FLUSH_AT_N_MEMOIZED / 2:
			# it should usually be sufficient to flush past only
			for key in _flush_indexes:
				_future_elements.erase(key)
		else: # for some reason we have very many future elements
			_future_elements.clear()
		_flush_indexes.clear()
	# memoize and return
	_future_elements[time_index] = elements
	return elements
