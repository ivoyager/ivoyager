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
# TODO: We need API to assist building Body not from table data.
#
# Note: below the huge build_from_table() function, we have functions that
# build unpersisted parts of Body as they are added to the SceneTree, including
# I/O threaded resource loading. These are rate-limiting for building the solar
# system. Hence, we use these to determine and signal "system_ready" and to
# run the progress bar.

extends Reference
class_name BodyBuilder

const math := preload("res://ivoyager/static/math.gd") # =Math when issue #37529 fixed
const file_utils := preload("res://ivoyager/static/file_utils.gd")

const DPRINT := false
const ECLIPTIC_Z := Vector3(0.0, 0.0, 1.0)
const G := UnitDefs.GRAVITATIONAL_CONSTANT
const BodyFlags := Enums.BodyFlags

# project vars - modify if body or body components are subclassed
var body_fields := ["name", "symbol", "class_type", "model_type", "light_type"]
var body_characteristics_fields := ["GM", "mass", "surface_gravity", "esc_vel", "m_radius", "e_radius",
	"mean_density", "hydrostatic_equilibrium", "albedo", "surf_t", "min_t", "max_t",
	"surf_pres", "trace_pres", "trace_pres_low", "trace_pres_high", "one_bar_t", "half_bar_t",
	"tenth_bar_t"]
var model_controller_fields := ["rotation_period", "right_ascension", "declination", "axial_tilt"]
var flag_fields := {
	BodyFlags.IS_DWARF_PLANET : "dwarf",
	BodyFlags.IS_TIDALLY_LOCKED : "tidally_locked",
	BodyFlags.HAS_ATMOSPHERE : "atmosphere",
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
var _composition_builder: CompositionBuilder
var _io_manager: IOManager
var _scheduler: Scheduler
var _table_reader: TableReader
var _main_prog_bar: MainProgBar
var _Body_: Script
var _ModelController_: Script
var _BodyCharacteristics_: Script
var _StarRegulator_: Script
var _fallback_body_2d: Texture

var progress := 0 # external progress bar read-only

var _is_building_system := false
var _system_build_count: int
var _system_finished_count: int
var _system_build_start_msec := 0

var _table_name: String
var _row: int

func init_system_build() -> void:
	# Track when Bodies are completely finished (including I/O threaded
	# resource loading) to signal "system_ready" and run the progress bar.
	progress = 0
	_is_building_system = true
	_system_build_count = 0
	_system_finished_count = 0
	_io_manager.callback(self, "_start_system_build_msec") # after existing I/O jobs
	if _main_prog_bar:
		_main_prog_bar.start(self)

func build_from_table(table_name: String, row: int, parent: Body) -> Body: # Main thread!
	_table_name = table_name
	_row = row
	var body: Body = _Body_.new()
	_table_reader.build_object(body, body_fields, table_name, row)
	_set_flags_from_table(body, parent)
	_set_orbit_from_table(body, parent)
	_set_body_characteristics_from_table(body)
	_set_model_controller_from_table(body)
	_set_file_info_from_table(body)
	_modify_parent(body, parent)
	_register(body, parent)
	_selection_builder.build_and_register(body, parent)
	body.hide()
	return body

func _set_flags_from_table(body: Body, parent: Body) -> void:
	# flags
	var flags := _table_reader.build_flags(0, flag_fields, _table_name, _row)
	if !parent:
		flags |= BodyFlags.IS_TOP # must be in BodyRegistry.top_bodies
		flags |= BodyFlags.PROXY_STAR_SYSTEM
	var hydrostatic_equilibrium: int = _table_reader.get_enum(_table_name, "hydrostatic_equilibrium", _row)
	if hydrostatic_equilibrium >= Enums.ConfidenceType.PROBABLY:
		flags |= BodyFlags.LIKELY_HYDROSTATIC_EQUILIBRIUM
	match _table_name:
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
					or _table_reader.get_bool(_table_name, "force_navigator", _row):
				flags |= BodyFlags.IS_NAVIGATOR_MOON
	body.flags = flags

func _set_orbit_from_table(body: Body, parent: Body) -> void:
	if body.flags & BodyFlags.IS_TOP:
		return
	var orbit := _orbit_builder.make_orbit_from_data(_table_name, _row, parent)
	body.set_orbit(orbit)

func _set_body_characteristics_from_table(body: Body) -> void:
	var body_characteristics: BodyCharacteristics = _BodyCharacteristics_.new()
	_table_reader.build_object(body_characteristics, body_characteristics_fields, _table_name, _row)
	body.system_radius = body_characteristics.m_radius * 10.0 # widens if satalletes are added
	if !is_nan(body_characteristics.e_radius):
		body_characteristics.is_oblate = true
		body_characteristics.p_radius = 3.0 * body_characteristics.m_radius - 2.0 * body_characteristics.e_radius
	else:
		body.flags |= BodyFlags.DISPLAY_M_RADIUS
	if is_inf(body_characteristics.mass): # missing in moon table
		# Could calculate from GM, but mean_density x m_radius is better
		if !is_nan(body_characteristics.mean_density):
			var sig_digits := _table_reader.get_least_real_precision(_table_name, ["mean_density", "m_radius"], _row)
			if sig_digits > 1:
				var mass := (PI * 4.0 / 3.0) * body_characteristics.mean_density * pow(body_characteristics.m_radius, 3.0)
				body_characteristics.mass = math.set_decimal_precision(mass, sig_digits)
	if is_nan(body_characteristics.GM): # planets table has mass, not GM
		var sig_digits := _table_reader.get_real_precision(_table_name, "mass", _row)
		if sig_digits > 1:
			if sig_digits > 6:
				sig_digits = 6 # limited by G precision
			var GM := G * body_characteristics.mass
			body_characteristics.GM = math.set_decimal_precision(GM, sig_digits)
	if is_nan(body_characteristics.esc_vel) or is_nan(body_characteristics.surface_gravity):
		if _table_reader.has_value(_table_name, "GM", _row):
			var sig_digits := _table_reader.get_least_real_precision(_table_name, ["GM", "m_radius"], _row)
			if sig_digits > 2:
				if is_nan(body_characteristics.esc_vel):
					var esc_vel := sqrt(2.0 * body_characteristics.GM / body_characteristics.m_radius)
					body_characteristics.esc_vel = math.set_decimal_precision(esc_vel, sig_digits - 1)
				if is_nan(body_characteristics.surface_gravity):
					var surface_gravity := body_characteristics.GM / pow(body_characteristics.m_radius, 2.0)
					body_characteristics.surface_gravity = math.set_decimal_precision(surface_gravity, sig_digits - 1)
		else: # planet w/ mass
			var sig_digits := _table_reader.get_least_real_precision(_table_name, ["mass", "m_radius"], _row)
			if sig_digits > 2:
				if is_nan(body_characteristics.esc_vel):
					if sig_digits > 6:
						sig_digits = 6
					var esc_vel := sqrt(2.0 * G * body_characteristics.mass / body_characteristics.m_radius)
					body_characteristics.esc_vel = math.set_decimal_precision(esc_vel, sig_digits - 1)
				if is_nan(body_characteristics.surface_gravity):
					var surface_gravity := G * body_characteristics.mass / pow(body_characteristics.m_radius, 2.0)
					body_characteristics.surface_gravity = math.set_decimal_precision(surface_gravity, sig_digits - 1)
	_set_compositions_from_table(body_characteristics)
	body.set_body_characteristics(body_characteristics)

func _set_compositions_from_table(body_characteristics: BodyCharacteristics) -> void:
	var compositions := body_characteristics.compositions
	var atmosphere_composition_str := _table_reader.get_string(_table_name, "atmosphere_composition", _row)
	if atmosphere_composition_str:
		var atmosphere_composition := _composition_builder.make_from_string(atmosphere_composition_str)
		compositions.atmosphere = atmosphere_composition
	var trace_atmosphere_composition_str := _table_reader.get_string(_table_name, "trace_atmosphere_composition", _row)
	if trace_atmosphere_composition_str:
		var trace_atmosphere_composition := _composition_builder.make_from_string(trace_atmosphere_composition_str)
		compositions.trace_atmosphere = trace_atmosphere_composition
	var photosphere_composition_str := _table_reader.get_string(_table_name, "photosphere_composition", _row)
	if photosphere_composition_str:
		var photosphere_composition := _composition_builder.make_from_string(photosphere_composition_str)
		compositions.photosphere = photosphere_composition

func _set_model_controller_from_table(body: Body) -> void:
	# orbit and rotations
	# We use definition of "axial tilt" as angle to a body's orbital plane
	# (excpept for primary star where we use ecliptic). North pole should
	# follow IAU definition (!= positive pole) except Pluto, which is
	# intentionally flipped.
	var flags := body.flags
	var orbit := body.orbit
	var model_controller: ModelController = _ModelController_.new()
	_table_reader.build_object(model_controller, model_controller_fields, _table_name, _row)
	if not flags & BodyFlags.IS_TIDALLY_LOCKED:
		assert(!is_nan(model_controller.right_ascension) and !is_nan(model_controller.declination))
		model_controller.north_pole = _ecliptic_rotation * math.convert_spherical2(
				model_controller.right_ascension, model_controller.declination)
		# We have dec & RA for planets and we calculate axial_tilt from these
		# (overwriting table value, if exists). Results basically make sense for
		# the planets EXCEPT Uranus (flipped???) and Pluto (ahhhh Pluto...).
		if orbit:
			model_controller.axial_tilt = model_controller.north_pole.angle_to(orbit.get_normal(NAN, true))
		else: # sun
			model_controller.axial_tilt = model_controller.north_pole.angle_to(ECLIPTIC_Z)
	else:
		model_controller.rotation_period = TAU / orbit.get_mean_motion()
		# This is complicated! The Moon has axial tilt 6.5 degrees (to its 
		# orbital plane) and orbit inclination ~5 degrees. The resulting axial
		# tilt to ecliptic is 1.5 degrees.
		# For The Moon, axial precession and orbit nodal precession are both
		# 18.6 yr. So we apply below adjustment to north pole here AND in Body
		# after each orbit update. I don't think this is correct for other
		# moons, but all other moons have zero or very small axial tilt, so
		# inacuracy is small.
		model_controller.north_pole = orbit.get_normal(NAN, true)
		if model_controller.axial_tilt != 0.0:
			var correction_axis := model_controller.north_pole.cross(orbit.reference_normal).normalized()
			model_controller.north_pole = model_controller.north_pole.rotated(correction_axis, model_controller.axial_tilt)
	model_controller.north_pole = model_controller.north_pole.normalized()
	if orbit and orbit.is_retrograde(): # retrograde
		model_controller.rotation_period = -model_controller.rotation_period
	# body reference basis
	var basis_at_epoch := math.rotate_basis_z(Basis(), model_controller.north_pole)
	var total_rotation: float
	if flags & BodyFlags.IS_TIDALLY_LOCKED:
		# By definition, longitude 0.0 is the mean parent facing side.
		total_rotation = orbit.get_mean_longitude(0.0) - PI
	elif orbit:
		# Table value "longitude_at_epoch" is planetocentric longitude facing
		# solar system barycenter at epoch.
		total_rotation = orbit.get_true_longitude(0.0) - PI
		var longitude_at_epoch := _table_reader.get_real(_table_name, "longitude_at_epoch", _row)
		if longitude_at_epoch and !is_nan(longitude_at_epoch):
			total_rotation += longitude_at_epoch
	basis_at_epoch = basis_at_epoch.rotated(model_controller.north_pole, total_rotation)
	model_controller.set_basis_at_epoch(basis_at_epoch)
	body.set_model_controller(model_controller)

func _set_file_info_from_table(body: Body) -> void:
	var file_prefix := _table_reader.get_string(_table_name, "file_prefix", _row)
	body.file_info[0] = file_prefix
	var rings_name := _table_reader.get_string(_table_name, "rings", _row)
	if rings_name:
		if body.file_info.size() < 3:
			body.file_info.resize(3)
		body.file_info[1] = rings_name
		body.file_info[2] = _table_reader.get_real(_table_name, "rings_radius", _row)

func _modify_parent(body: Body, parent: Body) -> void:
	var orbit := body.orbit
	if parent and orbit:
		var semimajor_axis := orbit.get_semimajor_axis()
		if parent.system_radius < semimajor_axis:
			parent.system_radius = semimajor_axis

func _register(body: Body, parent: Body) -> void:
	if !parent:
		_body_registry.register_top_body(body)
	_body_registry.register_body(body)

# *****************************************************************************

func _project_init() -> void:
	Global.connect("game_load_started", self, "init_system_build")
	Global.get_tree().connect("node_added", self, "_on_node_added")
	_body_registry = Global.program.BodyRegistry
	_model_builder = Global.program.ModelBuilder
	_rings_builder = Global.program.RingsBuilder
	_light_builder = Global.program.LightBuilder
	_huds_builder = Global.program.HUDsBuilder
	_selection_builder = Global.program.SelectionBuilder
	_orbit_builder = Global.program.OrbitBuilder
	_composition_builder = Global.program.CompositionBuilder
	_io_manager = Global.program.IOManager
	_scheduler = Global.program.Scheduler
	_table_reader = Global.program.TableReader
	_main_prog_bar = Global.program.get("MainProgBar") # safe if doesn't exist
	_Body_ = Global.script_classes._Body_
	_ModelController_ = Global.script_classes._ModelController_
	_BodyCharacteristics_ = Global.script_classes._BodyCharacteristics_
	_fallback_body_2d = Global.assets.fallback_body_2d

# *****************************************************************************

func _on_node_added(node: Node) -> void:
	var body := node as Body
	if body:
		_build_unpersisted(body)

func _build_unpersisted(body: Body) -> void: # Main thread
	# After _enter_tree(), before _ready()
	# Note: many builders called here ask for IOManager.callback. These are
	# processed in order, so the last callback at the end of this function will
	# have the last "finish" callback.
	if body.model_type != -1:
		var lazy_init: bool = body.flags & BodyFlags.IS_MOON  \
				and not body.flags & BodyFlags.IS_NAVIGATOR_MOON
		_model_builder.add_model(body, lazy_init)
	if body.has_rings():
		_rings_builder.add_rings(body)
	if body.light_type != -1:
		_light_builder.add_omni_light(body)
	if body.orbit:
		_huds_builder.add_orbit(body)
	_huds_builder.add_label(body)
	body.set_hide_hud_when_close(_settings.hide_hud_when_close)
	var file_prefix := body.get_file_prefix()
	var is_star := bool(body.flags & BodyFlags.IS_STAR)
	if _is_building_system:
		_system_build_count += 1
	var array := [body, file_prefix, is_star]
	_io_manager.callback(self, "_load_textures_on_io_thread", "_io_finish", array)

func _load_textures_on_io_thread(array: Array) -> void: # I/O thread
	var file_prefix: String = array[1]
	var is_star: bool = array[2]
	var texture_2d: Texture = file_utils.find_and_load_resource(_bodies_2d_search, file_prefix)
	if !texture_2d:
		texture_2d = _fallback_body_2d
	array.append(texture_2d)
	if is_star:
		var slice_name = file_prefix + "_slice"
		var texture_slice_2d: Texture = file_utils.find_and_load_resource(_bodies_2d_search, slice_name)
		array.append(texture_slice_2d)

func _io_finish(array: Array) -> void: # Main thread
	var body: Body = array[0]
	var is_star: bool = array[2]
	var texture_2d: Texture = array[3]
	body.texture_2d = texture_2d
	if is_star:
		var texture_slice_2d: Texture = array[4]
		body.texture_slice_2d = texture_slice_2d
	if _is_building_system:
		_system_finished_count += 1
		# warning-ignore:integer_division
		progress = 100 * _system_finished_count / _system_build_count
		if _system_finished_count == _system_build_count:
			_finish_system_build()

func _start_system_build_msec(_array: Array) -> void: # I/O thread
	_system_build_start_msec = OS.get_system_time_msecs()

func _finish_system_build() -> void: # Main thread
		_is_building_system = false
		var msec :=  OS.get_system_time_msecs() - _system_build_start_msec
		print("Built %s solar system bodies in %s msec" % [_system_build_count, msec])
		var is_new_game: bool = !Global.state.is_loaded_game
		Global.emit_signal("system_tree_ready", is_new_game)
		if _main_prog_bar:
			_main_prog_bar.stop()
