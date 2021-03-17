# body.gd
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
# Base class for spatial nodes that have an orbit or can be orbited, including
# non-physical barycenters & lagrange points. The system tree is composed of
# Body instances from top to bottom, each Body having its orbiting children
# (other Body instances) and other spatial children that are visuals: Model,
# Rings, HUDOrbit.
#
# Node name is table row name: "PLANET_EARTH", "MOON_EUROPA", etc.
#
# TODO?: Make LPoint into Body instances?
# TODO: barycenters
#
# TODO: Make this node "drag-and_drop" as much as possible.
#
# TODO: Implement network sync! This will mainly involve synching Orbit
# anytime it changes (e.g., impulse from a rocket engine).

extends Spatial
class_name Body

const math := preload("res://ivoyager/static/math.gd") # =Math when issue #37529 fixed

const DPRINT := false

const IDENTITY_BASIS := Basis.IDENTITY
const ECLIPTIC_Z := IDENTITY_BASIS.z
const VECTOR2_ZERO := Vector2.ZERO
const VECTOR2_NULL := Vector2(-INF, -INF)
const BodyFlags := Enums.BodyFlags
const IS_STAR := BodyFlags.IS_STAR
const IS_TRUE_PLANET := BodyFlags.IS_TRUE_PLANET
const IS_DWARF_PLANET := BodyFlags.IS_DWARF_PLANET
const IS_MOON := BodyFlags.IS_MOON
const IS_TIDALLY_LOCKED := BodyFlags.IS_TIDALLY_LOCKED
const NEVER_SLEEP := BodyFlags.NEVER_SLEEP
const IS_SERVER = Enums.NetworkState.IS_SERVER

# persisted
var body_id := -1
var flags := 0 # see Enums.BodyFlags
var characteristics := {} # non-object values
var components := {} # objects (persisted only)
var satellites := [] # Body instances
var lagrange_points := [] # LPoint instances (lazy init as needed)

const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["name", "body_id", "flags", "characteristics", "components",
	"satellites", "lagrange_points"]

# public - read-only except builder classes; not persisted unless noted
var m_radius := NAN # persisted in characteristics
var model_controller: ModelController # persisted in components
var orbit: Orbit # persisted in components
var aux_graphic: Spatial # rings, commet tail, etc. (for visibility control)
var omni_light: OmniLight # star only
var hud_orbit: HUDOrbit
var hud_label: HUDLabel
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
var _times: Array = Global.times
var _state: Dictionary = Global.state
var _camera_info: Array = Global.camera_info
var _mouse_target: Array = Global.mouse_target
onready var _tree := get_tree()
onready var _huds_manager: HUDsManager = Global.program.HUDsManager
var _show_orbit := true
var _show_label := true
var _model_visible := false
var _aux_graphic_visible := false
var _hud_orbit_visible := false
var _hud_label_visible := false
var _is_visible := false


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

func get_latitude_longitude(translation_: Vector3, time := NAN) -> Vector2:
	if !model_controller:
		return VECTOR2_ZERO
	return model_controller.get_latitude_longitude(translation_, time)

func get_north(_time := NAN) -> Vector3:
	# Returns this body's north in ecliptic coordinates.
	# TODO: North precession; will require time
	if !model_controller:
		return ECLIPTIC_Z
	return model_controller.north_pole

func get_orbit_semi_major_axis(time := NAN) -> float:
	if !orbit:
		return 0.0
	return orbit.get_semimajor_axis(time)

func get_orbit_normal(time := NAN, flip_retrograde := false) -> Vector3:
	if !orbit:
		return ECLIPTIC_Z
	return orbit.get_normal(time, flip_retrograde)

func get_orbit_inclination_to_equator(time := NAN) -> float:
	if !orbit or flags & BodyFlags.IS_TOP:
		return NAN
	var parent_north: Vector3 = get_parent().get_north(time)
	var orbit_normal := orbit.get_normal(time)
	return parent_north.angle_to(orbit_normal)

func get_sidereal_rotation_period() -> float:
	if !model_controller:
		return NAN
	return model_controller.rotation_period

func get_sidereal_rotation_period_qualifier() -> String:
	if flags & BodyFlags.IS_TIDALLY_LOCKED:
		return "TXT_TIDALLY_LOCKED"
	if flags & BodyFlags.CHAOTIC_ROTATION:
		return "TXT_CHAOTIC"
	if name == "PLANET_MERCURY":
		return "3:2 " + tr("TXT_RESONANCE")
	if model_controller and model_controller.rotation_period < 0.0:
		return "TXT_RETROGRADE"
	return ""

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

func set_orbit(orbit_: Orbit) -> void:
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
		_on_orbit_changed(false)
	else:
		components.erase("orbit")

func set_model_controller(model_controller_: ModelController) -> void:
	if model_controller == model_controller_:
		return
	if model_controller:
		model_controller.disconnect("changed", self, "_on_model_controller_changed")
	model_controller = model_controller_
	if model_controller_:
		components.model_controller = model_controller_
		model_controller_.connect("changed", self, "_on_model_controller_changed")
		_on_model_controller_changed()
	else:
		components.erase("model_controller")

# *****************************************************************************
# ivoyager mechanics & private

func set_hide_hud_when_close(hide_hud_when_close: bool) -> void:
	if hide_hud_when_close:
		min_hud_dist = m_radius * min_hud_dist_radius_multiplier
		if flags & IS_STAR:
			min_hud_dist *= min_hud_dist_star_multiplier # just the label
	else:
		min_hud_dist = 0.0

func set_sleep(sleep: bool) -> void: # called by SleepManager
	if flags & NEVER_SLEEP or sleep == is_asleep:
		return
	if sleep:
		is_asleep = true
		set_process(false)
		_is_visible = false
		visible = false
		if _mouse_target[1] == self:
			_mouse_target[1] = null
			_mouse_target[2] = INF
		if hud_orbit: # not a child of this node!
			_hud_orbit_visible = false
			hud_orbit.visible = false
		if hud_label: # not a child of this node!
			_hud_label_visible = false
			hud_label.visible = false
	else:
		is_asleep = false
		set_process(true) # will show on next _process()

# virtual functions call private functions so subclass can override
func _init() -> void:
	_on_init()

func _enter_tree() -> void:
	_on_enter_tree()

func _ready() -> void:
	_on_ready()

func _process(delta: float) -> void:
	_on_process(delta)

func _on_init() -> void:
	hide()

func _on_enter_tree() -> void:
	if !_state.is_loaded_game or _state.is_system_built:
		return
	# loading game inits
	m_radius = characteristics.m_radius
	orbit = components.get("orbit")
	model_controller = components.get("model_controller")
	if orbit:
		orbit.reset_elements_and_interval_update()
		orbit.connect("changed", self, "_on_orbit_changed")
		_on_orbit_changed(false)
	if model_controller:
		model_controller.connect("changed", self, "_on_model_controller_changed")
		_on_model_controller_changed()

func _on_ready() -> void:
#	Global.connect("system_tree_ready", self, "_on_system_tree_ready")
	Global.connect("about_to_free_procedural_nodes", self, "_prepare_to_free", [], CONNECT_ONESHOT)
	Global.connect("setting_changed", self, "_settings_listener")
	_huds_manager.connect("show_huds_changed", self, "_on_show_huds_changed")

#func _on_system_tree_ready(_is_new_game: bool) -> void:
#	pass

func _prepare_to_free() -> void:
	set_process(false)
	Global.disconnect("setting_changed", self, "_settings_listener")
	_huds_manager.disconnect("show_huds_changed", self, "_on_show_huds_changed")

func _on_process(_delta: float) -> void:
	var global_translation := global_transform.origin
	var camera_global_translation: Vector3 = _camera_info[1]
	var camera_dist := global_translation.distance_to(camera_global_translation)
	var is_mouse_near := false
	var position_2d := VECTOR2_NULL
	var camera: Camera = _camera_info[0]
	if !camera.is_position_behind(global_translation):
		position_2d = camera.unproject_position(global_translation)
		var mouse_dist := position_2d.distance_to(_mouse_target[0]) # mouse position
		var click_radius := min_click_radius
		var divisor: float = _camera_info[2] * camera_dist # fov * dist
		if divisor > 0.0:
			var screen_radius: float = 55.0 * m_radius * _camera_info[3] / divisor
			if click_radius < screen_radius:
				click_radius = screen_radius
		if mouse_dist < click_radius:
			is_mouse_near = true
			if camera_dist < _mouse_target[2]:
				_mouse_target[1] = self
				_mouse_target[2] = camera_dist
	if !is_mouse_near and _mouse_target[1] == self:
		_mouse_target[1] = null
		_mouse_target[2] = INF
	var hud_dist_ok := camera_dist > min_hud_dist
	if hud_dist_ok:
		var orbit_radius := translation.length() if orbit else INF
		hud_dist_ok = camera_dist < orbit_radius * max_hud_dist_orbit_radius_multiplier
	var hud_label_visible := _show_label and hud_dist_ok and hud_label \
			and position_2d != VECTOR2_NULL
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

func _on_show_huds_changed() -> void:
	_show_orbit = _huds_manager.show_orbits
	_show_label = _huds_manager.show_names or _huds_manager.show_symbols

func _on_model_controller_changed() -> void:
	pass
	# TODO: Network sync

func _on_orbit_changed(is_scheduled: bool) -> void:
#	prints("Orbit change: ", orbit._update_interval / UnitDefs.HOUR, "hr", tr(name))
	if flags & IS_TIDALLY_LOCKED and model_controller:
		var new_north_pole := orbit.get_normal(_times[0])
		if model_controller.axial_tilt != 0.0:
			var correction_axis := new_north_pole.cross(orbit.reference_normal).normalized()
			new_north_pole = new_north_pole.rotated(correction_axis, model_controller.axial_tilt)
		model_controller.north_pole = new_north_pole
		model_controller.emit_signal("changed")
		# TODO: Adjust basis_at_epoch???
	if !is_scheduled and _state.network_state == IS_SERVER: # sync clients
		# scheduled changes happen on client so don't need sync
		rpc("_orbit_sync", orbit.reference_normal, orbit.elements_at_epoch, orbit.element_rates,
				orbit.m_modifiers)

remote func _orbit_sync(reference_normal: Vector3, elements_at_epoch: Array,
		element_rates: Array, m_modifiers: Array) -> void: # client-side network game only
	if _tree.get_rpc_sender_id() != 1:
		return # from server only
	orbit.orbit_sync(reference_normal, elements_at_epoch, element_rates, m_modifiers)

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
