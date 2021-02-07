# body_builder.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield
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

extends Reference
class_name BodyBuilder

const math := preload("res://ivoyager/static/math.gd") # =Math when issue #37529 fixed
const file_utils := preload("res://ivoyager/static/file_utils.gd")

const DPRINT := false
const ECLIPTIC_Z := Vector3(0.0, 0.0, 1.0)
const G := UnitDefs.GRAVITATIONAL_CONSTANT
const BodyFlags := Enums.BodyFlags

# project vars
var body_fields := {
	# property = table_field
	name = "key",
	symbol = "symbol",
	class_type = "class_type",
	model_type = "model_type",
	light_type = "light_type",
}
var body_fields_req := ["class_type", "model_type", "m_radius"]

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
var _bodies_2d_search: Array = Global.bodies_2d_search
var _times: Array = Global.times
var _body_registry: BodyRegistry
var _model_builder: ModelBuilder
var _rings_builder: RingsBuilder
var _light_builder: LightBuilder
var _huds_builder: HUDsBuilder
var _selection_builder: SelectionBuilder
var _orbit_builder: OrbitBuilder
var _scheduler: Scheduler
var _table_reader: TableReader
var _Body_: Script
var _ModelGeometry_: Script
var _Properties_: Script
var _StarRegulator_: Script
var _fallback_body_2d: Texture
var _satellite_indexes := {} # passed to & shared by Body instances


func project_init() -> void:
	Global.connect("system_tree_built_or_loaded", self, "_init_unpersisted")
	_body_registry = Global.program.BodyRegistry
	_model_builder = Global.program.ModelBuilder
	_rings_builder = Global.program.RingsBuilder
	_light_builder = Global.program.LightBuilder
	_huds_builder = Global.program.HUDsBuilder
	_selection_builder = Global.program.SelectionBuilder
	_orbit_builder = Global.program.OrbitBuilder
	_scheduler = Global.program.Scheduler
	_table_reader = Global.program.TableReader
	_Body_ = Global.script_classes._Body_
	_ModelGeometry_ = Global.script_classes._ModelGeometry_
	_Properties_ = Global.script_classes._Properties_
	_fallback_body_2d = Global.assets.fallback_body_2d

func build_from_table(table_name: String, row: int, parent: Body) -> Body:
	var body: Body = SaverLoader.make_object_or_scene(_Body_)
	_table_reader.build_object2(body, table_name, row, body_fields, body_fields_req)
	# flags
	var flags := _table_reader.build_flags(0, table_name, row, flag_fields)
	if !parent:
		flags |= BodyFlags.IS_TOP # must be in BodyRegistry.top_bodies
		flags |= BodyFlags.PROXY_STAR_SYSTEM
	var hydrostatic_equilibrium: int = _table_reader.get_enum(table_name, "hydrostatic_equilibrium", row)
	if hydrostatic_equilibrium >= Enums.ConfidenceType.PROBABLY:
		flags |= BodyFlags.LIKELY_HYDROSTATIC_EQUILIBRIUM
	match table_name:
		"stars":
			flags |= BodyFlags.IS_STAR
			if flags & BodyFlags.IS_TOP:
				flags |= BodyFlags.IS_PRIMARY_STAR
			flags |= BodyFlags.NEVER_SLEEP
		"planets":
			flags |= BodyFlags.IS_STAR_ORBITING
			if not flags & BodyFlags.IS_DWARF_PLANET:
				flags |= BodyFlags.IS_TRUE_PLANET
			flags |= BodyFlags.NEVER_SLEEP
		"moons":
			flags |= BodyFlags.IS_MOON
			if flags & BodyFlags.LIKELY_HYDROSTATIC_EQUILIBRIUM \
					or _table_reader.get_bool(table_name, "force_navigator", row):
				flags |= BodyFlags.IS_NAVIGATOR_MOON
	body.flags = flags # there may be more flags set below
	# orbit
	var time: float = _times[0]
	var orbit: Orbit
	if not body.flags & BodyFlags.IS_TOP:
		orbit = _orbit_builder.make_orbit_from_data(table_name, row, parent)
		body.set_orbit(orbit)
	# properties
	var properties: Properties = _Properties_.new()
	body.properties = properties
	_table_reader.build_object2(properties, table_name, row, properties_fields, properties_fields_req)
	body.system_radius = properties.m_radius * 10.0 # widens if satalletes are added
	if !is_nan(properties.e_radius):
		properties.p_radius = 3.0 * properties.m_radius - 2.0 * properties.e_radius
	else:
		body.flags |= BodyFlags.DISPLAY_M_RADIUS
	if is_nan(properties.mass):
		var sig_digits := _table_reader.get_least_real_precision(table_name, ["density", "m_radius"], row)
		if sig_digits > 1:
			var mass := (PI * 4.0 / 3.0) * properties.mean_density * pow(properties.m_radius, 3.0)
			properties.mass = math.set_decimal_precision(mass, sig_digits)
	if is_nan(properties.gm): # planets table has mass, not GM
		var sig_digits := _table_reader.get_real_precision(table_name, "mass", row)
		if sig_digits > 1:
			if sig_digits > 6:
				sig_digits = 6 # limited by G precision
			var gm := G * properties.mass
			properties.gm = math.set_decimal_precision(gm, sig_digits)
	if is_nan(properties.esc_vel) or is_nan(properties.surface_gravity):
		if _table_reader.has_value(table_name, "GM", row):
			var sig_digits := _table_reader.get_least_real_precision(table_name, ["GM", "m_radius"], row)
			if sig_digits > 2:
				if is_nan(properties.esc_vel):
					var esc_vel := sqrt(2.0 * properties.gm / properties.m_radius)
					properties.esc_vel = math.set_decimal_precision(esc_vel, sig_digits - 1)
				if is_nan(properties.surface_gravity):
					var surface_gravity := properties.gm / pow(properties.m_radius, 2.0)
					properties.surface_gravity = math.set_decimal_precision(surface_gravity, sig_digits - 1)
		else: # planet w/ mass
			var sig_digits := _table_reader.get_least_real_precision(table_name, ["mass", "m_radius"], row)
			if sig_digits > 2:
				if is_nan(properties.esc_vel):
					if sig_digits > 6:
						sig_digits = 6
					var esc_vel := sqrt(2.0 * G * properties.mass / properties.m_radius)
					properties.esc_vel = math.set_decimal_precision(esc_vel, sig_digits - 1)
				if is_nan(properties.surface_gravity):
					var surface_gravity := G * properties.mass / pow(properties.m_radius, 2.0)
					properties.surface_gravity = math.set_decimal_precision(surface_gravity, sig_digits - 1)
	# orbit and rotations
	# We use definition of "axial tilt" as angle to a body's orbital plane
	# (excpept for primary star where we use ecliptic). North pole should
	# follow IAU definition (!= positive pole) except Pluto, which is
	# intentionally flipped.
	var model_geometry: ModelGeometry = _ModelGeometry_.new()
	body.model_geometry = model_geometry
	_table_reader.build_object2(model_geometry, table_name, row, rotations_fields)
	if not flags & BodyFlags.IS_TIDALLY_LOCKED:
		assert(!is_nan(model_geometry.right_ascension) and !is_nan(model_geometry.declination))
		model_geometry.north_pole = _ecliptic_rotation * math.convert_spherical2(
				model_geometry.right_ascension, model_geometry.declination)
		# We have dec & RA for planets and we calculate axial_tilt from these
		# (overwriting table value, if exists). Results basically make sense for
		# the planets EXCEPT Uranus (flipped???) and Pluto (ah Pluto...).
		if orbit:
			model_geometry.axial_tilt = model_geometry.north_pole.angle_to(orbit.get_normal(time))
		else: # sun
			model_geometry.axial_tilt = model_geometry.north_pole.angle_to(ECLIPTIC_Z)
	else:
		model_geometry.rotation_period = TAU / orbit.get_mean_motion(time)
		# This is complicated! The Moon has axial tilt 6.5 degrees (to its 
		# orbital plane) and orbit inclination ~5 degrees. The resulting axial
		# tilt to ecliptic is 1.5 degrees.
		# For The Moon, axial precession and orbit nodal precession are both
		# 18.6 yr. So we apply below adjustment to north pole here AND in Body
		# after each orbit update. I don't think this is correct for other
		# moons, but all other moons have zero or very small axial tilt, so
		# inacuracy is small.
		model_geometry.north_pole = orbit.get_normal(time)
		if model_geometry.axial_tilt != 0.0:
			var correction_axis := model_geometry.north_pole.cross(orbit.reference_normal).normalized()
			model_geometry.north_pole = model_geometry.north_pole.rotated(correction_axis, model_geometry.axial_tilt)
	model_geometry.north_pole = model_geometry.north_pole.normalized()
	if orbit and orbit.is_retrograde(time): # retrograde
		model_geometry.rotation_period = -model_geometry.rotation_period
	# body reference basis
	var basis_at_epoch := math.rotate_basis_z(Basis.IDENTITY, model_geometry.north_pole)
	var total_rotation: float
	if flags & BodyFlags.IS_TIDALLY_LOCKED:
		# By definition, longitude 0.0 is the mean parent facing side.
		total_rotation = orbit.get_mean_longitude(0.0) - PI
	elif orbit:
		# Table value "longitude_at_epoch" is planetocentric longitude facing
		# solar system barycenter at epoch.
		total_rotation = orbit.get_true_longitude(0.0) - PI
		var longitude_at_epoch := _table_reader.get_real(table_name, "longitude_at_epoch", row)
		if longitude_at_epoch and !is_nan(longitude_at_epoch):
			total_rotation += longitude_at_epoch
	basis_at_epoch = basis_at_epoch.rotated(model_geometry.north_pole, total_rotation)
	model_geometry.set_basis_at_epoch(basis_at_epoch)
	# file import info
	var file_prefix := _table_reader.get_string(table_name, "file_prefix", row)
	body.file_info[0] = file_prefix
	var rings := _table_reader.get_string(table_name, "rings", row)
	if rings:
		if body.file_info.size() < 4:
			body.file_info.resize(4)
		body.file_info[2] = rings
		body.file_info[3] = _table_reader.get_real(table_name, "rings_radius", row)
	# parent modifications
	if parent and orbit:
		var semimajor_axis := orbit.get_semimajor_axis(time)
		if parent.system_radius < semimajor_axis:
			parent.system_radius = semimajor_axis
	if !parent:
		_body_registry.register_top_body(body)
	_body_registry.register_body(body)
	_selection_builder.build_and_register(body, parent)
	body.hide()
	return body

func _init_unpersisted(is_new_game: bool) -> void:
	_satellite_indexes.clear()
	for body in _body_registry.bodies:
		if body:
			_build_unpersisted(body, is_new_game)

func _build_unpersisted(body: Body, is_new_game: bool) -> void:
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
		var lazy_init: bool = body.flags & BodyFlags.IS_MOON  \
				and not body.flags & BodyFlags.IS_NAVIGATOR_MOON
		_model_builder.add_model(body, lazy_init)
	if body.file_info.size() > 2 and body.file_info[2]:
		_rings_builder.add_rings(body)
	if body.light_type != -1:
		_light_builder.add_omni_light(body)
	if body.orbit:
		_huds_builder.add_orbit(body)
		if !is_new_game:
			body.reset_orbit()
	_huds_builder.add_label(body)
	body.set_hud_too_close(_settings.hide_hud_when_close)
	var file_prefix: String = body.file_info[0]
	body.texture_2d = file_utils.find_and_load_resource(_bodies_2d_search, file_prefix)
	if !body.texture_2d:
		body.texture_2d = _fallback_body_2d
	if body.flags & BodyFlags.IS_STAR:
		var slice_name = file_prefix + "_slice"
		body.texture_slice_2d = file_utils.find_and_load_resource(_bodies_2d_search, slice_name)
