# body.gd
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
class_name IVBody
extends Spatial

# Base class for Spatial nodes that have an orbit or can be orbited. The system
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
const MIN_SYSTEM_M_RADIUS_MULTIPLIER := 15.0

const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL # free & rebuild on load
const PERSIST_PROPERTIES := [
	"name",
	"flags",
	"characteristics",
	"components",
	"satellites",
	"lagrange_points",
]


# persisted
var flags := 0 # see IVEnums.BodyFlags
var characteristics := {} # non-object values
var components := {} # objects (persisted only)
var satellites := [] # IVBody instances
var lagrange_points := [] # IVLPoint instances (lazy init as needed)


# public - read-only except builder classes
var parent: Spatial # another Body or 'Universe'
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
var _huds_visibility: IVHUDsVisibility = IVGlobal.program.HUDsVisibility
var _show_orbit := true
var _show_label := true
var _model_visible := false
var _aux_graphic_visible := false
var _hud_orbit_visible := false
var _hud_label_visible := false
var _is_visible := false

var _world_targeting: Array = IVGlobal.world_targeting
onready var _tree := get_tree()


# virtual & overridable virtual-replacement functions

func _init() -> void:
	_on_init()


func _on_init() -> void:
	hide()


func _enter_tree() -> void:
	_on_enter_tree()


func _on_enter_tree() -> void:
	parent = get_parent()
	if _state.is_game_loading:
		m_radius = characteristics.m_radius
		orbit = components.get("orbit")
		if orbit:
			orbit.reset_elements_and_interval_update()
			orbit.connect("changed", self, "_on_orbit_changed")


func _ready() -> void:
	_on_ready()


func _on_ready() -> void:
	IVGlobal.connect("system_tree_built_or_loaded", self, "_on_system_tree_built_or_loaded", [], CONNECT_ONESHOT)
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_prepare_to_free", [], CONNECT_ONESHOT)
	IVGlobal.connect("setting_changed", self, "_settings_listener")
	_huds_visibility.connect("body_huds_visibility_changed", self, "_on_huds_visibility_changed")
	var timekeeper: IVTimekeeper = IVGlobal.program.Timekeeper
	timekeeper.connect("time_altered", self, "_on_time_altered")
	assert(!IVGlobal.bodies.has(name))
	IVGlobal.bodies[name] = self
	if flags & BodyFlags.IS_TOP:
		IVGlobal.top_bodies.append(self)


func _exit_tree() -> void:
	_on_exit_tree()


func _on_exit_tree() -> void:
	IVGlobal.bodies.erase(name)
	if flags & BodyFlags.IS_TOP:
		IVGlobal.top_bodies.erase(self)


func _on_system_tree_built_or_loaded(is_new_game: bool) -> void:
	if !is_new_game:
		return
	var system_radius := m_radius * MIN_SYSTEM_M_RADIUS_MULTIPLIER
	for satellite in satellites:
		var a: float = satellite.get_orbit_semi_major_axis()
		if system_radius < a:
			system_radius = a
	characteristics.system_radius = system_radius
	# non-table flags
	var hill_sphere := get_hill_sphere()
	if hill_sphere < m_radius:
		flags |= BodyFlags.NO_ORBIT
	if hill_sphere / 3.0 < m_radius:
		flags |= BodyFlags.NO_STABLE_ORBIT


func _prepare_to_free() -> void:
	set_process(false)
	IVGlobal.disconnect("setting_changed", self, "_settings_listener")
	_huds_visibility.disconnect("body_huds_visibility_changed", self, "_on_huds_visibility_changed")


func _process(delta: float) -> void:
	_on_process(delta)


func _on_process(_delta: float) -> void:
	# Determine if this body is mouse target.
	# _world_targeting:
	#  [0] mouse_position: Vector2
	#  [1] veiwport_height: float
	#  [2] camera: Camera
	#  [3] camera_fov: float
	#  [4] mouse_target: Object
	#  [5] mouse_target_dist: float
	var is_in_mouse_click_radius := false
	var camera: Camera = _world_targeting[2]
	var camera_dist := global_translation.distance_to(camera.global_translation)
	var position_2d := VECTOR2_NULL
	if !camera.is_position_behind(global_translation):
		position_2d = camera.unproject_position(global_translation)
		var mouse_dist := position_2d.distance_to(_world_targeting[0])
		var click_radius := min_click_radius
		var divisor: float = _world_targeting[3] * camera_dist # fov * dist
		if divisor > 0.0:
			var screen_radius: float = 55.0 * m_radius * _world_targeting[1] / divisor
			if click_radius < screen_radius:
				click_radius = screen_radius
		if mouse_dist < click_radius:
			is_in_mouse_click_radius = true
	if is_in_mouse_click_radius:
		if camera_dist < _world_targeting[5]: # make self the mouse target
			_world_targeting[4] = self
			_world_targeting[5] = camera_dist
	elif _world_targeting[4] == self: # remove self as mouse target
		_world_targeting[4] = null
		_world_targeting[5] = INF
	var hud_dist_ok := camera_dist > min_hud_dist # not too close
	if hud_dist_ok:
		var orbit_radius := translation.length() if orbit else INF
		hud_dist_ok = camera_dist < orbit_radius * max_hud_dist_orbit_radius_multiplier
	var hud_label_visible := _show_label and hud_dist_ok and hud_label and position_2d != VECTOR2_NULL

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

func get_real_precision(path: String) -> int:
	# Available only if IVBodyBuilder.keep_real_precisions = true. Gets the
	# precision (significant digits) of a real value as it was entered in the
	# table *.tsv file. Used by Planetarium.
	if !characteristics.has("real_precisions"):
		return -1
	return characteristics.real_precisions.get(path, -1)


func get_system_radius() -> float:
	return characteristics.system_radius


func get_hud_name() -> String:
	return characteristics.get("hud_name", name)


func get_symbol() -> String:
	return characteristics.get("symbol", "\u25CC") # default is dashed circle


func get_body_class() -> int: # body_classes.tsv
	return characteristics.get("body_class", -1)


func get_model_type() -> int: # models.tsv
	return characteristics.get("model_type", -1)


func get_light_type() -> int: # lights.tsv
	return characteristics.get("light_type", -1)


func get_file_prefix() -> String:
	return characteristics.get("file_prefix", "")


func has_rings() -> bool:
	return characteristics.has("rings_radius")


func get_rings_file_prefix() -> String:
	return characteristics.get("rings_file_prefix", "")


func get_rings_radius() -> float:
	return characteristics.get("rings_radius", 0.0)


func get_mass() -> float:
	return characteristics.get("mass", 0.0)


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
	# IAU defines "north" only for true planets and their satellites (defined
	# as the pole pointing above invariable plane). Other bodies technically
	# don't have "north" and are supposed to use "positive pole".
	#    https://en.wikipedia.org/wiki/Poles_of_astronomical_bodies
	# However, we want a "north" for all bodies for camera orientation. Also,
	# it is common usage to assign "north" to Pluto and Charon's positive
	# poles, which is reversed from above if Pluto were a planet (which it is
	# not, of course!). We attempt to sort this out as follows:
	#
	#  * Star - Same as true planet.
	#  * True planets and their satellites - Use pole pointing in positive z-
	#    axis direction in ecliptic (our sim reference coordinates). This is
	#    per IAU except the use of ecliptic rather than invarient plane; the
	#    difference is ~ 1 degree and will affect very few if any objects.
	#  * Other star-orbiting bodies - Use positive pole, following Pluto.
	#  * All others (e.g., satellites of dwarf planets) - Use pole in same
	#    hemisphere as parent positive pole.
	#
	# Note that rotation_vector (and rotation_rate) will be flipped if needed
	# during system build (following above rules) so that rotation_vector is
	# always "north".
	#
	# TODO: North precession; will require time.
	if !model_controller:
		return ECLIPTIC_Z
	return model_controller.rotation_vector


func get_positive_pole(_time := NAN) -> Vector3:
	# Right-hand-rule! This is exactly defined, unlike "north".
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


func get_hill_sphere(eccentricity := 0.0) -> float:
	# returns INF if this is a top body in simulation
	# see: https://en.wikipedia.org/wiki/Hill_sphere
	if flags & BodyFlags.IS_TOP:
		return INF
	var a := get_orbit_semi_major_axis()
	var mass := get_mass()
	var parent_mass: float = parent.get_mass()
	if !a or !mass or !parent_mass:
		return 0.0
	return a * (1.0 - eccentricity) * pow(mass / (3.0 * parent_mass), 0.33333333)


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
		if _world_targeting[4] == self: # remove self as mouse target
			_world_targeting[4] = null
			_world_targeting[5] = INF
		if hud_orbit: # not a child of this node!
			_hud_orbit_visible = false
			hud_orbit.visible = false
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
	
	if !model_controller or flags & IS_TOP:
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
	var parent_flags: int = parent.flags
	if flags & IS_STAR or flags & IS_TRUE_PLANET or parent_flags & IS_TRUE_PLANET:
		if ECLIPTIC_Z.dot(rotation_vector) < 0.0:
			reverse_polarity = true
	elif parent_flags & IS_STAR: # dwarf planets and other star-orbiters
		if rotation_rate < 0.0:
			reverse_polarity = true
	else: # moons of not-true-planet star-orbiters
		var parent_positive_pole: Vector3 = parent.get_positive_pole()
		if parent_positive_pole.dot(rotation_vector) < 0.0:
			reverse_polarity = true
	if reverse_polarity:
		rotation_rate = -rotation_rate
		rotation_vector = -rotation_vector # this defines "north"!
		rotation_at_epoch = -rotation_at_epoch
	
	model_controller.set_body_parameters(rotation_vector, rotation_rate, rotation_at_epoch)
	model_controller.emit_signal("changed")


# private functions

func _on_huds_visibility_changed() -> void:
	_show_orbit = _huds_visibility.is_orbit_visible(flags)
	var is_name_visible := _huds_visibility.is_name_visible(flags)
	_show_label = is_name_visible or _huds_visibility.is_symbol_visible(flags)
	if hud_label:
		hud_label.set_symbol_mode(!is_name_visible)


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
		"hide_hud_when_close":
			set_hide_hud_when_close(value)
