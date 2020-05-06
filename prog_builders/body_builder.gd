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
const BodyFlags := Enums.BodyFlags

# project vars
var body_fields := {
	# property = table_field
	name = "key",
	class_type = "class_type",
	model_type = "model_type",
	light_type = "light_type",
	file_prefix = "file_prefix",
}
var body_fields_req := ["class_type", "model_type", "m_radius", "file_prefix"]

var flag_fields := {
	BodyFlags.IS_DWARF_PLANET : "dwarf",
	BodyFlags.IS_TIDALLY_LOCKED : "tidally_locked",
	BodyFlags.HAS_ATMOSPHERE : "atmosphere",
}

var properties_fields := {
	m_radius = "m_radius",
	e_radius = "e_radius", # set to m_radius if missing
	mass = "mass", # calculate from m_radius & density if missing
	gm = "GM", # calculate from mass if missing
	esc_vel = "esc_vel",
	surface_gravity = "surface_gravity",
	hydrostatic_equilibrium = "hydrostatic_equilibrium",
	mean_density = "density",
	albedo = "albedo",
	surf_pres = "surf_pres",
	surf_t = "surf_t",
	min_t = "min_t",
	max_t = "max_t",
	one_bar_t = "one_bar_t",
	half_bar_t = "half_bar_t",
	tenth_bar_t = "tenth_bar_t",
}
var properties_fields_req := ["m_radius"]

var rotations_fields := {
	rotation_period = "rotation",
	right_ascension = "RA",
	declination = "dec",
	axial_tilt = "axial_tilt",
}

# private
var _ecliptic_rotation: Basis = Global.ecliptic_rotation
var _settings: Dictionary = Global.settings
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
var _Rotations_: Script
var _Properties_: Script
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
	_Rotations_ = Global.script_classes._Rotations_
	_Properties_ = Global.script_classes._Properties_
	_texture_2d_dir = Global.asset_paths.texture_2d_dir

func build_from_table(table_name: String, row: int, parent: Body) -> Body:
	var body: Body = SaverLoader.make_object_or_scene(_Body_)
	_table_helper.build_object(body, table_name, row, body_fields, body_fields_req)
	# flags
	var flags := _table_helper.build_flags(0, table_name, row, flag_fields)
	if !parent:
		flags |= BodyFlags.IS_TOP # must be in Registrar.top_bodies
		flags |= BodyFlags.PROXY_STAR_SYSTEM
	var hydrostatic_equilibrium: int = _table_helper.get_enum(table_name, "hydrostatic_equilibrium", row)
	if hydrostatic_equilibrium >= Enums.KnowTypes.PROBABLY:
		flags |= BodyFlags.LIKELY_HYDROSTATIC_EQUILIBRIUM
	match table_name:
		"stars":
			flags |= BodyFlags.IS_STAR
			if flags & BodyFlags.IS_TOP:
				flags |= BodyFlags.IS_PRIMARY_STAR
		"planets":
			flags |= BodyFlags.IS_STAR_ORBITING
			if not flags & BodyFlags.IS_DWARF_PLANET:
				flags |= BodyFlags.IS_TRUE_PLANET
		"moons":
			flags |= BodyFlags.IS_MOON
			if flags & BodyFlags.LIKELY_HYDROSTATIC_EQUILIBRIUM \
					or _table_helper.get_bool(table_name, "force_navigator", row):
				flags |= BodyFlags.IS_NAVIGATOR_MOON
	body.flags = flags
	# orbit
	var time: float = _times[0]
	var orbit: Orbit
	if not body.flags & BodyFlags.IS_TOP:
		orbit = _orbit_builder.make_orbit_from_data(table_name, row, parent)
		body.orbit = orbit
	# properties
	var properties: Properties = _Properties_.new()
	body.properties = properties
	_table_helper.build_object(properties, table_name, row, properties_fields, properties_fields_req)
	body.system_radius = properties.m_radius * 10.0 # widens if satalletes are added
	if is_inf(properties.mass):
		var sig_digits := _table_helper.get_least_real_precision(table_name, ["density", "m_radius"], row)
		if sig_digits > 1:
			var mass := (PI * 4.0 / 3.0) * properties.mean_density * pow(properties.m_radius, 3.0)
			properties.mass = math.set_decimal_precision(mass, sig_digits)
	if is_inf(properties.gm): # planets table has mass, not GM
		var sig_digits := _table_helper.get_real_precision(table_name, "mass", row)
		if sig_digits > 1:
			if sig_digits > 6:
				sig_digits = 6 # limited by G precision
			var gm := G * properties.mass
			properties.gm = math.set_decimal_precision(gm, sig_digits)
	if is_inf(properties.esc_vel) or is_inf(properties.surface_gravity):
		if _table_helper.is_value(table_name, "GM", row):
			var sig_digits := _table_helper.get_least_real_precision(table_name, ["GM", "m_radius"], row)
			if sig_digits > 2:
				if is_inf(properties.esc_vel):
					var esc_vel := sqrt(2.0 * properties.gm / properties.m_radius)
					properties.esc_vel = math.set_decimal_precision(esc_vel, sig_digits - 1)
				if is_inf(properties.surface_gravity):
					var surface_gravity := properties.gm / pow(properties.m_radius, 2.0)
					properties.surface_gravity = math.set_decimal_precision(surface_gravity, sig_digits - 1)
		else: # planet w/ mass
			var sig_digits := _table_helper.get_least_real_precision(table_name, ["mass", "m_radius"], row)
			if sig_digits > 2:
				if is_inf(properties.esc_vel):
					if sig_digits > 6:
						sig_digits = 6
					var esc_vel := sqrt(2.0 * G * properties.mass / properties.m_radius)
					properties.esc_vel = math.set_decimal_precision(esc_vel, sig_digits - 1)
				if is_inf(properties.surface_gravity):
					var surface_gravity := G * properties.mass / pow(properties.m_radius, 2.0)
					properties.surface_gravity = math.set_decimal_precision(surface_gravity, sig_digits - 1)
	# orbit and rotations
	# We use definition of "axial tilt" as angle to a body's orbital plane
	# (excpept for primary star where we use ecliptic). North pole should
	# follow IAU definition (!= positive pole) except Pluto, which is
	# intentionally flipped.
	var rotations: Rotations = _Rotations_.new()
	body.rotations = rotations
	_table_helper.build_object(rotations, table_name, row, rotations_fields)
	if not flags & BodyFlags.IS_TIDALLY_LOCKED:
		assert(!is_inf(rotations.right_ascension) and !is_inf(rotations.declination))
		rotations.north_pole = _ecliptic_rotation * math.convert_equatorial_coordinates2(
				rotations.right_ascension, rotations.declination)
		# We have dec & RA for planets and we calculate axial_tilt from these
		# (overwriting table value, if exists). Results basically make sense for
		# the planets EXCEPT Uranus (flipped???) and Pluto (ah Pluto...).
		if orbit:
			rotations.axial_tilt = rotations.north_pole.angle_to(orbit.get_normal(time))
		else: # sun
			rotations.axial_tilt = rotations.north_pole.angle_to(ECLIPTIC_NORTH)
	else:
		rotations.rotation_period = TAU / orbit.get_mean_motion(time)
		# This is complicated! The Moon has axial tilt 6.5 degrees (to its 
		# orbital plane) and orbit inclination ~5 degrees. The resulting axial
		# tilt to ecliptic is 1.5 degrees.
		# For The Moon, axial precession and orbit nodal precession are both
		# 18.6 yr. So we apply below adjustment to north pole here AND in Body
		# after each orbit update. I don't think this is correct for other
		# moons, but all other moons have zero or very small axial tilt, so
		# inacuracy is small.
		rotations.north_pole = orbit.get_normal(time)
		if rotations.axial_tilt != 0.0:
			var correction_axis := rotations.north_pole.cross(orbit.reference_normal).normalized()
			rotations.north_pole = rotations.north_pole.rotated(correction_axis, rotations.axial_tilt)
	rotations.north_pole = rotations.north_pole.normalized()
	if orbit and orbit.is_retrograde(time): # retrograde
		rotations.rotation_period = -rotations.rotation_period
	# reference basis
	body.reference_basis = math.rotate_basis_pole(Basis(), rotations.north_pole)
	var rotation_0 := _table_helper.get_real(table_name, "rotate_adj", row)
	if rotation_0 and !is_inf(rotation_0):
		body.reference_basis = body.reference_basis.rotated(rotations.north_pole, rotation_0)
	# file import info
	var rings_prefix := _table_helper.get_string(table_name, "rings", row)
	if rings_prefix:
		var rings_radius := _table_helper.get_real(table_name, "rings_outer_radius", row)
		body.rings_info = [rings_prefix, rings_radius]
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
		_model_builder.add_model(body, not body.flags & BodyFlags.IS_NAVIGATOR_MOON)
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
	if body.flags & BodyFlags.IS_STAR:
		var slice_name = body.file_prefix + "_slice"
		body.texture_slice_2d = file_utils.find_resource(_texture_2d_dir, slice_name)
		if !body.texture_slice_2d:
			body.texture_slice_2d = Global.assets.fallback_star_slice
