# body_builder.gd
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
class_name BodyBuilder

const DPRINT := false
const MAJOR_MOON_GM := 4.0 * 7.46496e9 # eg, Miranda is 4.4 in _Moon_Master.xlsm
const ECLIPTIC_NORTH := Vector3(0.0, 0.0, 1.0)

var _texture_2d_dir: String = Global.texture_2d_dir
var _ecliptic_rotation: Basis = Global.ecliptic_rotation
var _scale: float = Global.scale
var _gravitational_constant: float = Global.gravitational_constant
var _settings: Dictionary = Global.settings
var _table_data: Dictionary = Global.table_data
var _enums: Dictionary = Global.enums
var _global_time_array: Array = Global.time_array
var _hud_2d_control: Control
var _registrar: Registrar
var _selection_builder: SelectionBuilder
var _orbit_builder: OrbitBuilder
var _file_helper: FileHelper
var _math: Math
var _Body_: Script
var _HUDOrbit_: Script
var _HUDIcon_: Script
var _HUDLabel_: Script
var _Model_: Script
var _Rings_: Script
var _Starlight_: Script

var _major_moon_gm: float = MAJOR_MOON_GM * _scale * _scale * _scale
var _satellite_indexes := {} # passed to & shared by Body instances
var _orbit_mesh_arrays: Array # shared by HUDOrbit instances


func build(body: Body, data_table_type: int, data: Dictionary, parent: Body) -> void:
	assert(DPRINT and prints("build", tr(data.key)) or true)
	body.name = data.key
	if !parent:
		body.is_top = true
	match data_table_type:
		_enums.DATA_TABLE_STAR:
			body.is_star = true
		_enums.DATA_TABLE_PLANET:
			body.is_planet = true
			body.is_dwarf_planet = data.has("dwarf")
			body.has_minor_moons = data.has("minor_moons")
		_enums.DATA_TABLE_MOON:
			body.is_moon = true
	
	body.is_gas_giant = data.has("gas_giant")
	
	var time: float = _global_time_array[0]
	var orbit: Orbit
	if !body.is_top:
		orbit = _orbit_builder.make_orbit_from_data(data, parent, parent.GM, time)
		body.orbit = orbit
	body.body_type = _enums.BodyTypes[data.body_type]
	if data.has("starlight_type"):
		body.starlight_type = _enums.StarlightTypes[data.starlight_type]
	body.has_atmosphere = data.has("atmosphere")
	body.m_radius = data.m_radius * _scale
	body.e_radius = data.e_radius * _scale if data.has("e_radius") else body.m_radius
	body.system_radius = body.e_radius * 10.0 # widens if satalletes are added
	body.mass = data.mass if data.has("mass") else 0.0
	body.GM = data.GM * _scale * _scale * _scale if data.has("GM") else 0.0
	if body.mass == 0.0:
		body.mass = body.GM / _gravitational_constant
	elif body.GM == 0.0:
		body.GM = body.mass * _gravitational_constant
	if body.is_moon and body.GM < _major_moon_gm and !data.has("force_major"):
		body.is_minor_moon = true
	body.rotation_period = data.rotation if data.has("rotation") else 0.0
	body.right_ascension = data.RA if data.has("RA") else -INF
	body.declination = data.dec if data.has("dec") else -INF
	body.axial_tilt = data.axial_tilt if data.has("axial_tilt") else 0.0
	body.esc_vel = data.esc_vel * _scale if data.has("esc_vel") else 0.0

	# orbit and axis
	if parent and parent.is_star:
		body.is_star_orbiting = true
	if data.has("tidally_locked") and data.tidally_locked: # almost all moons
		body.tidally_locked = true
		body.rotation_period = TAU / orbit.get_mean_motion(time)

	# We use definition of "axial tilt" as angle to a body's orbital plane
	# (excpept for primary star where we use ecliptic). North pole should
	# follow IAU definition (!= positive pole) except Pluto, which is
	# intentionally flipped.
	if !body.tidally_locked:
		assert(data.has("dec") and data.has("RA"))
		body.north_pole = _ecliptic_rotation * _math.convert_equatorial_coordinates(body.right_ascension, body.declination)
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
	# Keep below print statement for additional "does this make sense?" tests.
	# prints(body.name, rad2deg(body.axial_tilt), rad2deg(body.north_pole.angle_to(ECLIPTIC_NORTH)))
	
	if orbit and orbit.is_retrograde(time): # retrograde
		body.rotation_period = -body.rotation_period
	
	# reference basis
	var polar_radius = 3.0 * body.m_radius - 2.0 * body.e_radius
	body.reference_basis = body.reference_basis.scaled(Vector3(body.e_radius, polar_radius, body.e_radius))
	var tilt_axis = Vector3(0.0, 1.0, 0.0).cross(body.north_pole).normalized() # up for model graphic is its y-axis
	var tilt_angle = Vector3(0.0, 1.0, 0.0).angle_to(body.north_pole)
	body.reference_basis = body.reference_basis.rotated(tilt_axis, tilt_angle)
	if data.has("rotate_adj") and data.rotate_adj != 0.0:
		body.reference_basis = body.reference_basis.rotated(body.north_pole, data.rotate_adj)

	# file import info
	body.file_prefix = data.file_prefix
	if data.has("rings"):
		body.rings_info = [data.rings, data.rings_outer_radius * _scale]

	body.classification = _get_classification(body)
	# parent modifications
	if parent and orbit:
		var semimajor_axis := orbit.get_semimajor_axis(time)
		if parent.system_radius < semimajor_axis:
			parent.system_radius = semimajor_axis
	
	if !parent:
		_registrar.register_top_body(body)
	_registrar.register_body(body)
	_selection_builder.build_from_body(body, parent)


func project_init() -> void:
	Global.connect("system_tree_built_or_loaded", self, "_init_unpersisted")
	_hud_2d_control = Global.objects.HUD2dControl
	_registrar = Global.objects.Registrar
	_selection_builder = Global.objects.SelectionBuilder
	_orbit_builder = Global.objects.OrbitBuilder
	_file_helper = Global.objects.FileHelper
	_math = Global.objects.Math
	_Body_ = Global.script_classes._Body_
	_HUDOrbit_ = Global.script_classes._HUDOrbit_
	_HUDIcon_ = Global.script_classes._HUDIcon_
	_HUDLabel_ = Global.script_classes._HUDLabel_
	_Model_ = Global.script_classes._Model_
	_Rings_ = Global.script_classes._Rings_
	_Starlight_ = Global.script_classes._Starlight_
	_orbit_mesh_arrays = _HUDOrbit_.make_mesh_arrays()

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
	var file_prefix: String = body.file_prefix
	var body_type: int = body.body_type
	# model
	if body.body_type != -1:
		var model: Model = _file_helper.make_object_or_scene(_Model_)
		model.init(body_type, file_prefix)
		var too_far: float = body.m_radius * model.TOO_FAR_RADIUS_MULTIPLIER
		body.set_model(model, too_far)
	# rings
	if body.rings_info:
		var rings_file: String = body.rings_info[0]
		var rings_radius: float = body.rings_info[1]
		var rings: Spatial = _file_helper.make_object_or_scene(_Rings_)
		rings.init(rings_file, rings_radius)
		var rings_tilt_axis := Vector3(0, 0, 1).cross(body.north_pole).normalized() # z-axis is up for rings graphic
		var rings_tilt_angle := Vector3(0, 0, 1).angle_to(body.north_pole)
		rings.rotate(rings_tilt_axis, rings_tilt_angle)
		var too_far: float = rings_radius * rings.TOO_FAR_RADIUS_MULTIPLIER
		body.set_aux_graphic(rings, too_far)
	# starlight
	var starlight: Starlight
	if body.starlight_type != -1:
		starlight = _file_helper.make_object_or_scene(_Starlight_)
		var starlight_data: Dictionary = _table_data.starlight_data[body.starlight_type]
		starlight.init(starlight_data)
		body.add_child(starlight)
	# HUDs
	if _settings.hide_hud_when_close:
		body.hud_too_close = body.m_radius * body.HUD_TOO_CLOSE_M_RADIUS_MULTIPLIER
		if body.is_star:
			body.hud_too_close *= body.HUD_TOO_CLOSE_STAR_MULTIPLIER
	# HUDOrbit
	var hud_orbit: HUDOrbit
	if body.orbit:
		var orbit_color: Color
		if body.is_minor_moon:
			orbit_color = _settings.minor_moon_orbit_color
		elif body.is_moon:
			orbit_color = _settings.moon_orbit_color
		elif body.is_dwarf_planet:
			orbit_color = _settings.dwarf_planet_orbit_color
		elif body.is_planet:
			orbit_color = _settings.planet_orbit_color
		if orbit_color:
			hud_orbit = _file_helper.make_object_or_scene(_HUDOrbit_)
			hud_orbit.init(body.orbit, orbit_color, _orbit_mesh_arrays)
			body.hud_orbit = hud_orbit
			var parent: Body = body.get_parent()
			parent.call_deferred("add_child", hud_orbit)
	# HUDIcon
	var hud_icon: HUDIcon = _file_helper.make_object_or_scene(_HUDIcon_)
	var fallback_icon_texture: Texture
	if body.is_moon:
		fallback_icon_texture = Global.assets.generic_moon_icon
	else:
		fallback_icon_texture = Global.assets.fallback_icon
	hud_icon.init(file_prefix, fallback_icon_texture)
	body.hud_icon = hud_icon
	body.add_child(hud_icon)
	# HUDLabel
	var hud_label: HUDLabel = _file_helper.make_object_or_scene(_HUDLabel_)
	hud_label.init(tr(body.name))
	body.hud_label = hud_label
	_hud_2d_control.add_child(hud_label)

	# 2D selection textures
	body.texture_2d = _file_helper.find_resource(_texture_2d_dir, file_prefix)
	if !body.texture_2d:
		body.texture_2d = Global.assets.fallback_texture_2d
	if body.is_star:
		var slice_name = file_prefix + "_slice"
		body.texture_slice_2d = _file_helper.find_resource(_texture_2d_dir, slice_name)
		if !body.texture_slice_2d:
			body.texture_slice_2d = Global.assets.fallback_star_slice

# DEPRECIATE - move to SelectionBuilder for SelectionItem
func _get_classification(body: Body) -> String:
	# for UI display "Classification: ______"
	if body.is_star:
		return "CLASSIFICATION_STAR"
	if body.is_dwarf_planet:
		return "CLASSIFICATION_DWARF_PLANET"
	if body.is_planet:
		return "CLASSIFICATION_PLANET"
	if body.is_moon:
		return "CLASSIFICATION_MOON"
	return ""



