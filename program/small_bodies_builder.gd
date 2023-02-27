# small_bodies_builder.gd
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
class_name IVSmallBodiesBuilder
extends Reference

# Builds SmallBodiesGroup instances from binary data.
#
# TODO: Code needs generalization. It is currently specific for asteroids
# orbiting the 'top' body.

signal small_bodies_added()


const DPRINT = false
const BINARY_FILE_MAGNITUDES = ["11.0", "11.5", "12.0", "12.5", "13.0", "13.5",
	"14.0", "14.5", "15.0", "15.5", "16.0", "16.5", "17.0", "17.5", "18.0",
	"18.5", "99.9"]

var _SmallBodiesGroup_: Script
var _asteroid_mag_cutoff_override: float = IVGlobal.asteroid_mag_cutoff_override
var _table_reader: IVTableReader
var _small_bodies_group_indexing: IVSmallBodiesGroupIndexing
var _running_count := 0


func _project_init() -> void:
	_SmallBodiesGroup_ = IVGlobal.script_classes._SmallBodiesGroup_
	_table_reader = IVGlobal.program.TableReader


func build() -> void:
	if IVGlobal.skip_asteroids:
		return
	var star: IVBody = IVGlobal.top_bodies[0] # TODO: multistar
	_load_binaries(star)
	print("Added orbital data for ", _running_count, " asteroids")
	emit_signal("small_bodies_added")


func _load_binaries(star: IVBody) -> void:
	_running_count = 0
	var n_groups := _table_reader.get_n_rows("asteroid_groups")
	var row := 0
	while row < n_groups:
		if _table_reader.get_bool("asteroid_groups", "skip_import", row):
			row += 1
			continue
		var group_name := _table_reader.get_string("asteroid_groups", "group", row)
		var trojan_of: IVBody
		var trojan_of_name := _table_reader.get_string("asteroid_groups", "trojan_of", row)
		if trojan_of_name:
			trojan_of = IVGlobal.bodies[trojan_of_name]
		if !trojan_of:
			_load_group_binaries(star, group_name, row)
		else: # trojans!
			for lp_integer in [4, 5]: # split data table JT i!JT4 & JT5
				var l_group: String = group_name + str(lp_integer)
				_load_group_binaries(star, l_group, row, lp_integer, trojan_of)
		row += 1


func _load_group_binaries(star: IVBody, group_name: String, table_row: int, lp_integer := -1,
		trojan_of: IVBody = null) -> void:
	assert(lp_integer == -1 or lp_integer == 4 or lp_integer == 5)
	var group: IVSmallBodiesGroup = _SmallBodiesGroup_.new()
	group.init(group_name, star, trojan_of, lp_integer)
	var binary_dir := _table_reader.get_string("asteroid_groups", "binary_dir", table_row)
	var mag_cutoff := 100.0
	if _asteroid_mag_cutoff_override != INF:
		mag_cutoff = _asteroid_mag_cutoff_override
	else:
		mag_cutoff = _table_reader.get_real("asteroid_groups", "mag_cutoff", table_row)
	for mag_str in BINARY_FILE_MAGNITUDES:
		if float(mag_str) < mag_cutoff:
			_load_binary(group, group_name, mag_str, binary_dir)
		else:
			break
	group.finish_binary_import()
	
	
	_running_count += group.get_number()


func _load_binary(group: IVSmallBodiesGroup, group_name: String, mag_str: String,
		binary_dir: String) -> void:
	var binary_name := group_name + "." + mag_str + ".ivbinary"
	var path: String = binary_dir.plus_file(binary_name)
	var binary := File.new()
	if binary.open(path, File.READ) != OK: # skip if file doesn't exist
		return
	assert(DPRINT and print("Reading binary %s" % path) or true)
	group.read_binary(binary)
	binary.close()
