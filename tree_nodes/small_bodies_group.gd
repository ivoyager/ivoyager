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
# constitute ArrayMesh in IVSBGPoints. Packed arrays are also very fast to
# read/write in the game save file.
#
# 'de' not implemented (amplitude of e libration in secular resonence).

const units := preload("res://ivoyager/static/units.gd")
const utils := preload("res://ivoyager/static/utils.gd")

const VPRINT = false # print verbose asteroid summary on load

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
	&"s_g_mag_de",
	&"da_D_f_th0",
]

# persisted

var sbg_alias: StringName
var sbg_class: int # IVEnums.SBGClass
var secondary_body: IVBody # e.g., Jupiter for Trojans; usually null
var lp_integer := -1 # -1, 4 & 5 are currently supported
var max_apoapsis := 0.0

# binary import data
var names := PackedStringArray()
var e_i_Om_w := PackedFloat32Array() # fixed & precessing (except e in sec res)
var a_M0_n := PackedFloat32Array() # librating in l-point objects
var s_g_mag_de := PackedFloat32Array() # orbit precessions, magnitude, & e amplitude (sec res only)
var da_D_f_th0 := PackedFloat32Array() # Trojans only


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
	
	e_i_Om_w.append_array(binary_data[1])
	a_M0_n.append_array(binary_data[2])
	s_g_mag_de.append_array(binary_data[3])
	
	if lp_integer != -1:
		da_D_f_th0.append_array(binary_data[4])


func finish_binary_import() -> void:
	# set max apoapsis and do verbose tally
	var size := names.size()
	assert(size)
	var index := 0
	if lp_integer == -1:
		while index < size:
			var a: float = a_M0_n[index * 3]
			var e: float = e_i_Om_w[index * 4]
			var apoapsis := a * (1.0 + e)
			if max_apoapsis < apoapsis:
				max_apoapsis = apoapsis
			index += 1
	else:
		var characteristic_length := secondary_body.orbit.get_semimajor_axis()
		while index < size:
			var da: float = da_D_f_th0[index * 4]
			var e: float = e_i_Om_w[index * 4]
			var apoapsis := (characteristic_length + da) * (1.0 + e)
			if max_apoapsis < apoapsis:
				max_apoapsis = apoapsis
			index += 1
	
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

