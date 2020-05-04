# asteroid_group.gd
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
# Keeps compact data for an asteroid group, which could include >100,000
# asteroids (Main Belt). Pool*Arrays are used to constitute ArrayMesh's in
# HUDPoints, and act as source data for Asteroid instances. We can't easily
# separate contruction here because we would have to pass-by-value very large
# pool arrays.

extends Reference
class_name AsteroidGroup

const math := preload("res://ivoyager/static/math.gd") # =Math when issue #37529 fixed
const unit_defs := preload("res://ivoyager/static/unit_defs.gd")

const VPRINT = false # print verbose asteroid summary on load
const DPRINT = false

# ************************** PERSISTED VARS ***********************************

var is_trojans := false
var star: Body
var lagrange_point: LPoint # null unless is_trojans
var group_name: String

var max_apoapsis := 0.0
var names := PoolStringArray()
var iau_numbers := PoolIntArray() # -1 for unnumbered
var magnitudes := PoolRealArray()
var dummy_translations := PoolVector3Array() # all 0's (until we can extract values from GPU)

# non-Trojans - arrays optimized for MeshArray construction
var a_e_i := PoolVector3Array()
var Om_w_M0_n := PoolColorArray()
var s_g := PoolVector2Array() # TODO: implement these orbit precessions
# Trojans - arrays optimized for MeshArray construction
var d_e_i := PoolVector3Array()
var Om_w_D_f := PoolColorArray()
var th0 := PoolVector2Array()

var _index := 0

# persistence
const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["is_trojans", "group_name", "max_apoapsis", "names",
	"iau_number", "magnitudes", 
	"dummy_translations", "a_e_i", "Om_w_M0_n", "s_g", "d_e_i", "Om_w_D_f", "th0", "_index"]
const PERSIST_OBJ_PROPERTIES := ["star", "lagrange_point"]

# ************************** UNPERSISTED VARS *********************************

var _maxes := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _mins := [INF, INF, INF, INF, INF, INF, INF, INF, INF]
var _load_count := 0

# ************************** PUBLIC FUNCTIONS *********************************

func init(star_: Body, group_name_: String) -> void:
	star = star_
	group_name = group_name_
	assert(VPRINT and _verbose_reset_mins_maxes() or true)

func init_trojans(star_: Body, group_name_: String, lagrange_point_: LPoint) -> void:
	star = star_
	group_name = group_name_
	is_trojans = true
	lagrange_point = lagrange_point_
	assert(VPRINT and _verbose_reset_mins_maxes() or true)

func read_binary(binary: File) -> void:
	var binary_data: Array = binary.get_var()
	names.append_array(binary_data[0])
	iau_numbers.append_array(binary_data[1])
	magnitudes.append_array(binary_data[2])
	dummy_translations.append_array(binary_data[3])
	if !is_trojans:
		a_e_i.append_array(binary_data[4])
		Om_w_M0_n.append_array(binary_data[5])
	else:
		d_e_i.append_array(binary_data[4])
		Om_w_D_f.append_array(binary_data[5])
		th0.append_array(binary_data[6])
	_index = names.size()

func finish_binary_import() -> void:
	if !is_trojans:
		_fix_binary_keplerian_elements()
	else:
		_fix_binary_trojan_elements()
	assert(DPRINT and _debug_print() or true)
	assert(VPRINT and _verbose_print() or true)

# ***************** PUBLIC FUNCTIONS FOR AsteroidImporter **********************

func expand_arrays(n: int) -> void:
	names.resize(n + names.size())
	iau_numbers.resize(n + iau_numbers.size())
	magnitudes.resize(n + magnitudes.size())
	dummy_translations.resize(n + dummy_translations.size())
	if !is_trojans:
		a_e_i.resize(n + a_e_i.size())
		Om_w_M0_n.resize(n + Om_w_M0_n.size())
	else:
		d_e_i.resize(n + d_e_i.size())
		Om_w_D_f.resize(n + Om_w_D_f.size())
		th0.resize(n + th0.size())

func set_data(name_: String, magnitude: float, keplerian_elements: Array, iau_number := -1) -> void:
	names[_index] = name_
	iau_numbers[_index] = iau_number
	magnitudes[_index] = magnitude
	dummy_translations[_index] = Vector3(0.0, 0.0, 0.0)
	a_e_i[_index] = Vector3(keplerian_elements[0], keplerian_elements[1], keplerian_elements[2]) # a, e, i
	Om_w_M0_n[_index] = Color(keplerian_elements[3], keplerian_elements[4], keplerian_elements[5], keplerian_elements[6]) # Om, w, M0, n
	_index += 1

func set_trojan_data(name_: String, magnitude: float, keplerian_elements: Array, trojan_elements: Array, iau_number := -1) -> void:
	names[_index] = name_
	iau_numbers[_index] = iau_number
	magnitudes[_index] = magnitude
	dummy_translations[_index] = Vector3(0.0, 0.0, 0.0)
	d_e_i[_index] = Vector3(trojan_elements[0], keplerian_elements[1], keplerian_elements[2]) # d, e, i
	Om_w_D_f[_index] = Color(keplerian_elements[3], keplerian_elements[4], trojan_elements[1], trojan_elements[2]) # Om, w, D, f
	th0[_index] = Vector2(trojan_elements[3], 0.0) # th0
	_index += 1

func write_binary(binary: File) -> void:
	var binary_data: Array
	if !is_trojans:
		binary_data = [names, iau_numbers, magnitudes, dummy_translations, a_e_i, Om_w_M0_n]
	else:
		binary_data = [names, iau_numbers, magnitudes, dummy_translations, d_e_i, Om_w_D_f, th0]
	binary.store_var(binary_data)

func clear_for_import() -> void:
	names.resize(0)
	iau_numbers.resize(0)
	magnitudes.resize(0)
	dummy_translations.resize(0)
	a_e_i.resize(0)
	Om_w_M0_n.resize(0)
	d_e_i.resize(0)
	Om_w_D_f.resize(0)
	th0.resize(0)
	_index = 0

# ************************** PRIVATE FUNCTIONS ********************************

func _fix_binary_keplerian_elements() -> void:
	var au := unit_defs.AU
	var year := unit_defs.YEAR
	var mu := star.properties.gm
	var index := 0
	while index < _index:
		var a: float = a_e_i[index][0] * au # from au
		a_e_i[index][0] = a
		var n: float = Om_w_M0_n[index][3]
		if n != 0.0:
			n /= year # from rad/year
		else:
			n = sqrt(mu / (a * a * a))
		Om_w_M0_n[index][3] = n
		# Fix M0 for different epoch.
		# Currently, *.cat files have epoch MJD 58200. We need to check this
		# whenever we download new source data and adjust code accordingly.
		# TODO: automate this in big_data_interface.gd.
		# We need to correct M0 from MJD to J2000 day:
		# MJD = 58200
		# JD = MJD + 2400000.5 = 2458200.5
		# J2000 day = JD - 2451545 = 6655.5
		var M0: float = Om_w_M0_n[index][2] # already in rad
		var M0_J2000: float = M0 - n * 6655.5 # J2000 was this many days before import epoch
		M0_J2000 = fposmod(M0_J2000, TAU)
		Om_w_M0_n[index][2] = M0_J2000
		# apoapsis
		var e: float = a_e_i[index][1]
		var apoapsis := a * (1.0 + e)
		if max_apoapsis < apoapsis:
			max_apoapsis = apoapsis
		assert(VPRINT and _verbose_min_max_tally(a_e_i[index], Om_w_M0_n[index]) or true)
		index += 1

func _fix_binary_trojan_elements() -> void:
	var au := unit_defs.AU
	var year := unit_defs.YEAR
	var lagrange_a: float = lagrange_point.dynamic_elements[0]
	var index := 0
	while index < _index:
		var d: float = d_e_i[index][0] * au # from au
		d_e_i[index][0] = d
		Om_w_D_f[index][3] /= year # f; from rad/year
		
		# FIXME: We should be able to derived th0 from initial keplerian elements.
		# Maybe someone smarter than me can figure out how.
		# This isn't correct, but my guess is something like...
		#	var th0 = atan2((a - l_point_a) / d, (M0 - l_point_M0) / D)
		var th0_ := rand_range(0.0, TAU)
		th0[index][0] = th0_
		# apoapsis
		var e: float = d_e_i[index][1]
		var apoapsis := (lagrange_a + d) * (1.0 + e) # more or less
		if max_apoapsis < apoapsis:
			max_apoapsis = apoapsis
		assert(VPRINT and _verbose_min_max_tally(d_e_i[index], Om_w_D_f[index], th0[index]) or true)
		index += 1

func _verbose_reset_mins_maxes() -> void:
	for i in range(_maxes.size()):
			_maxes[i] = 0.0
			_mins[i] = INF

func _verbose_min_max_tally(a_e_i_: Vector3, Om_w_M0_n_: Color, s_g_ := Vector2(0.0, 0.0)) -> void:
	# works for trojan, just substitue trojan args
	_maxes[0] = max(_maxes[0], a_e_i_[0])
	_maxes[1] = max(_maxes[1], a_e_i_[1])
	_maxes[2] = max(_maxes[2], a_e_i_[2])
	_maxes[3] = max(_maxes[3], Om_w_M0_n_[0])
	_maxes[4] = max(_maxes[4], Om_w_M0_n_[1])
	_maxes[5] = max(_maxes[5], Om_w_M0_n_[2])
	_maxes[6] = max(_maxes[6], Om_w_M0_n_[3])
	_maxes[7] = max(_maxes[7], s_g_[0])
	_maxes[8] = max(_maxes[8], s_g_[1])
	_mins[0] = min(_mins[0], a_e_i_[0])
	_mins[1] = min(_mins[1], a_e_i_[1])
	_mins[2] = min(_mins[2], a_e_i_[2])
	_mins[3] = min(_mins[3], Om_w_M0_n_[0])
	_mins[4] = min(_mins[4], Om_w_M0_n_[1])
	_mins[5] = min(_mins[5], Om_w_M0_n_[2])
	_mins[6] = min(_mins[6], Om_w_M0_n_[3])
	_mins[7] = min(_mins[7], s_g_[0])
	_mins[8] = min(_mins[8], s_g_[1])
	_load_count += 1
	
func _verbose_print() -> void:
	var au := unit_defs.AU
	var deg := unit_defs.DEG
	var year := unit_defs.YEAR
	print("%s group %s asteroids loaded from binaries (min/max)" % [_load_count, group_name])
	if !is_trojans:
		print(" a  : %s / %s (AU)" % [_mins[0] / au, _maxes[0] / au])
		print(" e  : %s / %s" % [_mins[1], _maxes[1]])
		print(" i  : %s / %s (deg)" % [_mins[2] / deg, _maxes[2] / deg])
		print(" Om : %s / %s (deg)" % [_mins[3] / deg, _maxes[3] / deg])
		print(" w  : %s / %s (deg)" % [_mins[4] / deg, _maxes[4] / deg])
		print(" M0 : %s / %s (deg)" % [_mins[5] / deg, _maxes[5] / deg])
		print(" n  : %s / %s (deg/y)" % [_mins[6] / deg * year, _maxes[6] / deg * year])
	else:
		print(" d,  min/max: %s / %s (AU)" % [_mins[0] / au, _maxes[0] / au])
		print(" e  : %s / %s" % [_mins[1], _maxes[1]])
		print(" i  : %s / %s (deg)" % [_mins[2] / deg, _maxes[2] / deg])
		print(" Om : %s / %s (deg)" % [_mins[3] / deg, _maxes[3] / deg])
		print(" w  : %s / %s (deg)" % [_mins[4] / deg, _maxes[4] / deg])
		print(" D  : %s / %s (deg)" % [_mins[5] / deg, _maxes[5] / deg])
		print(" f  : %s / %s (deg/y)" % [_mins[6] / deg * year, _maxes[6] / deg * year])
		print(" th0: %s / %s (deg)" % [_mins[7] / deg, _maxes[7] / deg])
		
func _debug_print():
	print(group_name, " _ready()")
	print(dummy_translations.size())
	print(names.size())
	print(magnitudes.size())
	print(a_e_i.size())
	print(Om_w_M0_n.size())
	print(d_e_i.size())
	print(Om_w_D_f.size())
	print(th0.size())
	print(_index)
	print(max_apoapsis)
