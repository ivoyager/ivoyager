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


signal small_bodies_added()


const DPRINT = false
const BINARY_FILE_MAGNITUDES = ["11.0", "11.5", "12.0", "12.5", "13.0", "13.5",
	"14.0", "14.5", "15.0", "15.5", "16.0", "16.5", "17.0", "17.5", "18.0",
	"18.5", "99.9"]

var _asteroid_mag_cutoff_override: float = IVGlobal.asteroid_mag_cutoff_override
var _settings: Dictionary = IVGlobal.settings
var _table_reader: IVTableReader
var _l_point_builder: IVLagrangePointBuilder
var _small_bodies_manager: IVSmallBodiesManager
var _SmallBodiesGroup_: Script
var _HUDPoints_: Script
var _asteroid_binaries_dir: String
var _running_count := 0


func _project_init() -> void:
	IVGlobal.connect("system_tree_built_or_loaded", self, "_init_unpersisted")
	_table_reader = IVGlobal.program.TableReader
	_l_point_builder = IVGlobal.program.LagrangePointBuilder
	_small_bodies_manager = IVGlobal.program.SmallBodiesManager
	_SmallBodiesGroup_ = IVGlobal.script_classes._SmallBodiesGroup_
	_HUDPoints_ = IVGlobal.script_classes._HUDPoints_
	_asteroid_binaries_dir = IVGlobal.asset_paths.asteroid_binaries_dir


func _init_unpersisted(_is_new_game: bool) -> void:
	var groups_by_name := _small_bodies_manager.groups_by_name
	for group_name in groups_by_name:
		var small_bodies_group := groups_by_name[group_name] as IVSmallBodiesGroup
		if small_bodies_group:
			_init_hud_points(small_bodies_group)


func build() -> void:
	if IVGlobal.skip_asteroids:
		return
	var star: IVBody = IVGlobal.top_bodies[0] # TODO: multistar
	_load_binaries(star)
	print("Added orbital data for ", _running_count, " asteroids")
	emit_signal("small_bodies_added")


func _init_hud_points(small_bodies_group: IVSmallBodiesGroup) -> void:
	var hud_points: IVHUDPoints = _HUDPoints_.new()
	hud_points.init(small_bodies_group, _settings.asteroid_point_color)
	hud_points.draw_points()
	var star := small_bodies_group.star
	star.add_child(hud_points)


func _load_binaries(star: IVBody) -> void:
	_running_count = 0
	var n_groups := _table_reader.get_n_rows("asteroid_groups")
	var row := 0
	while row < n_groups:
		var group := _table_reader.get_string("asteroid_groups", "group", row)
		var trojan_of: IVBody
		var trojan_of_name := _table_reader.get_string("asteroid_groups", "trojan_of", row)
		if trojan_of_name:
			trojan_of = IVGlobal.bodies[trojan_of_name]
		if !trojan_of:
			_load_group_binaries(star, group, row)
		else: # trojans!
			for l_point in [4, 5]: # split data table JT i!JT4 & JT5
				var l_group: String = group + str(l_point)
				_load_group_binaries(star, l_group, row, l_point, trojan_of)
		row += 1


func _load_group_binaries(star: IVBody, group: String, table_row: int, l_point := -1,
		trojan_of: IVBody = null) -> void:
	assert(l_point == -1 or l_point == 4 or l_point == 5)
	var is_trojans := l_point != -1
	var lagrange_point: IVLPoint
	# make the IVSmallBodiesGroup
	var small_bodies_group: IVSmallBodiesGroup = _SmallBodiesGroup_.new()
	if !is_trojans:
		small_bodies_group.init(star, group)
	else:
		lagrange_point = _l_point_builder.get_or_make_lagrange_point(trojan_of, l_point)
		assert(lagrange_point)
		small_bodies_group.init_trojans(star, group, lagrange_point)
	var mag_cutoff := 100.0
	if _asteroid_mag_cutoff_override != INF:
		mag_cutoff = _asteroid_mag_cutoff_override
	else:
		mag_cutoff = _table_reader.get_real("asteroid_groups", "mag_cutoff", table_row)
	for mag_str in BINARY_FILE_MAGNITUDES:
		if float(mag_str) < mag_cutoff:
			_load_binary(small_bodies_group, group, mag_str)
		else:
			break
	small_bodies_group.finish_binary_import()
	_running_count += small_bodies_group.get_number()
	# register in IVSmallBodiesManager
	if is_trojans:
		_small_bodies_manager.lagrange_points[group] = lagrange_point
	_small_bodies_manager.groups_by_name[group] = small_bodies_group


func _load_binary(small_bodies_group: IVSmallBodiesGroup, group: String, mag_str: String) -> void:
	var binary_name := group + "." + mag_str + ".vbinary"
	var path: String = _asteroid_binaries_dir.plus_file(binary_name)
	var binary := File.new()
	if binary.open(path, File.READ) != OK: # skip if file doesn't exist
		return
	assert(DPRINT and print("Reading binary %s" % path) or true)
	small_bodies_group.read_binary(binary)
	binary.close()
