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
extends Node

# Keeps compact data for large numbers of small bodies that we don't want to
# instantiate as a full set, e.g., 10000s of asteroids.
#
# Packed arrays are used as source data in a form that is ready-to-use to
# constitute ArrayMesh's in IVSBGPoints. Packed arrays are also very fast to
# read/write in the game save file.

const units := preload("res://ivoyager/static/units.gd")
const utils := preload("res://ivoyager/static/utils.gd")

const VPRINT = true # print verbose asteroid summary on load

const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL
const PERSIST_PROPERTIES := [
	&"name",
	&"sbg_alias",
	&"sbg_class",
	&"secondary_body",
	&"lp_integer",
	&"max_apoapsis",
	&"names",
	&"e_i_Om_w",
	&"a_M0_n",
	&"s_g_mag",
	&"da_D_f_th0",
	&"de",
]

# persisted

var sbg_alias: StringName
var sbg_class: int # IVEnums.SBGClass
var secondary_body: IVBody # e.g., Jupiter for Trojans; usually null
var lp_integer := -1 # -1, 4 & 5 are currently supported
var max_apoapsis := 0.0

# binary import data
var names := PackedStringArray()

# new packed data
var e_i_Om_w := PackedFloat32Array()
var a_M0_n := PackedFloat32Array()
var s_g_mag := PackedFloat32Array()

# L4/L5
var da_D_f_th0 := PackedFloat32Array()
var de := PackedFloat32Array() # NOT USED


# temp import vars until we rebuild ivbinary_maker
var temp_e_i_Om_w := PackedColorArray() # fixed & precessing (e librates for secular resonance)
var temp_a_M0_n := PackedVector3Array() # librating in l-point objects
var temp_s_g := PackedVector2Array() # orbit precessions
var temp_da_D_f := PackedVector3Array() # Trojans: a amplitude, L amplitude, and libration frequency
var temp_th0_de := PackedVector2Array() # Trojans: libration at epoch [, & sec res: e amplitude]
var temp_magnitudes := PackedFloat32Array()

# *****************************************************************************
# public API

func get_number() -> int:
	return names.size()


func get_orbit_elements(index: int) -> Array[float]:
	# [a, e, i, Om, w, M0, n]
	# WIP - Trojan elements a, M0 & n vary with libration. This is reflected in
	# shader point calculations but not in elements here (yet).
	
	return Array([
		a_M0_n[index * 3],
		e_i_Om_w[index * 4],
		e_i_Om_w[index * 4 + 1],
		e_i_Om_w[index * 4 + 2],
		e_i_Om_w[index * 4 + 3],
		a_M0_n[index * 3 + 1],
		a_M0_n[index * 3 + 2],
	], TYPE_FLOAT, &"", null)



#	var e_i_Om_w_item := temp_e_i_Om_w[index]
#	var a_M0_n_item := temp_a_M0_n[index]
#	return Array([
#		a_M0_n_item[0],
#		e_i_Om_w_item[0],
#		e_i_Om_w_item[1],
#		e_i_Om_w_item[2],
#		e_i_Om_w_item[3],
#		a_M0_n_item[1],
#		a_M0_n_item[2],
#	], TYPE_FLOAT, &"", null)


# *****************************************************************************
# ivoyager internal methods

func init(name_: StringName, sbg_alias_: StringName, sbg_class_: int,
		lp_integer_ := -1, secondary_body_: IVBody = null) -> void:
	# Last 2 args only if these are Lagrange point objects.
	name = name_
	sbg_alias = sbg_alias_
	sbg_class = sbg_class_
	lp_integer = lp_integer_
	secondary_body = secondary_body_


func read_binary(binary: FileAccess) -> void:
	var binary_data: Array = binary.get_var()
	names.append_array(binary_data[0])
	temp_magnitudes.append_array(binary_data[1])
	temp_e_i_Om_w.append_array(binary_data[2])
	temp_a_M0_n.append_array(binary_data[3])
	temp_s_g.append_array(binary_data[4])
	if lp_integer != -1:
		temp_da_D_f.append_array(binary_data[5])
		temp_th0_de.append_array(binary_data[6])


func finish_binary_import() -> void:
	# set max apoapsis and do verbose tally
	var size := names.size()
	assert(size)
	var index := 0
	if lp_integer == -1:
		while index < size:
			var a: float = temp_a_M0_n[index][0]
			var e: float = temp_e_i_Om_w[index][0]
			var apoapsis := a * (1.0 + e)
			if max_apoapsis < apoapsis:
				max_apoapsis = apoapsis
			index += 1
	else:
		var characteristic_length := secondary_body.orbit.get_semimajor_axis()
		while index < size:
			var da: float = temp_da_D_f[index][0]
			var e: float = temp_e_i_Om_w[index][0]
			var apoapsis := (characteristic_length + da) * (1.0 + e)
			if max_apoapsis < apoapsis:
				max_apoapsis = apoapsis
			index += 1
	
	# WIP - Convert to new packed arrays until we rebuild ivbinary_maker
	index = 0
	e_i_Om_w.resize(size * 4)
	a_M0_n.resize(size * 3)
	s_g_mag.resize(size * 3)
	if lp_integer == -1:
		while index < size:
			e_i_Om_w[index * 4] = temp_e_i_Om_w[index][0]
			e_i_Om_w[index * 4 + 1] = temp_e_i_Om_w[index][1]
			e_i_Om_w[index * 4 + 2] = temp_e_i_Om_w[index][2]
			e_i_Om_w[index * 4 + 3] = temp_e_i_Om_w[index][3]
			a_M0_n[index * 3] = temp_a_M0_n[index][0]
			a_M0_n[index * 3 + 1] = temp_a_M0_n[index][1]
			a_M0_n[index * 3 + 2] = temp_a_M0_n[index][2]
			s_g_mag[index * 3] = temp_s_g[index][0]
			s_g_mag[index * 3 + 1] = temp_s_g[index][1]
			s_g_mag[index * 3 + 2] = temp_magnitudes[index]
			index += 1
	else:
		da_D_f_th0.resize(size * 4)
		de.resize(size)
		while index < size:
			e_i_Om_w[index * 4] = temp_e_i_Om_w[index][0]
			e_i_Om_w[index * 4 + 1] = temp_e_i_Om_w[index][1]
			e_i_Om_w[index * 4 + 2] = temp_e_i_Om_w[index][2]
			e_i_Om_w[index * 4 + 3] = temp_e_i_Om_w[index][3]
			a_M0_n[index * 3] = temp_a_M0_n[index][0]
			a_M0_n[index * 3 + 1] = temp_a_M0_n[index][1]
			a_M0_n[index * 3 + 2] = temp_a_M0_n[index][2]
			s_g_mag[index * 3] = temp_s_g[index][0]
			s_g_mag[index * 3 + 1] = temp_s_g[index][1]
			s_g_mag[index * 3 + 2] = temp_magnitudes[index]
			da_D_f_th0[index * 4] = temp_da_D_f[index][0]
			da_D_f_th0[index * 4 + 1] = temp_da_D_f[index][1]
			da_D_f_th0[index * 4 + 2] = temp_da_D_f[index][2]
			da_D_f_th0[index * 4 + 3] = temp_th0_de[index][0]
			de[index] = temp_th0_de[index][1]
			index += 1
	
	temp_e_i_Om_w.clear()
	temp_a_M0_n.clear()
	temp_s_g.clear()
	temp_magnitudes.clear()
	temp_da_D_f.clear()
	temp_th0_de.clear()
	
	
	# feedback
	assert(!VPRINT or IVDebug.dprint("%s %s asteroids loaded from binaries"
			% [names.size(), sbg_alias]))


func get_fragment_data(fragment_type: int, index: int) -> Array:
	return [get_instance_id(), fragment_type, index]


func get_fragment_text(data: Array) -> String:
	var fragment_type: int = data[1]
	var index: int = data[2]
	var text := names[index]
	if fragment_type == IVFragmentIdentifier.FRAGMENT_SBG_ORBIT:
		text += " (" + tr("LABEL_ORBIT").to_lower() + ")"
	return text

