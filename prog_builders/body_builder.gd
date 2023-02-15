# body_builder.gd
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
class_name IVBodyBuilder
extends Reference

# Builds IVBody from data tables.


const DPRINT := false
const ECLIPTIC_Z := Vector3(0.0, 0.0, 1.0)
const G := IVUnits.GRAVITATIONAL_CONSTANT
const BodyFlags := IVEnums.BodyFlags

# project vars
var keep_real_precisions := true # remember table sig. digits (probably don't need for games)

var characteristics_fields := [ # only added if exists
	"symbol",
	"hud_name",
	"body_class",
	"model_type",
	"light_type",
	"omni_light_type",
	"omni_light_type_gles2",
	"file_prefix",
	"rings_file_prefix",
	"rings_radius",
	"n_kn_planets",
	"n_kn_dwf_planets",
	"n_kn_minor_planets",
	"n_kn_comets",
	"n_nat_satellites",
	"n_kn_nat_satellites",
	"n_kn_quasi_satellites",
	"GM",
	"mass",
	"surface_gravity",
	"esc_vel",
	"m_radius",
	"e_radius",
	"right_ascension",
	"declination",
	"longitude_at_epoch",
	"rotation_period",
	"mean_density",
	"hydrostatic_equilibrium",
	"albedo",
	"surf_t",
	"min_t",
	"max_t",
	"temp_center",
	"temp_photosphere",
	"temp_corona",
	"surf_pres",
	"trace_pres",
	"trace_pres_low",
	"trace_pres_high",
	"one_bar_t",
	"half_bar_t",
	"tenth_bar_t",
	"galactic_orbital_speed",
	"velocity_vs_cmb",
	"velocity_vs_near_stars",
	"dist_galactic_core",
	"galactic_period",
	"stellar_classification",
	"absolute_magnitude",
	"luminosity",
	"color_b_v",
	"metallicity",
	"age",
]

var flag_fields := {
	BodyFlags.IS_STAR : "star",
	BodyFlags.IS_PLANET : "planet",
	BodyFlags.IS_TRUE_PLANET : "true_planet",
	BodyFlags.IS_DWARF_PLANET : "dwarf_planet",
	BodyFlags.IS_MOON : "moon",
	BodyFlags.IS_TIDALLY_LOCKED : "tidally_locked",
	BodyFlags.IS_AXIS_LOCKED : "axis_locked",
	BodyFlags.TUMBLES_CHAOTICALLY : "tumbles_chaotically",
	BodyFlags.HAS_ATMOSPHERE : "atmosphere",
	BodyFlags.IS_GAS_GIANT : "gas_giant",
	BodyFlags.IS_ASTEROID : "asteroid",
	BodyFlags.IS_COMET : "comet",
	BodyFlags.IS_SPACECRAFT : "spacecraft",
	BodyFlags.IS_PLANETARY_MASS_OBJECT : "planetary_mass_object",
	BodyFlags.SHOW_IN_NAV_PANEL : "show_in_nav_panel",
}

# private
var _Body_: Script
var _orbit_builder: IVOrbitBuilder
var _composition_builder: IVCompositionBuilder
var _table_reader: IVTableReader
var _times: Array = IVGlobal.times
var _ecliptic_rotation: Basis = IVGlobal.ecliptic_rotation
var _table_name: String
var _row: int
var _real_precisions := {}


func _project_init() -> void:
	_Body_ = IVGlobal.script_classes._Body_
	_orbit_builder = IVGlobal.program.OrbitBuilder
	_composition_builder = IVGlobal.program.get("CompositionBuilder")
	_table_reader = IVGlobal.program.TableReader


func build_from_table(table_name: String, row: int, parent: IVBody) -> IVBody: # Main thread!
	_table_name = table_name
	_row = row
	var body: IVBody = _Body_.new()
	body.name = _table_reader.get_string(table_name, "name", row)
	_set_flags_from_table(body, parent)
	_set_orbit_from_table(body, parent)
	_set_characteristics_from_table(body)
	if _composition_builder:
		_composition_builder.add_compositions_from_table(body, table_name, row)
	if keep_real_precisions:
		body.characteristics.real_precisions = _real_precisions
		_real_precisions = {}
	return body


func _set_flags_from_table(body: IVBody, parent: IVBody) -> void:
	# flags
	var flags := _table_reader.get_flags(flag_fields, _table_name, _row)
	# All below are constructed (non-table) flags.
	if !parent:
		flags |= BodyFlags.IS_TOP # will add self to IVGlobal.top_bodies
		flags |= BodyFlags.IS_PRIMARY_STAR
		flags |= BodyFlags.PROXY_STAR_SYSTEM
	if flags & BodyFlags.IS_STAR:
		flags |= BodyFlags.NEVER_SLEEP
		flags |= BodyFlags.USE_CARDINAL_DIRECTIONS
	if flags & BodyFlags.IS_PLANET:
		flags |= BodyFlags.IS_STAR_ORBITING
		flags |= BodyFlags.NEVER_SLEEP
		flags |= BodyFlags.USE_CARDINAL_DIRECTIONS
	if flags & BodyFlags.IS_MOON:
		if flags & BodyFlags.SHOW_IN_NAV_PANEL:
			flags |= BodyFlags.IS_NAVIGATOR_MOON
		if flags & BodyFlags.IS_PLANETARY_MASS_OBJECT:
			flags |= BodyFlags.IS_PLANETARY_MASS_MOON
		else:
			flags |= BodyFlags.IS_NON_PLANETARY_MASS_MOON
		flags |= BodyFlags.USE_CARDINAL_DIRECTIONS
	if flags & BodyFlags.IS_ASTEROID:
		flags |= BodyFlags.IS_STAR_ORBITING
		flags |= BodyFlags.NEVER_SLEEP
	if flags & BodyFlags.IS_SPACECRAFT:
		flags |= BodyFlags.USE_PITCH_YAW
	body.flags = flags


func _set_orbit_from_table(body: IVBody, parent: IVBody) -> void:
	if body.flags & BodyFlags.IS_TOP:
		return
	var orbit := _orbit_builder.make_orbit_from_data(_table_name, _row, parent)
	body.set_orbit(orbit)


func _set_characteristics_from_table(body: IVBody) -> void:
	var characteristics := body.characteristics
	_table_reader.build_dictionary(characteristics, characteristics_fields, _table_name, _row)
	assert(characteristics.has("m_radius"))
	if keep_real_precisions:
		var precisions := _table_reader.get_real_precisions(characteristics_fields, _table_name, _row)
		var n_fields := characteristics_fields.size()
		var i := 0
		while i < n_fields:
			var precision: int = precisions[i]
			if precision != -1:
				var field: String = characteristics_fields[i]
				var index := "body/characteristics/" + field
				_real_precisions[index] = precision
			i += 1
	# Assign missing characteristics where we can
	if characteristics.has("e_radius"):
		characteristics.p_radius = 3.0 * characteristics.m_radius - 2.0 * characteristics.e_radius
		if keep_real_precisions:
			var precision := _table_reader.get_least_real_precision(_table_name, ["m_radius", "e_radius"], _row)
			_real_precisions["body/characteristics/p_radius"] = precision
	else:
		body.flags |= BodyFlags.DISPLAY_M_RADIUS
	if !characteristics.has("mass"): # moons.tsv has GM but not mass
		assert(_table_reader.has_real_value(_table_name, "GM", _row)) # table test
		# We could in principle calculate mass from GM, but small moon GM is poor
		# estimator. Instead use mean_density if we have it; otherwise, assign INF
		# for unknown mass.
		if characteristics.has("mean_density"):
			characteristics.mass = (PI * 4.0 / 3.0) * characteristics.mean_density * pow(characteristics.m_radius, 3.0)
			if keep_real_precisions:
				var precision := _table_reader.get_least_real_precision(_table_name, ["m_radius", "mean_density"], _row)
				_real_precisions["body/characteristics/mass"] = precision
		else:
			characteristics.mass = INF # displays "?"
	if !characteristics.has("GM"): # planets.tsv has mass, not GM
		assert(_table_reader.has_real_value(_table_name, "mass", _row))
		characteristics.GM = G * characteristics.mass
		if keep_real_precisions:
			var precision := _table_reader.get_real_precision(_table_name, "mass", _row)
			if precision > 6:
				precision = 6 # limited by G
			_real_precisions["body/characteristics/GM"] = precision
	if !characteristics.has("esc_vel") or !characteristics.has("surface_gravity"):
		if _table_reader.has_real_value(_table_name, "GM", _row):
			# Use GM to calculate missing esc_vel & surface_gravity, but only
			# if precision > 1.
			var precision := _table_reader.get_least_real_precision(_table_name, ["GM", "m_radius"], _row)
			if precision > 1:
				if !characteristics.has("esc_vel"):
					characteristics.esc_vel = sqrt(2.0 * characteristics.GM / characteristics.m_radius)
					if keep_real_precisions:
						_real_precisions["body/characteristics/esc_vel"] = precision
				if !characteristics.has("surface_gravity"):
					characteristics.surface_gravity = characteristics.GM / pow(characteristics.m_radius, 2.0)
					if keep_real_precisions:
						_real_precisions["body/characteristics/surface_gravity"] = precision
		else: # planet w/ mass
			# Use mass to calculate missing esc_vel & surface_gravity, but only
			# if precision > 1.
			var precision := _table_reader.get_least_real_precision(_table_name, ["mass", "m_radius"], _row)
			if precision > 1:
				if precision > 6:
					precision = 6 # limited by G
				if !characteristics.has("esc_vel"):
					characteristics.esc_vel = sqrt(2.0 * G * characteristics.mass / characteristics.m_radius)
					if keep_real_precisions:
						_real_precisions["body/characteristics/esc_vel"] = precision
				if !characteristics.has("surface_gravity"):
					characteristics.surface_gravity = G * characteristics.mass / pow(characteristics.m_radius, 2.0)
					if keep_real_precisions:
						_real_precisions["body/characteristics/surface_gravity"] = precision

