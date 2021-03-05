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
# Be carful to test for table nulls explicitly! (0.0 != null)

extends Reference
class_name OrbitBuilder

const math := preload("res://ivoyager/static/math.gd") # =Math when issue #37529 fixed

const DPRINT := false
#const MIN_APSIDAL_OR_NODAL_PERIOD := 1.0
const MIN_E_FOR_APSIDAL_PRECESSION := 0.0001
const MIN_I_FOR_NODAL_PRECESSION := deg2rad(0.1)

#const UPDATE_ORBIT_TOLERANCE := 0.0002
#var update_frequency_limitor := 1.0 / UnitDefs.HOUR # up to +10% to prevent schedular clumping

var property_fields := {
	# property = table_field
	_a = "a",
	_e = "e",
	_i = "i",
	_Om = "Om",
	_w = "w",
	_w_hat = "w_hat",
	_M0 = "M0",
	_L0 = "L0",
	_T0 = "T0",
	_n = "n",
	_L_rate = "L_rate",
	_a_rate = "a_rate",
	_e_rate = "e_rate",
	_i_rate = "i_rate",
	_Om_rate = "Om_rate",
	_w_rate = "w_rate",
	_M_adj_b = "M_adj_b",
	_M_adj_c = "M_adj_c",
	_M_adj_s = "M_adj_s",
	_M_adj_f = "M_adj_f",
	_Pw = "Pw",
	_Pnode = "Pnode",
	_ref_plane = "ref_plane"
}

# import data values
var _a := NAN
var _e := NAN
var _i := NAN
var _Om := NAN
var _w := NAN
var _w_hat := NAN
var _M0 := NAN
var _L0 := NAN
var _T0 := NAN
var _n := NAN
var _L_rate := NAN
var _a_rate := NAN
var _e_rate := NAN
var _i_rate := NAN
var _Om_rate := NAN
var _w_rate := NAN
var _M_adj_b := NAN
var _M_adj_c := NAN
var _M_adj_s := NAN
var _M_adj_f := NAN
var _Pw := NAN
var _Pnode := NAN
var _ref_plane := ""

# project inits
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
	
	_table_reader.build_object2(self, table_name, table_row, property_fields)
	# standardize orbital elements to: a, e, i, Om, w, M0, n
	var mu := parent.get_std_gravitational_parameter()
	if is_nan(_w):
		assert(!is_nan(_w_hat))
		_w = _w_hat - _Om
	if is_nan(_n):
		if !is_nan(_L_rate):
			_n = _L_rate
		else:
			_n = sqrt(mu / (_a * _a * _a))
	if is_nan(_M0):
		if !is_nan(_L0):
			_M0 = _L0 - _w - _Om
		elif !is_nan(_T0):
			_M0 = -_n * _T0
		else:
			assert(false, "Elements must include M0, L0 or T0")
	var elements := [_a, _e, _i, _Om, _w, _M0, _n]
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
		if !is_nan(_a_rate): # is planet w/ rates
			element_rates = [_a_rate, _e_rate, _i_rate, _Om_rate, _w_rate]
			assert(!is_nan(_e_rate) && !is_nan(_i_rate) && !is_nan(_Om_rate) && !is_nan(_w_rate))
			# M modifiers are additional modifiers for Jupiter to Pluto.
			if !is_nan(_M_adj_b): # must also have c, s, f
				m_modifiers = [_M_adj_b, _M_adj_c, _M_adj_s, _M_adj_f]
				assert(!is_nan(_M_adj_c) && !is_nan(_M_adj_s) && !is_nan(_M_adj_f))
		elif !is_nan(_Pw): # moon format
			assert(!is_nan(_Pnode)) # both or neither
			# Pw, Pnode don't tell us the direction of precession! However, I
			# believe that it is always the case that Pw is in the direction of
			# orbit and Pnode is in the opposite direction.
			# Some values are tiny leading to div/0 or excessive updating. These
			# correspond to near-circular and/or non-inclined orbits (where Om & w
			# are technically undefined and updates are irrelevant).
			if elements[2] < MIN_I_FOR_NODAL_PRECESSION:
				_Pnode = 0.0
			if elements[1] < MIN_E_FOR_APSIDAL_PRECESSION:
				_Pw = 0.0
			var orbit_sign := sign(PI / 2.0 - _i) # prograde +1; retrograde -1
			_Om_rate = 0.0
			_w_rate = 0.0
			if _Pnode != 0.0:
				_Om_rate = -orbit_sign * TAU / _Pnode # opposite to orbit!
			if _Pw != 0.0:
				_w_rate = orbit_sign * TAU / _Pw
			if _Om_rate or _w_rate:
				element_rates = [0.0, 0.0, 0.0, _Om_rate, _w_rate]
		if element_rates:
			orbit.element_rates = element_rates
			if m_modifiers:
				orbit.m_modifiers = m_modifiers
			# Set update_frequency based on fastest element rate. We normalize to
			# values roughly meaning "parts per second".
#			var a_pps: float = abs(element_rates[0]) / elements[0]
#			var e_pps: float = abs(element_rates[1]) / 0.1 # arbitrary
#			var i_pps: float = abs(element_rates[2]) / TAU
#			var Om_pps: float = abs(element_rates[3]) / TAU
#			var w_pps: float = abs(element_rates[4]) / TAU
#			var max_pps: float = [a_pps, e_pps, i_pps, Om_pps, w_pps].max()
#			var update_frequency := max_pps / UPDATE_ORBIT_TOLERANCE # 1/s (tiny!)
#			if update_frequency > update_frequency_limitor:
#				var adj := (1.0 - update_frequency_limitor / update_frequency) / 10.0 # 0.1 to >0.0
#				update_frequency = update_frequency_limitor * (1.0 + adj)
#			orbit.update_frequency = update_frequency

	# reference plane (moons!)
	if _ref_plane == "Equatorial":
		orbit.reference_normal = parent.model_controller.north_pole
	elif _ref_plane == "Laplace":
		var orbit_ra: float = _table_reader.get_real(table_name, "orbit_RA", table_row)
		var orbit_dec: float = _table_reader.get_real(table_name, "orbit_dec", table_row)
		orbit.reference_normal = math.convert_spherical2(orbit_ra, orbit_dec)
		orbit.reference_normal = Global.ecliptic_rotation * orbit.reference_normal
		orbit.reference_normal = orbit.reference_normal.normalized()
	elif _ref_plane:
		assert(_ref_plane == "Ecliptic")
	# reset for next orbit build
	for property in property_fields:
		if property != "_ref_plane":
			set(property, NAN)
	_ref_plane = ""
	return orbit

# *****************************************************************************

func _project_init() -> void:
	_table_reader = Global.program.TableReader
	_Orbit_ = Global.script_classes._Orbit_
	_dynamic_orbits = Global.dynamic_orbits
