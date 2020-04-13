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
# Be carful to test for table nulls explicitly! (0.0 != null)

extends Reference
class_name OrbitBuilder

const math := preload("res://ivoyager/static/math.gd") # =Math when issue #37529 fixed

const DPRINT := false
#const MIN_APSIDAL_OR_NODAL_PERIOD := 1.0
const MIN_E_FOR_APSIDAL_PRECESSION := 0.0001
const MIN_I_FOR_NODAL_PRECESSION := deg2rad(0.1)
const UPDATE_ORBIT_TOLERANCE := 0.0002

var data_parser := { # property = table_field
	a = "a",
	e = "e",
	i = "i",
	Om = "Om",
	w = "w",
	w_hat = "w_hat",
	M0 = "M0",
	L0 = "L0",
	T0 = "T0",
	n = "n",
	L_rate = "L_rate",
#	a = "a",
#	a = "a",
#	a = "a",
}
var required_data := ["a", "e", "i", "Om"]

# import data values
var a := 0.0
var e := 0.0
var i := 0.0
var Om := 0.0
var w := -INF
var w_hat := -INF
var M0 := -INF
var L0 := -INF
var T0 := -INF

var _resets := ["w", "w_hat", "M0", "L0", "T0", "", "", "", "", ""]

var _dynamic_orbits: bool = Global.dynamic_orbits
var _Orbit_: Script

func project_init() -> void:
	_Orbit_ = Global.script_classes._Orbit_

func make_orbit_from_data(parent: Body, row_data: Array, fields: Dictionary, time: float) -> Orbit:
	assert(DPRINT and prints("make_orbit_from_data", tr(row_data[0]), parent, time) or true)
	# This is messy because every kind of astronomical body and source uses a
	# different parameterization of the 6 Keplarian orbital elements. We
	# translate table data to a common set of 6(+1) elements for sim use:
	#  [0] a,  semimajor axis (in UnitDef.KM) [TODO: allow negative for hyperbolic!]
	#  [1] e,  eccentricity (0.0 - 1.0)
	#  [2] i,  inclination (rad)
	#  [3] Om, longitude of the ascending node (rad)
	#  [4] w,  argument of periapsis (rad)
	#  [5] M0, mean anomaly at epoch (rad)
	#  [6] n,  mean motion (rad/s)
	#
	# Elements 0-5 completely define an *unperturbed* orbit assuming we know mu
	# (= GM of parent body). Mean motion (n) is kept for convinience and
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
	var mu := parent.gm
	var elements := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var element_rates: Array # optional
	var m_modifiers: Array # optional
	
	# Keplerian elements
	elements[0] = row_data[fields.a]
	elements[1] = row_data[fields.e]
	elements[2] = row_data[fields.i]
	elements[3] = row_data[fields.Om]
	if fields.has("w") and row_data[fields.w] != null:
		elements[4] = row_data[fields.w]
	else: # table must have w or w_hat
		elements[4] = row_data[fields.w_hat] - elements[3] # w = w_hat - Om
	if fields.has("n") and row_data[fields.n] != null:
		elements[6] = row_data[fields.n]
	elif fields.has("L_rate") and row_data[fields.L_rate] != null: # planet tables
		# Note: "L_rate" is NOT an element rate! It's just n in disguise.
		elements[6] = row_data[fields.L_rate]
	else: # calculate n
		elements[6] = sqrt(mu / pow(elements[0], 3.0)) # n = sqrt(mu/(a^3))
	if fields.has("M0") and row_data[fields.M0] != null:
		elements[5] = row_data[fields.M0]
	elif fields.has("L0") and row_data[fields.L0] != null:
		elements[5] = row_data[fields.L0] - elements[4] - elements[3] # M0 = L0 - w - Om
	else: # table must have "T0" if it doesn't have "M0" or "L0"
		elements[5] = -elements[6] * row_data[fields.T0] # M0 = -n * T0
	
	# Element rates are optional. For planets, we get these as "x_rate" for
	# a, e, i, Om & w (but not "L_rate", which is just n).
	# For moons, we get these as Pw (nodal period) and Pnode (apsidal period),
	# corresponding to rotational period of Om & w, respectively [TODO: in
	# asteroid data, these are g & s, I think...].
	# Rate info (if given) must matches one or the other format.
	if fields.has("a_rate") and row_data[fields.a_rate] != null: # is planet w/ rates
		element_rates = [
			row_data[fields.a_rate],
			row_data[fields.e_rate],
			row_data[fields.i_rate],
			row_data[fields.Om_rate],
			row_data[fields.w_rate]
			]
		assert(element_rates.max() != null) # checks all rates present
		# M modifiers are additional modifiers for Jupiter to Pluto.
		if fields.has("M_adj_b") and row_data[fields.M_adj_b]: # must also have c, s, f
			m_modifiers = [
				row_data[fields.M_adj_b],
				row_data[fields.M_adj_c],
				row_data[fields.M_adj_s],
				row_data[fields.M_adj_f]
				]
			assert(m_modifiers.max() != null)
	elif fields.has("Pw") and fields.has("Pnode"): # moon format
		# Some values are tiny leading to div/0 or excessive updating. These
		# correspond to near-circular and/or non-inclined orbits (where Om & w
		# are technically undefined and updates are irrelevant).
		var Pnode := 0.0 # nodal precession
		var Pw := 0.0 # apsidal precession
		if elements[2] > MIN_I_FOR_NODAL_PRECESSION:
			Pnode = row_data[fields.Pnode]
		if elements[1] > MIN_E_FOR_APSIDAL_PRECESSION:
			Pw = row_data[fields.Pw]
		if Pw != 0.0 or Pnode != 0.0:
			element_rates = [
				0.0,
				0.0,
				0.0,
				TAU / Pnode if Pnode > 0.0 else 0.0, # Om_rate
				TAU / Pw if Pw > 0.0 else 0.0 # w_rate
				]
	else: # no rates or format error
		assert(!fields.has("Pw") and !fields.has("Pnode"))
		
	if element_rates and _dynamic_orbits:
		# Set update_frequency based on fastest element rate. We normalize to
		# values roughly meaning "parts per second".
		var a_pps: float = element_rates[0] / elements[0]
		var e_pps: float = element_rates[1] / 0.1 # arbitrary
		var i_pps: float = element_rates[2] / TAU
		var Om_pps: float = element_rates[3] / TAU
		var w_pps: float = element_rates[4] / TAU
		var max_pps = [a_pps, e_pps, i_pps, Om_pps, w_pps].max()
		orbit.update_frequency = max_pps / UPDATE_ORBIT_TOLERANCE # 1/s (tiny!)
		assert(DPRINT and prints("update_frequency", tr(row_data[0]), orbit.update_frequency) or true)

	if fields.has("ref_plane") and row_data[fields.ref_plane] != null: # many moons
		if row_data[fields.ref_plane] == "Equatorial":
			orbit.reference_normal = parent.north_pole
		elif row_data[fields.ref_plane] == "Laplace":
			orbit.reference_normal = math.convert_equatorial_coordinates(
					row_data[fields.orbit_RA], row_data[fields.orbit_dec])
			orbit.reference_normal = Global.ecliptic_rotation * orbit.reference_normal
			orbit.reference_normal = orbit.reference_normal.normalized()
		else:
			assert(row_data[fields.ref_plane] == "Ecliptic")

	orbit.elements_at_epoch = elements
	if element_rates and _dynamic_orbits:
		orbit.element_rates = element_rates
		if m_modifiers:
			orbit.m_modifiers = m_modifiers

	return orbit

func _make_orbit() -> Orbit:
	var orbit: Orbit = _Orbit_.new()
	return orbit
