# small_bodies_group.gd
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
class_name IVSmallBodiesGroup
extends Reference

# Keeps compact data for large numbers of small bodies that we don't want to
# instantiate as a full set - e.g., 10,000s of asteroids.
#
# Packed arrays are used to constitute ArrayMesh's in IVHUDPoints, and act as
# small body source data (e.g., when a small body needs to be instantiated).
# Packed arrays are also very fast to read/write in the game save file.
#
# TODO 4.0: Reorganize for new shader CUSTOM channels:
#  - CUSTOM0: a, e, M0, n
#  - CUSTOM1: i, Om, w
#  - CUSTOM2: s, g
#  - CUSTOM3: d, D, f, th0 (lagrange only)


const units := preload("res://ivoyager/static/units.gd")
const utils := preload("res://ivoyager/static/utils.gd")

const VPRINT = true # print verbose asteroid summary on load
const DPRINT = false

const FRAGMENT_POINT := IVFragmentIdentifier.FRAGMENT_POINT
const FRAGMENT_ORBIT := IVFragmentIdentifier.FRAGMENT_ORBIT

const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL
const PERSIST_PROPERTIES := [
	"group_name",
	"group_id",
	"primary_body",
	"secondary_body",
	"lp_integer",
	"max_apoapsis",
	"names",
	"iau_numbers",
	"magnitudes",
	"dummy_translations",
	"a_e_i",
	"Om_w_M0_n",
	"s_g",
	"d_e_i",
	"Om_w_D_f",
	"th0",
]
	
# *****************************************************************************
# persisted

var group_name: String
var group_id: int
var primary_body: IVBody
var secondary_body: IVBody # null unless resonant group
var lp_integer := -1 # -1, NA; 4 & 5 are currently supported

var max_apoapsis := 0.0

# below is binary import data
var names := PoolStringArray()
var iau_numbers := PoolIntArray() # -1 for unnumbered (is 32 bit enough?)
var magnitudes := PoolRealArray()

var dummy_translations := PoolVector3Array() # all 0's

# non-Trojans - arrays pre-structured for MeshArray construction
var a_e_i := PoolVector3Array()
var Om_w_M0_n := PoolColorArray()
var s_g := PoolVector2Array() # TODO: implement these orbit precessions
# Trojans - arrays pre-structured for MeshArray construction
var d_e_i := PoolVector3Array()
var Om_w_D_f := PoolColorArray()
var th0 := PoolVector2Array()


# *****************************************************************************

var _index := 0
var _maxes := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _mins := [INF, INF, INF, INF, INF, INF, INF, INF, INF]
var _load_count := 0


# *****************************************************************************
# public API

func get_number() -> int:
	return names.size()


func get_orbit_elements(index: int) -> Array:
	# [a, e, i, Om, w, M0, n]
	# Does not work for Trojans (yet)
	assert(lp_integer == -1) # for now
	var a_e_i_item := a_e_i[index]
	var Om_w_M0_n_item := Om_w_M0_n[index]
	return [
		a_e_i_item[0],
		a_e_i_item[1],
		a_e_i_item[2],
		Om_w_M0_n_item[0],
		Om_w_M0_n_item[1],
		Om_w_M0_n_item[2],
		Om_w_M0_n_item[3],
	]


# *****************************************************************************
# ivoyager internal methods

func init(group_name_: String, primary_body_: IVBody, secondary_body_: IVBody = null,
		lp_integer_ := -1) -> void:
	# Last 2 args only if these are Lagrange point objects.
	group_name = group_name_
	primary_body = primary_body_
	secondary_body = secondary_body_
	lp_integer = lp_integer_
	assert(VPRINT and _verbose_reset_mins_maxes() or true)
	# self register in SmallBodiesGroupIndexing for persistence
	var small_bodies_group_indexing: IVSmallBodiesGroupIndexing \
			= IVGlobal.program.SmallBodiesGroupIndexing
	group_id = small_bodies_group_indexing.groups.size()
	small_bodies_group_indexing.groups.append(self)
	small_bodies_group_indexing.group_ids[group_name] = group_id


# TODO: Move binary build stuff to SmallBodiesBuilder
func read_binary(binary: File) -> void:
	var binary_data: Array = binary.get_var()
	names.append_array(binary_data[0])
	iau_numbers.append_array(binary_data[1])
	magnitudes.append_array(binary_data[2])
	dummy_translations.append_array(binary_data[3])
	if lp_integer == -1:
		a_e_i.append_array(binary_data[4])
		Om_w_M0_n.append_array(binary_data[5])
	else:
		d_e_i.append_array(binary_data[4])
		Om_w_D_f.append_array(binary_data[5])
		th0.append_array(binary_data[6])
	_index = names.size()


func finish_binary_import() -> void:
	# convert binary data to internal units, etc.
	if lp_integer == -1:
		_fix_binary_keplerian_elements()
	else:
		_fix_binary_trojan_elements()
	
	# feedback
	assert(DPRINT and _debug_print() or true)
	assert(VPRINT and _verbose_print() or true)


func get_fragment_data(index: int, fragment_type: int) -> Array:
	return [names[index], fragment_type, group_id, index]




func _fix_binary_keplerian_elements() -> void:
#	var au := units.AU
#	var year := units.YEAR
#	var mu := primary_body.get_std_gravitational_parameter()
#	assert(mu)
	var size := names.size()
	var index := 0
	while index < size:
		var a: float = a_e_i[index][0] # * au # from au
#		a_e_i[index][0] = a
		var n: float = Om_w_M0_n[index][3]
		assert(n)
#		if n != 0.0:
#			n /= year # from rad/year
#		else:
#			n = sqrt(mu / (a * a * a))
#		Om_w_M0_n[index][3] = n
		# Fix M0 for different epoch.
		# Currently, *.cat files have epoch MJD 58200. We need to check this
		# whenever we download new source data and adjust code accordingly.
		# TODO: automate this (or provide setting) in asteroid_importer.gd.
		# We need to correct M0 from MJD to J2000 day:
		# MJD = 58200
		# JD = MJD + 2400000.5 = 2458200.5
		# J2000 day = JD - 2451545 = 6655.5
#		var M0: float = Om_w_M0_n[index][2] # already in rad
#		var M0_J2000: float = M0 - n * 6655.5 * IVUnits.DAY
#		M0_J2000 = fposmod(M0_J2000, TAU)
#		Om_w_M0_n[index][2] = M0_J2000
		# apoapsis
		var e: float = a_e_i[index][1]
		var apoapsis := a * (1.0 + e)
		if max_apoapsis < apoapsis:
			max_apoapsis = apoapsis
		assert(VPRINT and _verbose_min_max_tally(a_e_i[index], Om_w_M0_n[index]) or true)
		index += 1


func _fix_binary_trojan_elements() -> void:
#	var au := units.AU
#	var year := units.YEAR
	var characteristic_length := secondary_body.orbit.get_characteristic_length()
	var size := names.size()
	var index := 0
	while index < size:
		var d: float = d_e_i[index][0] # * au # from au
#		d_e_i[index][0] = d
#		Om_w_D_f[index][3] /= year # f; from rad/year
		# Random th0. We can't determine where we are in cycle from proper
		# elements alone. If we had current a & M (and epoch), we could
		# probably back-calculate th0. 
#		var th0_ := rand_range(0.0, TAU)
#		th0[index][0] = th0_
		# apoapsis
		var e: float = d_e_i[index][1]
		var apoapsis := characteristic_length / (1.0 - e) + d
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
	var au := units.AU
	var deg := units.DEG
	var year := units.YEAR
	print("%s group %s asteroids loaded from binaries (min - max)" % [_load_count, group_name])
	if lp_integer == -1:
		print(" a  : %s - %s (AU)" % [_mins[0] / au, _maxes[0] / au])
		print(" e  : %s - %s" % [_mins[1], _maxes[1]])
		print(" i  : %s - %s (deg)" % [_mins[2] / deg, _maxes[2] / deg])
		print(" Om : %s - %s (deg)" % [_mins[3] / deg, _maxes[3] / deg])
		print(" w  : %s - %s (deg)" % [_mins[4] / deg, _maxes[4] / deg])
		print(" M0 : %s - %s (deg)" % [_mins[5] / deg, _maxes[5] / deg])
		print(" n  : %s - %s (deg/y)" % [_mins[6] / deg * year, _maxes[6] / deg * year])
	else:
		print(" d  : %s - %s (AU)" % [_mins[0] / au, _maxes[0] / au])
		print(" e  : %s - %s" % [_mins[1], _maxes[1]])
		print(" i  : %s - %s (deg)" % [_mins[2] / deg, _maxes[2] / deg])
		print(" Om : %s - %s (deg)" % [_mins[3] / deg, _maxes[3] / deg])
		print(" w  : %s - %s (deg)" % [_mins[4] / deg, _maxes[4] / deg])
		print(" D  : %s - %s (deg)" % [_mins[5] / deg, _maxes[5] / deg])
		print(" f  : %s - %s (deg/y)" % [_mins[6] / deg * year, _maxes[6] / deg * year])
		print(" th0: %s - %s (deg)" % [_mins[7] / deg, _maxes[7] / deg])


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
