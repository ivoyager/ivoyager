# orbit_builder.gd
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

class_name OrbitBuilder

const math := preload("res://ivoyager/static/math.gd") # =Math when issue #37529 fixed

const DPRINT := false
const MIN_E_FOR_APSIDAL_PRECESSION := 0.0001
const MIN_I_FOR_NODAL_PRECESSION := deg2rad(0.1)

var t := {
	a = NAN,
	e = NAN,
	i = NAN,
	Om = NAN,
	w = NAN,
	w_hat = NAN,
	M0 = NAN,
	L0 = NAN,
	T0 = NAN,
	n = NAN,
	L_rate = NAN,
	a_rate = NAN,
	e_rate = NAN,
	i_rate = NAN,
	Om_rate = NAN,
	w_rate = NAN,
	M_adj_b = NAN,
	M_adj_c = NAN,
	M_adj_s = NAN,
	M_adj_f = NAN,
	Pw = NAN,
	Pnode = NAN,
	ref_plane = "",
}

var _table_reader: TableReader
var _Orbit_: Script
var _dynamic_orbits: bool

func make_orbit_from_data(table_name: String, table_row: int, parent: Body) -> Orbit:
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
	
	var mu := parent.get_std_gravitational_parameter()
	assert(mu)
	_table_reader.build_dictionary_from_keys(t, table_name, table_row)

	# convert to standardized orbital elements [a, e, i, Om, w, M0, n]
	if is_nan(t.w):
		assert(!is_nan(t.w_hat))
		t.w = t.w_hat - t.Om
	if is_nan(t.n):
		if !is_nan(t.L_rate):
			t.n = t.L_rate
		else:
			t.n = sqrt(mu / pow(t.a, 3))
	if is_nan(t.M0):
		if !is_nan(t.L0):
			t.M0 = t.L0 - t.w - t.Om
		elif !is_nan(t.T0):
			t.M0 = -t.n * t.T0
		else:
			assert(false, "Elements must include M0, L0 or T0")
	var elements := [t.a, t.e, t.i, t.Om, t.w, t.M0, t.n]
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
		if !is_nan(t.a_rate): # is planet w/ rates
			element_rates = [t.a_rate, t.e_rate, t.i_rate, t.Om_rate, t.w_rate]
			assert(!is_nan(t.e_rate) && !is_nan(t.i_rate) && !is_nan(t.Om_rate) && !is_nan(t.w_rate))
			# M modifiers are additional modifiers for Jupiter to Pluto.
			if !is_nan(t.M_adj_b): # must also have c, s, f
				m_modifiers = [t.M_adj_b, t.M_adj_c, t.M_adj_s, t.M_adj_f]
				assert(!is_nan(t.M_adj_c) && !is_nan(t.M_adj_s) && !is_nan(t.M_adj_f))
		elif !is_nan(t.Pw): # moon format
			assert(!is_nan(t.Pnode)) # both or neither
			# Pw, Pnode don't tell us the direction of precession! However, I
			# believe that it is always the case that Pw is in the direction of
			# orbit and Pnode is in the opposite direction.
			# Some values are tiny leading to div/0 or excessive updating. These
			# correspond to near-circular and/or non-inclined orbits (where Om & w
			# are technically undefined and updates are irrelevant).
			if elements[2] < MIN_I_FOR_NODAL_PRECESSION:
				t.Pnode = 0.0
			if elements[1] < MIN_E_FOR_APSIDAL_PRECESSION:
				t.Pw = 0.0
			var orbit_sign := sign(PI / 2.0 - t.i) # prograde +1; retrograde -1
			t.Om_rate = 0.0
			t.w_rate = 0.0
			if t.Pnode != 0.0:
				t.Om_rate = -orbit_sign * TAU / t.Pnode # opposite to orbit!
			if t.Pw != 0.0:
				t.w_rate = orbit_sign * TAU / t.Pw
			if t.Om_rate or t.w_rate:
				element_rates = [0.0, 0.0, 0.0, t.Om_rate, t.w_rate]
		if element_rates:
			orbit.element_rates = element_rates
			if m_modifiers:
				orbit.m_modifiers = m_modifiers
				
	# reference plane (moons!)
	if t.ref_plane == "Equatorial":
		orbit.reference_normal = parent.get_positive_pole()
	elif t.ref_plane == "Laplace":
		var orbit_ra: float = _table_reader.get_real(table_name, "orbit_RA", table_row)
		var orbit_dec: float = _table_reader.get_real(table_name, "orbit_dec", table_row)
		orbit.reference_normal = math.convert_spherical2(orbit_ra, orbit_dec)
		orbit.reference_normal = Global.ecliptic_rotation * orbit.reference_normal
		orbit.reference_normal = orbit.reference_normal.normalized()
	elif t.ref_plane:
		assert(t.ref_plane == "Ecliptic")
	# reset for next orbit build
	_reset_table_dict()
	return orbit

# *****************************************************************************

func _project_init() -> void:
	_table_reader = Global.program.TableReader
	_Orbit_ = Global.script_classes._Orbit_
	_dynamic_orbits = Global.dynamic_orbits

func _reset_table_dict() -> void:
	for field in t:
		if field != "ref_plane":
			t[field] = NAN
	t.ref_plane = ""
