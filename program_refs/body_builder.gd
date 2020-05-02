# body_builder.gd
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
# Be carful to test for table nulls explicitly! (0.0 != null)

extends Reference
class_name BodyBuilder

const math := preload("res://ivoyager/static/math.gd") # =Math when issue #37529 fixed
const file_utils := preload("res://ivoyager/static/file_utils.gd")

const DPRINT := false
const ECLIPTIC_NORTH := Vector3(0.0, 0.0, 1.0)
const G := UnitDefs.GRAVITATIONAL_CONSTANT

# project vars
var major_moon_gm := 1.0 * UnitDefs.STANDARD_GM # eg, Mimus 2.5, Miranda 4.4
var property_fields := {
	# property = table_field
	name = "key",
	class_type = "class_type",
	model_type = "model_type",
	light_type = "light_type",
	is_dwarf_planet = "dwarf",
	has_minor_moons = "minor_moons",
	has_atmosphere = "atmosphere",
	m_radius = "m_radius",
	e_radius = "e_radius", # set to m_radius if missing
	mass = "mass", # calculate from m_radius & density if missing
	gm = "GM", # calculate from mass if missing
	tidally_locked = "tidally_locked",
	rotation_period = "rotation",
	right_ascension = "RA",
	declination = "dec",
	axial_tilt = "axial_tilt",
	esc_vel = "esc_vel",
	surface_gravity = "surface_gravity",
	density = "density",
	albedo = "albedo",
	surf_pres = "surf_pres",
	surf_t = "surf_t",
	min_t = "min_t",
	max_t = "max_t",
	one_bar_t = "one_bar_t",
	half_bar_t = "half_bar_t",
	tenth_bar_t = "tenth_bar_t",
	file_prefix = "file_prefix",
}
var required_fields := ["class_type", "model_type", "m_radius", "file_prefix"] # assert if missing

# private
var _ecliptic_rotation: Basis = Global.ecliptic_rotation
var _settings: Dictionary = Global.settings
var _table_data: Dictionary = Global.table_data
var _table_fields: Dictionary = Global.table_fields
var _table_data_types: Dictionary = Global.table_data_types
var _table_rows: Dictionary = Global.table_rows
var _times: Array = Global.times
var _registrar: Registrar
var _model_builder: ModelBuilder
var _rings_builder: RingsBuilder
var _light_builder: LightBuilder
var _huds_builder: HUDsBuilder
var _selection_builder: SelectionBuilder
var _orbit_builder: OrbitBuilder
var _table_helper: TableHelper
var _Body_: Script
var _texture_2d_dir: String
var _satellite_indexes := {} # passed to & shared by Body instances

func project_init() -> void:
	Global.connect("system_tree_built_or_loaded", self, "_init_unpersisted")
	_registrar = Global.program.Registrar
	_model_builder = Global.program.ModelBuilder
	_rings_builder = Global.program.RingsBuilder
	_light_builder = Global.program.LightBuilder
	_huds_builder = Global.program.HUDsBuilder
	_selection_builder = Global.program.SelectionBuilder
	_orbit_builder = Global.program.OrbitBuilder
	_table_helper = Global.program.TableHelper
	_Body_ = Global.script_classes._Body_
	_texture_2d_dir = Global.asset_paths.texture_2d_dir

func build(table_name: String, row: int, parent: Body) -> Body:
	var row_data: Array = _table_data[table_name][row]
	var fields: Dictionary = _table_fields[table_name]
	var data_types: Array = _table_data_types[table_name]
	var body: Body = SaverLoader.make_object_or_scene(_Body_)
	_table_helper.build_object(body, row_data, fields, data_types, property_fields, required_fields)
	if !parent:
		body.is_top = true
	match table_name:
		"stars":
			body.is_star = true
		"planets":
			body.is_planet = true
		"moons":
			body.is_moon = true
	var time: float = _times[0]
	var orbit: Orbit
	if !body.is_top:
		orbit = _orbit_builder.make_orbit_from_data(parent, row_data, fields, data_types, time)
		body.orbit = orbit
	if body.e_radius == INF:
		body.e_radius = body.m_radius
	body.system_radius = body.e_radius * 10.0 # widens if satalletes are added
	if body.mass == INF and body.density != INF:
		body.mass = (PI * 4.0 / 3.0) * body.density * pow(body.m_radius, 3.0)
	if body.gm == -INF and body.mass != INF:
		body.gm = G * body.mass
	if body.is_moon and body.gm < major_moon_gm and !row_data[fields.force_major]:
		body.is_minor_moon = true
	if body.esc_vel == -INF and body.gm != -INF:
		body.esc_vel = sqrt(2.0 * body.gm / body.m_radius)
	if body.surface_gravity == -INF and body.gm != -INF:
		body.surface_gravity = body.gm / pow(body.m_radius, 2.0)
	body.selection_type = _get_selection_type(body)
	# orbit and axis
	if parent and parent.is_star:
		body.is_star_orbiting = true
	if body.tidally_locked:
		body.rotation_period = TAU / orbit.get_mean_motion(time)
	# We use definition of "axial tilt" as angle to a body's orbital plane
	# (excpept for primary star where we use ecliptic). North pole should
	# follow IAU definition (!= positive pole) except Pluto, which is
	# intentionally flipped.
	if !body.tidally_locked:
		assert(body.right_ascension != -INF and body.declination != -INF)
		body.north_pole = _ecliptic_rotation * math.convert_equatorial_coordinates2(
				body.right_ascension, body.declination)
		# We have dec & RA for planets and we calculate axial_tilt from these
		# (overwriting table value, if exists). Results basically make sense for
		# the planets EXCEPT Uranus (flipped???) and Pluto (ah Pluto...).
		if orbit:
			body.axial_tilt = body.north_pole.angle_to(orbit.get_normal(time))
		else: # sun
			body.axial_tilt = body.north_pole.angle_to(ECLIPTIC_NORTH)
	else:
		# This is complicated! The Moon has axial tilt 6.5 degrees (to its 
		# orbital plane) and orbit inclination ~5 degrees. The resulting axial
		# tilt to ecliptic is 1.5 degrees.
		# For The Moon, axial precession and orbit nodal precession are both
		# 18.6 yr. So we apply below adjustment to north pole here AND in Body
		# after each orbit update. I don't think this is correct for other
		# moons, but all other moons have zero or very small axial tilt, so
		# inacuracy is small.
		body.north_pole = orbit.get_normal(time)
		if body.axial_tilt != 0.0:
			var correction_axis := body.north_pole.cross(orbit.reference_normal).normalized()
			body.north_pole = body.north_pole.rotated(correction_axis, body.axial_tilt)
	body.north_pole = body.north_pole.normalized()
	if orbit and orbit.is_retrograde(time): # retrograde
		body.rotation_period = -body.rotation_period
	# reference basis
	body.reference_basis = math.rotate_basis_pole(Basis(), body.north_pole)
	if fields.has("rotate_adj") and row_data[fields.rotate_adj]: # skips if 0
		body.reference_basis = body.reference_basis.rotated(body.north_pole,
				row_data[fields.rotate_adj])
	# file import info
	if fields.has("rings") and row_data[fields.rings]:
		body.rings_info = [row_data[fields.rings], row_data[fields.rings_outer_radius]]
	# parent modifications
	if parent and orbit:
		var semimajor_axis := orbit.get_semimajor_axis(time)
		if parent.system_radius < semimajor_axis:
			parent.system_radius = semimajor_axis
	if !parent:
		_registrar.register_top_body(body)
	_registrar.register_body(body)
	_selection_builder.build_and_register(body, parent)
	return body

func _get_selection_type(body: Body) -> int:
	if body.is_star:
		return Enums.SelectionTypes.SELECTION_STAR
	if body.is_dwarf_planet:
		return Enums.SelectionTypes.SELECTION_DWARF_PLANET
	if body.is_planet:
		return Enums.SelectionTypes.SELECTION_PLANET
	if body.is_minor_moon:
		return Enums.SelectionTypes.SELECTION_MINOR_MOON
	if body.is_moon:
		return Enums.SelectionTypes.SELECTION_MAJOR_MOON
	return -1

func _init_unpersisted(_is_new_game: bool) -> void:
	_satellite_indexes.clear()
	for body in _registrar.bodies:
		if body:
			_build_unpersisted(body)

func _build_unpersisted(body: Body) -> void:
	body.satellite_indexes = _satellite_indexes
	var satellites := body.satellites
	var satellite_index := 0
	var n_satellites := satellites.size()
	while satellite_index < n_satellites:
		var satellite: Body = satellites[satellite_index]
		if satellite:
			_satellite_indexes[satellite] = satellite_index
		satellite_index += 1
	if body.model_type != -1:
		_model_builder.add_model(body, body.is_minor_moon)
	if body.rings_info:
		_rings_builder.add_rings(body)
	if body.light_type != -1:
		_light_builder.add_starlight(body)
	if body.orbit:
		_huds_builder.add_orbit(body)
	_huds_builder.add_icon(body)
	_huds_builder.add_label(body)
	body.set_hud_too_close(_settings.hide_hud_when_close)
	body.texture_2d = file_utils.find_resource(_texture_2d_dir, body.file_prefix)
	if !body.texture_2d:
		body.texture_2d = Global.assets.fallback_texture_2d
	if body.is_star:
		var slice_name = body.file_prefix + "_slice"
		body.texture_slice_2d = file_utils.find_resource(_texture_2d_dir, slice_name)
		if !body.texture_slice_2d:
			body.texture_slice_2d = Global.assets.fallback_star_slice
