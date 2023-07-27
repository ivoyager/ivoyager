# sbg_builder.gd
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
class_name IVSBGBuilder
extends RefCounted

# Builds SmallBodiesGroup instances from small_bodies_groups.tsv & binary data.

const utils := preload("res://ivoyager/static/utils.gd")

const DPRINT = false
const BINARY_EXTENSION := "ivbinary"
const BINARY_FILE_MAGNITUDES := ["11.0", "11.5", "12.0", "12.5", "13.0", "13.5", "14.0", "14.5",
		"15.0", "15.5", "16.0", "16.5", "17.0", "17.5", "18.0", "18.5", "99.9"]


var _sbg_mag_cutoff_override: float = IVGlobal.sbg_mag_cutoff_override
var _SmallBodiesGroup_: Script
var _table_reader: IVTableReader
var _asteroid_count := 0
var _binary_dir: String


func _project_init() -> void:
	_SmallBodiesGroup_ = IVGlobal.script_classes._SmallBodiesGroup_
	_table_reader = IVGlobal.program.TableReader


func build_sbgs() -> void:
	_asteroid_count = 0
	var n_groups := _table_reader.get_n_rows("small_bodies_groups")
	for row in n_groups:
		build_sbg(row)
	print("Added orbital data for ", _asteroid_count, " small bodies (asteroids, etc.)")


func build_sbg(row: int) -> void:
	if _table_reader.get_bool("small_bodies_groups", "skip", row):
		return
	
	# get table data (default colors are read by SBGHUDsState)
	var name := _table_reader.get_string("small_bodies_groups", "name", row)
	var sbg_alias := _table_reader.get_string("small_bodies_groups", "sbg_alias", row)
	var sbg_class := _table_reader.get_int("small_bodies_groups", "sbg_class", row)
	_binary_dir = _table_reader.get_string("small_bodies_groups", "binary_dir", row)
	var mag_cutoff := 100.0
	if _sbg_mag_cutoff_override != INF:
		mag_cutoff = _sbg_mag_cutoff_override
	else:
		mag_cutoff = _table_reader.get_real("small_bodies_groups", "mag_cutoff", row)
	var primary_name := _table_reader.get_string("small_bodies_groups", "primary", row)
	var primary: IVBody = IVGlobal.bodies.get(primary_name)
	assert(primary, "Primary body missing for SmallBodiesGroup")
	var lp_integer := _table_reader.get_int("small_bodies_groups", "lp_integer", row)
	var secondary: IVBody
	if lp_integer != -1:
		assert(lp_integer == 4 or lp_integer == 5, "Only L4, L5 supported at this time!")
		var secondary_name := _table_reader.get_string("small_bodies_groups", "secondary", row)
		secondary = IVGlobal.bodies.get(secondary_name)
		assert(secondary, "Secondary body missing for Lagrange point SmallBodiesGroup")
	
	# init
	var sbg: IVSmallBodiesGroup = _SmallBodiesGroup_.new()
	sbg.init(name, sbg_alias, sbg_class, lp_integer, secondary)
	
	# binaries import
	for mag_str in BINARY_FILE_MAGNITUDES:
		if float(mag_str) > mag_cutoff:
			break
		_load_group_binary(sbg, mag_str)
	sbg.finish_binary_import()
	_asteroid_count += sbg.get_number()
	
	# add to tree (SBGFinisher will add points and orbits HUDs)
	primary.add_child(sbg)


func _load_group_binary(sbg: IVSmallBodiesGroup, mag_str: String) -> void:
	var binary_name: String = sbg.sbg_alias + "." + mag_str + "." + BINARY_EXTENSION
	var path: String = _binary_dir.plus_file(binary_name)
	var binary := File.new()
	if binary.open(path, File.READ) != OK: # skip quietly if file doesn't exist
		return
	assert(DPRINT and print("Reading binary %s" % path) or true)
	sbg.read_binary(binary)
	binary.close()
