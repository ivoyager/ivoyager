# minor_bodies_builder.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2019 Charlie Whitfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# *****************************************************************************
#

extends Reference
class_name MinorBodiesBuilder

signal minor_bodies_added()

const DPRINT = false
const BINARY_FILE_MAGNITUDES = ["11.0", "11.5", "12.0", "12.5", "13.0", "13.5",
	"14.0", "14.5", "15.0", "15.5", "16.0", "16.5", "17.0", "17.5", "18.0",
	"18.5", "99.9"]

# dependencies
var _settings: Dictionary = Global.settings
var _table_data: Dictionary = Global.table_data
var _l_point_builder: LPointBuilder
var _minor_bodies_manager: MinorBodiesManager
var _points_manager: PointsManager
var _registrar: Registrar
var _file_helper: FileHelper
var _AsteroidGroup_: Script
var _HUDPoints_: Script

# ************************ PUBLIC FUNCTIONS ***********************************

func project_init() -> void:
	Global.connect("system_tree_built_or_loaded", self, "_init_unpersisted")
	_l_point_builder = Global.objects.LPointBuilder
	_minor_bodies_manager = Global.objects.MinorBodiesManager
	_points_manager = Global.objects.PointsManager
	_registrar = Global.objects.Registrar
	_file_helper = Global.objects.FileHelper
	_AsteroidGroup_ = Global.script_classes._AsteroidGroup_
	_HUDPoints_ = Global.script_classes._HUDPoints_
	
func build() -> void:
	if Global.skip_asteroids:
		return
	print("Adding minor bodies...")
	var star := _registrar.top_body # TODO: multistar
	_load_binaries(star)
	emit_signal("minor_bodies_added")

# ************************ PRIVATE FUNCTIONS **********************************

func _init_unpersisted(_is_new_game: bool) -> void:
	var group_refs_by_name := _minor_bodies_manager.group_refs_by_name
	for group_name in group_refs_by_name:
		var asteroid_group := group_refs_by_name[group_name] as AsteroidGroup
		if asteroid_group:
			_init_hud_points(asteroid_group, group_name)

func _init_hud_points(asteroid_group: AsteroidGroup, group_name: String) -> void:
	var hud_points: HUDPoints = _file_helper.make_object_or_scene(_HUDPoints_)
	hud_points.init(asteroid_group, _settings.asteroid_point_color)
	hud_points.draw_points()
	_points_manager.register_points_group(hud_points, group_name)
	_points_manager.register_points_group_in_category(group_name, "all_asteroids")
	var star := asteroid_group.star
	star.add_child(hud_points)

func _load_binaries(star: Body) -> void:
	for group_data in _table_data.asteroid_group_data:
		var table_group: String = group_data.group
		if !group_data.has("trojan_of"):
			_load_group_binaries(star, table_group, group_data)
		else: # trojans!
			for l_point in [4, 5]: # split data table JT i!JT4 & JT5
				var l_group: String = table_group + str(l_point)
				_load_group_binaries(star, l_group, group_data, l_point)
	
func _load_group_binaries(star: Body, group: String, group_data: Dictionary, l_point: int = -1) -> void:
	var is_trojans := l_point != -1
	var lagrange_point: LagrangePoint
	# make the AsteroidGroup
	var asteroid_group: AsteroidGroup = _AsteroidGroup_.new()
#	var asteroid_group: AsteroidGroup = _file_helper.make_object_or_scene(_AsteroidGroup_)
	if !is_trojans:
		asteroid_group.init(star, group)
	else:
		var planet_key: String = group_data.trojan_of
		var planet: Body = _registrar.bodies_by_name[planet_key]
		lagrange_point = _l_point_builder.get_or_make_lagrange_point(planet, l_point)
		assert(lagrange_point)
		asteroid_group.init_trojans(star, group, lagrange_point)
	var mag_cutoff := 100.0
	if group_data.has("mag_cutoff"):
		mag_cutoff = group_data.mag_cutoff
	for mag_str in BINARY_FILE_MAGNITUDES:
		if float(mag_str) < mag_cutoff:
			_load_binary(asteroid_group, group, mag_str)
		else:
			break
	asteroid_group.finish_binary_import()
	# register in MinorBodiesManager
	if is_trojans:
		_minor_bodies_manager.lagrange_points[group] = lagrange_point
	_minor_bodies_manager.group_refs_by_name[group] = asteroid_group
	_minor_bodies_manager.group_names.append(group)
	_minor_bodies_manager.ids_by_group[group] = []

func _load_binary(asteroid_group: AsteroidGroup, group: String, mag_str: String) -> void:
	var binary_name := group + "." + mag_str + ".vbinary"
	var path: String = Global.asteroid_binaries_dir.plus_file(binary_name)
	var binary := File.new()
	if binary.open(path, File.READ) != OK: # skip if file doesn't exist
		return
	assert(DPRINT and print("Reading binary %s" % path) or true)
	asteroid_group.read_binary(binary)
	binary.close()
	
	

