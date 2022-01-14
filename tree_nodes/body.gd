# body.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2022 Charlie Whitfield
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
class_name IVBody
extends Spatial

# Base class for spatial nodes that have an orbit or can be orbited. The system
# tree (under Universe) is composed of IVBody instances from top to bottom.
# Other spatial nodes (e.g., visuals) are parented by these IVBodies.
#
# Node name is table row name: "PLANET_EARTH", "MOON_EUROPA", etc.
#
# TODO?: Make IVLPoint into IVBody instances?
# TODO: barycenters
#
# TODO: Make this node "drag-and_drop" as much as possible.
#
# TODO: Implement network sync! This will mainly involve synching IVOrbit
# anytime it changes (e.g., impulse from a rocket engine).

const math := preload("res://ivoyager/static/math.gd") # =IVMath when issue #37529 fixed

const IDENTITY_BASIS := Basis.IDENTITY
const ECLIPTIC_Z := IDENTITY_BASIS.z
const VECTOR2_ZERO := Vector2.ZERO
const VECTOR2_NULL := Vector2(-INF, -INF)
const BodyFlags := IVEnums.BodyFlags
const IS_TOP := BodyFlags.IS_TOP
const IS_STAR := BodyFlags.IS_STAR
const IS_TRUE_PLANET := BodyFlags.IS_TRUE_PLANET
const IS_DWARF_PLANET := BodyFlags.IS_DWARF_PLANET
const IS_MOON := BodyFlags.IS_MOON
const IS_TIDALLY_LOCKED := BodyFlags.IS_TIDALLY_LOCKED
const IS_AXIS_LOCKED := BodyFlags.IS_AXIS_LOCKED
const TUMBLES_CHAOTICALLY := BodyFlags.TUMBLES_CHAOTICALLY
const NEVER_SLEEP := BodyFlags.NEVER_SLEEP
const IS_SERVER = IVEnums.NetworkState.IS_SERVER


# persisted
var body_id := -1
var flags := 0 # see IVEnums.BodyFlags
var characteristics := {} # non-object values
var components := {} # objects (persisted only)
var satellites := [] # IVBody instances
var lagrange_points := [] # IVLPoint instances (lazy init as needed)

const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["name", "body_id", "flags", "characteristics", "components",
	"satellites", "lagrange_points"]


# public - read-only except builder classes
var m_radius := NAN # persisted in characteristics
var orbit: IVOrbit # persisted in components
var model_controller: IVModelController
var aux_graphic: Spatial # rings, commet tail, etc. (for visibility control)
var omni_light: OmniLight # star only
var hud_orbit: IVHUDOrbit
var hud_label: IVHUDLabel
var texture_2d: Texture
var texture_slice_2d: Texture # GUI navigator graphic for sun only
var min_click_radius: float
var max_hud_dist_orbit_radius_multiplier: float
var min_hud_dist_radius_multiplier: float
var min_hud_dist_star_multiplier: float
var max_model_dist := 0.0
var max_aux_graphic_dist := 0.0
var min_hud_dist: float
var is_asleep := false


# private
var _times: Array = IVGlobal.times
var _state: Dictionary = IVGlobal.state
var _ecliptic_rotation: Basis = IVGlobal.ecliptic_rotation
var _visuals_helper: IVVisualsHelper = IVGlobal.program.VisualsHelper
var _huds_manager: IVHUDsManager = IVGlobal.program.HUDsManager
var _show_orbit := true
var _show_label := true
var _model_visible := false
var _aux_graphic_visible := false
var _hud_orbit_visible := false
var _hud_label_visible := false
var _is_visible := false

onready var _tree := get_tree()


# virtual & overridable virtual-replacement functions

func _init() -> void:
	_on_init()


func _on_init() -> void:
	hide()


func _enter_tree() -> void:
	_on_enter_tree()


func _on_enter_tree() -> void:
	if !_state.is_loaded_game or _state.is_system_built:
		return
	# loading game inits
	m_radius = characteristics.m_radius
	orbit = components.get("orbit")
	if orbit:
		orbit.reset_elements_and_interval_update()
		orbit.connect("changed", self, "_on_orbit_changed")


func _ready() -> void:
	_on_ready()


func _on_ready() -> void:
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_prepare_to_free", [], CONNECT_ONESHOT)
	IVGlobal.connect("setting_changed", self, "_settings_listener")
	_huds_manager.connect("show_huds_changed", self, "_on_show_huds_changed")
	var timekeeper: IVTimekeeper = IVGlobal.program.Timekeeper
	timekeeper.connect("time_altered", self, "_on_time_altered")


func _prepare_to_free() -> void:
	set_process(false)
	IVGlobal.disconnect("setting_changed", self, "_settings_listener")
	_huds_manager.disconnect("show_huds_changed", self, "_on_show_huds_changed")


func _process(delta: float) -> void:
	_on_process(delta)


func _on_process(_delta: float) -> void:
	var is_mouse_target := false
	var global_translation := global_transform.origin
	var camera_dist := _visuals_helper.get_distance_to_camera(global_translation)
	var position_2d := _visuals_helper.unproject_position_in_front(global_translation)
	if position_2d != VECTOR2_NULL: # not behind
		var mouse_dist := position_2d.distance_to(_visuals_helper.mouse_position)
		var click_radius := min_click_radius
		var divisor: float = _visuals_helper.camera_fov * camera_dist # fov * dist
		if divisor > 0.0:
			var screen_radius: float = 55.0 * m_radius * _visuals_helper.veiwport_height / divisor
			if click_radius < screen_radius:
				click_radius = screen_radius
		if mouse_dist < click_radius:
			is_mouse_target = true
	if is_mouse_target:
		_visuals_helper.set_mouse_target(self, camera_dist)
	else:
		_visuals_helper.remove_mouse_target(self)
	var hud_dist_ok := camera_dist > min_hud_dist
	if hud_dist_ok:
		var orbit_radius := translation.length() if orbit else INF
		hud_dist_ok = camera_dist < orbit_radius * max_hud_dist_orbit_radius_multiplier
	var hud_label_visible := _show_label and hud_dist_ok and hud_label and position_2d != VECTOR2_NULL
	if hud_label_visible:
		# position 2D Label before 3D translation!
		hud_label.set_position(position_2d - hud_label.rect_size / 2.0)
	var time: float = _times[0]
	if orbit:
		translation = orbit.get_position(time)
	if model_controller:
		var model_visible := camera_dist < max_model_dist
		if model_visible:
			model_controller.process_visible(time, camera_dist)
		if _model_visible != model_visible:
			_model_visible = model_visible
			model_controller.change_visibility(model_visible)
	if aux_graphic:
		var aux_graphic_visible := camera_dist < max_aux_graphic_dist
		if _aux_graphic_visible != aux_graphic_visible:
			_aux_graphic_visible = aux_graphic_visible
			aux_graphic.visible = aux_graphic_visible
	if hud_orbit:
		var hud_orbit_visible := _show_orbit and hud_dist_ok
		if _hud_orbit_visible != hud_orbit_visible:
			_hud_orbit_visible = hud_orbit_visible
			hud_orbit.visible = hud_orbit_visible
	if hud_label:
		if _hud_label_visible != hud_label_visible:
			_hud_label_visible = hud_label_visible
			hud_label.visible = hud_label_visible
	if !_is_visible:
		_is_visible = true
		visible = true


# public functions

func get_symbol() -> String:
	return characteristics.get("symbol", "\u25CC") # default is dashed circle


func get_class_type() -> int: # "classes" table row
	return characteristics.get("class_type", -1)


func get_model_type() -> int: # "models" table row
	return characteristics.get("model_type", -1)


func get_light_type() -> int: # "lights" table row
	return characteristics.get("light_type", -1)


func get_file_prefix() -> String:
	return characteristics.get("file_prefix", "")


func has_rings() -> bool:
	return characteristics.has("rings_radius")


func get_rings_file_prefix() -> String:
	return characteristics.get("rings_file_prefix", "")


func get_rings_radius() -> float:
	return characteristics.get("rings_radius", 0.0)


func get_std_gravitational_parameter() -> float:
	return characteristics.get("GM", 0.0)


func get_mean_radius() -> float:
	return m_radius


func get_equatorial_radius() -> float:
	var e_radius: float = characteristics.get("e_radius", 0.0)
	if e_radius:
		return e_radius
	return m_radius


func get_polar_radius() -> float:
	var p_radius: float = characteristics.get("p_radius", 0.0)
	if p_radius:
		return p_radius
	return m_radius


func get_rotation_period() -> float:
	return characteristics.get("rotation_period", 0.0)


func get_latitude_longitude(at_translation: Vector3, time := NAN) -> Vector2:
	if !model_controller:
		return VECTOR2_ZERO
	var ground_basis := model_controller.get_ground_ref_basis(time)
	var spherical := math.get_rotated_spherical3(at_translation, ground_basis)
	var latitude: float = spherical[1]
	var longitude: float = wrapf(spherical[0], -PI, PI)
	return Vector2(latitude, longitude)


func get_north_pole(_time := NAN) -> Vector3:
	# Returns this body's north in ecliptic coordinates. This is messy because
	# IAU defines "north" only for true planets and their satellites equal to
	# the pole pointing above invariable plane. Other bodies should use
	# positive pole:
	#    https://en.wikipedia.org/wiki/Poles_of_astronomical_bodies
	# However, it is common usage to assign "north" to Pluto and Charon's
	# positive poles, even though this is south by above definition. We attempt
	# to sort this out in our data tables and IVBodyBuilder assigning
	# model_controller.rotation_vector to a sensible "north" as follows:
	#  * Star - same as true planet below.
	#  * True planets and their satellites - use pole pointing in positive z-
	#    axis direction in ecliptic (our sim reference coordinates). This is
	#    per IAU except the use of ecliptic rather than invarient plane (the
	#    difference is ~ 1 degree and will affect very few if any objects).
	#  * Other star-orbiting bodies - use positive pole, following Pluto.
	#  * All others - use pole in same hemisphere as parent positive pole; so,
	#    hypothetically, a retrograde moon of Pluto would have north aligned
	#    with Pluto's.
	# TODO: North precession; will require time.
	if !model_controller:
		return ECLIPTIC_Z
	return model_controller.rotation_vector


func get_positive_pole(_time := NAN) -> Vector3:
	# Right-hand-rule.
	if !model_controller:
		return ECLIPTIC_Z
	if model_controller.rotation_rate < 0.0:
		return -model_controller.rotation_vector
	return model_controller.rotation_vector


func get_up_pole(_time := NAN) -> Vector3:
	# See comments in IVModelController.
	if !model_controller:
		return ECLIPTIC_Z
	return model_controller.rotation_vector


func is_orbit_retrograde(time := NAN) -> bool:
	if !orbit:
		return false
	return orbit.is_retrograde(time)


func get_orbit_semi_major_axis(time := NAN) -> float:
	if !orbit:
		return 0.0
	return orbit.get_semimajor_axis(time)


func get_orbit_normal(time := NAN, flip_retrograde := false) -> Vector3:
	if !orbit:
		return ECLIPTIC_Z
	return orbit.get_normal(time, flip_retrograde)


func get_orbit_inclination_to_equator(time := NAN) -> float:
	if !orbit or flags & IS_TOP:
		return NAN
	var orbit_normal := orbit.get_normal(time)
	var positive_pole: Vector3 = get_parent().get_positive_pole(time)
	return orbit_normal.angle_to(positive_pole)


func is_rotation_retrograde() -> bool:
	if !model_controller:
		return false
	return model_controller.rotation_rate < 0.0


func get_axial_tilt_to_orbit(time := NAN) -> float:
	if !model_controller or !orbit:
		return NAN
	var positive_pole := get_positive_pole(time)
	var orbit_normal := orbit.get_normal(time)
	return positive_pole.angle_to(orbit_normal)


func get_axial_tilt_to_ecliptic(time := NAN) -> float:
	if !model_controller:
		return NAN
	var positive_pole := get_positive_pole(time)
	return positive_pole.angle_to(ECLIPTIC_Z)


func get_ground_ref_basis(time := NAN) -> Basis:
	# returns rotation basis referenced to ground
	if !model_controller:
		return IDENTITY_BASIS
	return model_controller.get_ground_ref_basis(time)


func get_orbit_ref_basis(time := NAN) -> Basis:
	# returns rotation basis referenced to parent body
	if !orbit:
		return IDENTITY_BASIS
	var x_axis := -orbit.get_position(time).normalized()
	var up := orbit.get_normal(time, true)
	var y_axis := up.cross(x_axis).normalized() # norm needed due to imprecision
	var z_axis := x_axis.cross(y_axis)
	return Basis(x_axis, y_axis, z_axis)


# ivoyager mechanics below

func set_orbit(orbit_: IVOrbit) -> void:
	if orbit == orbit_:
		return
	if orbit:
		orbit.disconnect_interval_update()
		orbit.disconnect("changed", self, "_on_orbit_changed")
	orbit = orbit_
	if orbit_:
		components.orbit = orbit_
		orbit_.reset_elements_and_interval_update()
		orbit_.connect("changed", self, "_on_orbit_changed")
	else:
		components.erase("orbit")


func set_hide_hud_when_close(hide_hud_when_close: bool) -> void:
	if hide_hud_when_close:
		min_hud_dist = m_radius * min_hud_dist_radius_multiplier
		if flags & IS_STAR:
			min_hud_dist *= min_hud_dist_star_multiplier # just the label
	else:
		min_hud_dist = 0.0


func set_sleep(sleep: bool) -> void: # called by IVSleepManager
	if flags & NEVER_SLEEP or sleep == is_asleep:
		return
	if sleep:
		is_asleep = true
		set_process(false)
		_is_visible = false
		visible = false
		_visuals_helper.remove_mouse_target(self)
		if hud_orbit: # not a child of this node!
			_hud_orbit_visible = false
			hud_orbit.visible = false
		if hud_label: # not a child of this node!
			_hud_label_visible = false
			hud_label.visible = false
	else:
		is_asleep = false
		set_process(true) # will show on next _process()


func reset_orientation_and_rotation() -> void:
	# If we have tidal and/or axis lock, then IVOrbit determines rotation and/or
	# orientation. If so, we use IVOrbit to set values in characteristics and
	# IVModelController. Otherwise, characteristics already holds table-loaded
	# values (RA, dec, period) which we use to set IVModelController values.
	# Note: Earth's Moon is the unusual case that is tidally locked but not
	# axis locked (its axis is tilted to its orbit). Axis of other moons are
	# not exactly orbit normal but stay within ~1 degree. E.g., see:
	# https://zenodo.org/record/1259023.
	# TODO: We still need rotation precession for Bodies with axial tilt.
	# TODO: Some special mechanic for tumblers like Hyperion.
	if !model_controller:
		return
	# rotation_rate
	var rotation_rate: float
	if flags & IS_TIDALLY_LOCKED:
		rotation_rate = orbit.get_mean_motion()
		characteristics.rotation_period = TAU / rotation_rate
	else:
		var rotation_period: float = characteristics.rotation_period
		rotation_rate = TAU / rotation_period
	# rotation_vector
	var rotation_vector: Vector3
	if flags & IS_AXIS_LOCKED:
		rotation_vector = orbit.get_normal()
		var ra_dec := math.get_spherical2(rotation_vector)
		characteristics.right_ascension = ra_dec[0]
		characteristics.declination = ra_dec[1]
	elif flags & TUMBLES_CHAOTICALLY:
		# TODO: something sensible for Hyperion
		characteristics.right_ascension = 0.0
		characteristics.declination = 0.0
		rotation_vector = _ecliptic_rotation * math.convert_spherical2(0.0, 0.0)
	else:
		var ra: float = characteristics.right_ascension
		var dec: float = characteristics.declination
		rotation_vector = _ecliptic_rotation * math.convert_spherical2(ra, dec)
	var rotation_at_epoch: float = characteristics.get("longitude_at_epoch", 0.0)
	if orbit:
		if flags & IS_TIDALLY_LOCKED:
			rotation_at_epoch += orbit.get_mean_longitude(0.0) - PI
		else:
			rotation_at_epoch += orbit.get_true_longitude(0.0) - PI
	# possible polarity reversal; see comments under get_north_pole()
	var reverse_polarity := false
	var parent_flags := 0
	var parent := get_parent_spatial()
	if parent.name != "Universe":
		parent_flags = parent.flags
	if flags & IS_STAR or flags & IS_TRUE_PLANET or parent_flags & IS_TRUE_PLANET:
		if ECLIPTIC_Z.dot(rotation_vector) < 0.0:
			reverse_polarity = true
	elif parent_flags & IS_STAR: # dwarf planets and other star-orbiters
		var positive_pole := get_positive_pole()
		if positive_pole.dot(rotation_vector) < 0.0:
			reverse_polarity = true
	else:
		var parent_positive_pole: Vector3 = parent.get_positive_pole()
		if parent_positive_pole.dot(rotation_vector) < 0.0:
			reverse_polarity = true
	if reverse_polarity:
		rotation_rate *= -1.0
		rotation_vector *= -1.0
		rotation_at_epoch *= -1.0
	model_controller.set_body_parameters(rotation_vector, rotation_rate, rotation_at_epoch)
	model_controller.emit_signal("changed")


# private functions

func _on_show_huds_changed() -> void:
	_show_orbit = _huds_manager.show_orbits
	_show_label = _huds_manager.show_names or _huds_manager.show_symbols


func _on_orbit_changed(is_scheduled: bool) -> void:
	if flags & IS_TIDALLY_LOCKED or flags & IS_AXIS_LOCKED:
		reset_orientation_and_rotation()
	if !is_scheduled and _state.network_state == IS_SERVER: # sync clients
		# scheduled changes happen on client so don't need sync
		rpc("_orbit_sync", orbit.reference_normal, orbit.elements_at_epoch, orbit.element_rates,
				orbit.m_modifiers)


remote func _orbit_sync(reference_normal: Vector3, elements_at_epoch: Array,
		element_rates: Array, m_modifiers: Array) -> void: # client-side network game only
	if _tree.get_rpc_sender_id() != 1:
		return # from server only
	orbit.orbit_sync(reference_normal, elements_at_epoch, element_rates, m_modifiers)


func _on_time_altered(_previous_time: float) -> void:
	if orbit:
		orbit.reset_elements_and_interval_update()
	reset_orientation_and_rotation()


func _settings_listener(setting: String, value) -> void:
	match setting:
		"planet_orbit_color":
			if flags & BodyFlags.IS_TRUE_PLANET and hud_orbit:
				hud_orbit.change_color(value)
		"dwarf_planet_orbit_color":
			if flags & BodyFlags.IS_DWARF_PLANET and hud_orbit:
				hud_orbit.change_color(value)
		"moon_orbit_color":
			if flags & BodyFlags.IS_MOON and flags & BodyFlags.LIKELY_HYDROSTATIC_EQUILIBRIUM and hud_orbit:
				hud_orbit.change_color(value)
		"minor_moon_orbit_color":
			if flags & BodyFlags.IS_MOON and not flags & BodyFlags.LIKELY_HYDROSTATIC_EQUILIBRIUM and hud_orbit:
				hud_orbit.change_color(value)
		"hide_hud_when_close":
			set_hide_hud_when_close(value)
