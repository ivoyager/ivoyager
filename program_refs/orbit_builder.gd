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
	a_rate = "a_rate",
	e_rate = "e_rate",
	i_rate = "i_rate",
	Om_rate = "Om_rate",
	w_rate = "w_rate",
	M_adj_b = "M_adj_b",
	M_adj_c = "M_adj_c",
	M_adj_s = "M_adj_s",
	M_adj_f = "M_adj_f",
	Pw = "Pw",
	Pnode = "Pnode",
	ref_plane = "ref_plane"
}
var req_data := ["a", "e", "i", "Om"]
var ninf_resets := ["w", "w_hat", "M0", "L0", "T0", "n", "L_rate", "a_rate", "e_rate", "i_rate",
	"Om_rate", "w_rate", "M_adj_b", "M_adj_c", "M_adj_s", "M_adj_f", "Pw", "Pnode"]

# import data values
var a := -INF
var e := -INF
var i := -INF
var Om := -INF
var w := -INF
var w_hat := -INF
var M0 := -INF
var L0 := -INF
var T0 := -INF
var n := -INF
var L_rate := -INF
var a_rate := -INF
var e_rate := -INF
var i_rate := -INF
var Om_rate := -INF
var w_rate := -INF
var M_adj_b := -INF
var M_adj_c := -INF
var M_adj_s := -INF
var M_adj_f := -INF
var Pw := -INF
var Pnode := -INF
var ref_plane := ""

var _table_helper: TableHelper
var _Orbit_: Script
var _dynamic_orbits: bool


func project_init() -> void:
	_table_helper = Global.program.TableHelper
	_Orbit_ = Global.script_classes._Orbit_
	_dynamic_orbits = Global.dynamic_orbits

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
	
	_table_helper.build_object(self, row_data, fields, data_parser, req_data)
	# standardize orbital elements to: a, e, i, Om, w, M0, n
	var mu := parent.gm
	if w == -INF:
		assert(w_hat != -INF)
		w = w_hat - Om
	if n == -INF:
		if L_rate != -INF:
			n = L_rate
		else:
			n = sqrt(mu / (a * a * a))
	if M0 == -INF:
		if L0 != -INF:
			M0 = L0 - w - Om
		elif T0 != -INF:
			M0 = -n * T0
		else:
			assert(false, "Elements must include M0, L0 or T0")
	var elements := [a, e, i, Om, w, M0, n]
	var orbit: Orbit = _Orbit_.new()
	orbit.elements_at_epoch = elements
	
	if _dynamic_orbits:
		# Element rates are optional. For planets, we get these as "x_rate" for
		# a, e, i, Om & w (however, L_rate is just n!).
		# For moons, we get these as Pw (nodal period) and Pnode (apsidal period),
		# corresponding to rotational period of Om & w, respectively [TODO: in
		# asteroid data, these are g & s, I think...].
		# Rate info (if given) must matches one or the other format.
		var element_rates: Array # optional
		var m_modifiers: Array # optional
		if a_rate != -INF: # is planet w/ rates
			element_rates = [a_rate, e_rate, i_rate, Om_rate, w_rate]
			assert(element_rates.min() != -INF) # all rates present
			# M modifiers are additional modifiers for Jupiter to Pluto.
			if M_adj_b != -INF: # must also have c, s, f
				m_modifiers = [M_adj_b, M_adj_c, M_adj_s, M_adj_f]
				assert(m_modifiers.min() != null) # all present
		elif Pw != -INF: # moon format
			assert(Pnode != -INF) # both or neither
			# Some values are tiny leading to div/0 or excessive updating. These
			# correspond to near-circular and/or non-inclined orbits (where Om & w
			# are technically undefined and updates are irrelevant).
			if elements[2] < MIN_I_FOR_NODAL_PRECESSION:
				Pnode = 0.0
			if elements[1] < MIN_E_FOR_APSIDAL_PRECESSION:
				Pw = 0.0
			if Pw != 0.0 or Pnode != 0.0:
				Om_rate = TAU / Pnode if Pnode > 0.0 else 0.0
				w_rate = TAU / Pw if Pw > 0.0 else 0.0
				element_rates = [0.0, 0.0, 0.0, Om_rate, w_rate]
		if element_rates:
			orbit.element_rates = element_rates
			if m_modifiers:
				orbit.m_modifiers = m_modifiers
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

	# reference plane (moons!)
	if ref_plane == "Equatorial":
		orbit.reference_normal = parent.north_pole
	elif ref_plane == "Laplace":
		orbit.reference_normal = math.convert_equatorial_coordinates2(
				row_data[fields.orbit_RA], row_data[fields.orbit_dec])
		orbit.reference_normal = Global.ecliptic_rotation * orbit.reference_normal
		orbit.reference_normal = orbit.reference_normal.normalized()
	elif ref_plane:
		assert(ref_plane == "Ecliptic")
	# reset for next orbit build
	for property in ninf_resets:
		set(property, -INF)
	ref_plane = ""
	return orbit
