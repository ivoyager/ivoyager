# minor_bodies_builder.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
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
# TODO: simplify code with the new TableReader class.


extends Reference
class_name MinorBodiesBuilder

signal minor_bodies_added()

const DPRINT = false
const BINARY_FILE_MAGNITUDES = ["11.0", "11.5", "12.0", "12.5", "13.0", "13.5",
	"14.0", "14.5", "15.0", "15.5", "16.0", "16.5", "17.0", "17.5", "18.0",
	"18.5", "99.9"]

# dependencies
var _settings: Dictionary = Global.settings
var _table_reader: TableReader
var _l_point_builder: LPointBuilder
var _minor_bodies_manager: MinorBodiesManager
var _points_manager: PointsManager
var _registrar: Registrar
var _AsteroidGroup_: Script
var _HUDPoints_: Script
var _asteroid_binaries_dir: String
var _asteroid_mag_cutoff_override: float = Global.asteroid_mag_cutoff_override

var _running_count := 0

# ************************ PUBLIC FUNCTIONS ***********************************

func project_init() -> void:
	Global.connect("system_tree_built_or_loaded", self, "_init_unpersisted")
	_table_reader = Global.program.TableReader
	_l_point_builder = Global.program.LPointBuilder
	_minor_bodies_manager = Global.program.MinorBodiesManager
	_points_manager = Global.program.PointsManager
	_registrar = Global.program.Registrar
	_AsteroidGroup_ = Global.script_classes._AsteroidGroup_
	_HUDPoints_ = Global.script_classes._HUDPoints_
	_asteroid_binaries_dir = Global.asset_paths.asteroid_binaries_dir
	
func build() -> void:
	if Global.skip_asteroids:
		return
	print("Adding minor bodies...")
	var star: Body = _registrar.top_bodies[0] # TODO: multistar
	_load_binaries(star)
	print("Added orbital data for ", _running_count, " asteroids")
	emit_signal("minor_bodies_added")

# ************************ PRIVATE FUNCTIONS **********************************

func _init_unpersisted(_is_new_game: bool) -> void:
	var group_refs_by_name := _minor_bodies_manager.group_refs_by_name
	for group_name in group_refs_by_name:
		var asteroid_group := group_refs_by_name[group_name] as AsteroidGroup
		if asteroid_group:
			_init_hud_points(asteroid_group, group_name)

func _init_hud_points(asteroid_group: AsteroidGroup, group_name: String) -> void:
	var hud_points: HUDPoints = SaverLoader.make_object_or_scene(_HUDPoints_)
	hud_points.init(asteroid_group, _settings.asteroid_point_color)
	hud_points.draw_points()
	_points_manager.register_points_group(hud_points, group_name)
	_points_manager.register_points_group_in_category(group_name, "all_asteroids")
	var star := asteroid_group.star
	star.add_child(hud_points)

func _load_binaries(star: Body) -> void:
	var n_asteroid_groups := _table_reader.get_n_table_rows("asteroid_groups")
	var row := 0
	while row < n_asteroid_groups:
		var group := _table_reader.get_string("asteroid_groups", "group", row)
		var trojan_of := _table_reader.get_body("asteroid_groups", "trojan_of", row)
		if !trojan_of:
			_load_group_binaries(star, group, row)
		else: # trojans!
			for l_point in [4, 5]: # split data table JT i!JT4 & JT5
				var l_group: String = group + str(l_point)
				_load_group_binaries(star, l_group, row, l_point, trojan_of)
		row += 1
	
func _load_group_binaries(star: Body, group: String, table_row: int, l_point := -1,
		trojan_of: Body = null) -> void:
	assert(l_point == -1 or l_point == 4 or l_point == 5)
	var is_trojans := l_point != -1
	var lagrange_point: LPoint
	# make the AsteroidGroup
	var asteroid_group: AsteroidGroup = _AsteroidGroup_.new()
	if !is_trojans:
		asteroid_group.init(star, group)
	else:
		lagrange_point = _l_point_builder.get_or_make_lagrange_point(trojan_of, l_point)
		assert(lagrange_point)
		asteroid_group.init_trojans(star, group, lagrange_point)
	var mag_cutoff := 100.0
	if _asteroid_mag_cutoff_override != INF:
		mag_cutoff = _asteroid_mag_cutoff_override
	else:
		mag_cutoff = _table_reader.get_real("asteroid_groups", "mag_cutoff", table_row)
	for mag_str in BINARY_FILE_MAGNITUDES:
		if float(mag_str) < mag_cutoff:
			_load_binary(asteroid_group, group, mag_str)
		else:
			break
	asteroid_group.finish_binary_import()
	_running_count += asteroid_group.get_number()
	# register in MinorBodiesManager
	if is_trojans:
		_minor_bodies_manager.lagrange_points[group] = lagrange_point
	_minor_bodies_manager.group_refs_by_name[group] = asteroid_group
	_minor_bodies_manager.group_names.append(group)
	_minor_bodies_manager.ids_by_group[group] = []

func _load_binary(asteroid_group: AsteroidGroup, group: String, mag_str: String) -> void:
	var binary_name := group + "." + mag_str + ".vbinary"
	var path: String = _asteroid_binaries_dir.plus_file(binary_name)
	var binary := File.new()
	if binary.open(path, File.READ) != OK: # skip if file doesn't exist
		return
	assert(DPRINT and print("Reading binary %s" % path) or true)
	asteroid_group.read_binary(binary)
	binary.close()
	
	

