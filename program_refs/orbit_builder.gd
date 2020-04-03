# orbit_builder.gd
# This file is part of I, Voyager
# https://ivoyager.dev
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
#

extends Reference
class_name OrbitBuilder

const math := preload("res://ivoyager/static/math.gd") # =Math when issue #37529 fixed

#const MIN_APSIDAL_OR_NODAL_PERIOD := 1.0
const MIN_E_FOR_APSIDAL_PRECESSION := 0.0001
const MIN_I_FOR_NODAL_PRECESSION := deg2rad(0.1)
const UPDATE_ORBIT_TOLERANCE := 0.0002
const DPRINT := false

var _scale: float = Global.scale
var _dynamic_orbits: bool = Global.dynamic_orbits
var _Orbit_: Script

func project_init() -> void:
	_Orbit_ = Global.script_classes._Orbit_

func make_orbit_from_data(data: Dictionary, parent: Body, mu: float, time: float) -> Orbit:
	assert(DPRINT and prints("make_orbit_from_data", tr(data.key), parent, mu, time) or true)
	# This is messy because every kind of astronomical body and source uses a
	# different parameterization of the 6 Keplarian orbital elements. We
	# translate table data to a common set of 6(+1) elements for sim use:
	#  [0] a,  semimajor axis (in km * scale) [TODO: allow negative for hyperbolic!]
	#  [1] e,  eccentricity (0.0 - 1.0)
	#  [2] i,  inclination (rad)
	#  [3] Om, longitude of the ascending node (rad)
	#  [4] w,  argument of periapsis (rad)
	#  [5] M0, mean anomaly at epoch (rad)
	#  [6] n,  mean motion (rad/day)
	#
	# Elements 0-5 completely define an *unperturbed* orbit assuming we know mu
	# (= G * Mass of parent body). Mean motion (n) is kept for convinience and
	# for cases where we have "proper orbits" (a synthetic orbit accounting
	# for perturbations that is stable over millions of years).
	#
	# TODO: Deal with moons (!) that have weird epoch: transform all to J2000.
	#
	# TODO: 
	# We should find a planet data source valid outside of 3000BC-3000AD.
	# Then we can implement 3 user options for planet data: "1800-2050AD (most
	# accurate now)", "3000BC-3000AD", "millions of years (least accurate now)".
	# For now, everything is calculated for 3000BC-3000AD range and (TODO:) we
	# stop applying a, e, i rates outside of 3000BC-3000AD.
	# Or better, dynamically fit to either 1800-2050AD or 3000BC-3000AD range.
	# Alternatively, we could build orbit from an Ephemerides object.
	
	var orbit := _make_orbit()
	var elements := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var element_rates: Array # optional
	var m_modifiers: Array # optional
	
	# Keplerian elements
	elements[0] = data.a * _scale
	elements[1] = data.e
	elements[2] = data.i
	elements[3] = data.Om
	if data.has("w"):
		elements[4] = data.w
	else: # table must have w or w_hat
		elements[4] = data.w_hat - data.Om
	if data.has("n"):
		elements[6] = data.n
	elif data.has("L_rate"): # planet tables (rad / century after load conversion)
		# Note: "L_rate" is NOT an element rate! It's just n in disguise.
		elements[6] = math.day2year(data.L_rate) / 100.0
	else: # calculate n
		elements[6] = sqrt(mu / pow(elements[0], 3)) # n = sqrt(mu/(a^3))
	if data.has("M0"):
		elements[5] = data.M0
	elif data.has("L0"):
		elements[5] = data.L0 - elements[4] - elements[3] # M0 = L0 - w - Om
	else: # table must have "T0" if it doesn't have "M0" or "L0"
		elements[5] = -elements[6] * data.T0 # M0 = -n * T0
	
	# Element rates are optional. For planets, we get these as "x_rate" for
	# a, e, i, Om & w (but not "L_rate", which is just n).
	# For moons, we get these as Pw (nodal period) and Pnode (apsidal period),
	# corresponding to rotational period of Om & w, respectively [TODO: in
	# asteroid data, these are g & s, I think...].
	# We test that rate info (if given) matches one or the other format.
	var format_test := int(data.has("a_rate")) + int(data.has("e_rate")) + int(data.has("i_rate")) \
			+ int(data.has("w_rate")) + int(data.has("Om_rate"))
	if format_test == 5: # planet format
		element_rates = [
			data.a_rate * _scale,
			data.e_rate,
			data.i_rate,
			data.Om_rate,
			data.w_rate
			]
		# M modifiers are additional modifiers for Jupiter to Pluto.
		if data.has("M_adj_b"):
			m_modifiers = [
				data.M_adj_b,
				data.M_adj_c,
				data.M_adj_s,
				data.M_adj_f
				]
	elif data.has("Pw") and data.has("Pnode"): # moon format
		# Some values are tiny leading to div/0 or excessive updating. These
		# correspond to near-circular and/or non-inclined orbits (where Om & w
		# are technically undefined and updates are irrelevant).
		var Pnode := 0.0 # nodal precession
		var Pw := 0.0 # apsidal precession
		if elements[2] > MIN_I_FOR_NODAL_PRECESSION:
			Pnode = data.Pnode
		if elements[1] > MIN_E_FOR_APSIDAL_PRECESSION:
			Pw = data.Pw
		if Pw != 0.0 or Pnode != 0.0:
			element_rates = [
				0.0,
				0.0,
				0.0,
				100.0 * TAU / Pnode if Pnode > 0.0 else 0.0, # Om_rate
				100.0 * TAU / Pw if Pw > 0.0 else 0.0 # w_rate
				]
	else: # no rates or format error
		assert(format_test == 0)
		assert(!data.has("Pw") and !data.has("Pnode"))
		
	if element_rates and _dynamic_orbits:
		# Set update_frequency based on fastest element rate. We normalize to
		# values roughly meaning "parts per century".
		var a_ppc: float = element_rates[0] / elements[0]
		var e_ppc: float = element_rates[1]
		var i_ppc: float = element_rates[2] / TAU
		var Om_ppc: float = element_rates[3] / TAU
		var w_ppc: float = element_rates[4] / TAU
		var max_ppc = [a_ppc, e_ppc, i_ppc, Om_ppc, w_ppc].max()
		orbit.update_frequency = max_ppc / (UPDATE_ORBIT_TOLERANCE * 36525.0) # per day (mostly << 1)
#		if orbit.update_frequency > 1.0:
#			prints("update_frequency", tr(data.key), orbit.update_frequency)
		assert(DPRINT and prints("update_frequency", tr(data.key), orbit.update_frequency) or true)

	if data.has("ref_plane"): # many moon orbits use non-ecliptic reference plane
		if data.ref_plane == "Equatorial":
			orbit.reference_normal = parent.north_pole
		elif data.ref_plane == "Laplace":
			orbit.reference_normal = math.convert_equatorial_coordinates(data.orbit_RA, data.orbit_dec)
			orbit.reference_normal = Global.ecliptic_rotation * orbit.reference_normal
			orbit.reference_normal = orbit.reference_normal.normalized()
		else:
			assert(data.ref_plane == "Ecliptic") # default

	orbit.elements_at_epoch = elements
	if element_rates and _dynamic_orbits:
		orbit.element_rates = element_rates
		if m_modifiers:
			orbit.m_modifiers = m_modifiers

	return orbit

func _make_orbit() -> Orbit:
	var orbit: Orbit = _Orbit_.new()
	return orbit
