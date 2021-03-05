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
# TODO: Make LPoint into Body instances
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
const HUD_TOO_FAR_ORBIT_R_MULTIPLIER := 100.0
const HUD_TOO_CLOSE_M_RADIUS_MULTIPLIER := 500.0
const HUD_TOO_CLOSE_STAR_MULTIPLIER := 20.0 # combines w/ above
const MIN_CLICK_RADIUS := 20.0

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
# name is table row key ("MOON_EUROPA", etc.), which is localization key
var symbol := "\u25CC" # dashed circle default
var body_id := -1
var class_type := -1 # classes.csv
var model_type := -1 # models.csv
var light_type := -1 # lights.csv (probably -1 except stars)
var flags := 0 # see Enums.BodyFlags

var system_radius := 0.0 # widest orbiting satellite
var file_info := [""] # [file_prefix, icon [REMOVED], rings, rings_radius], 1st required

var properties: Properties
var model_geometry: ModelGeometry
var orbit: Orbit
var satellites := [] # Body instances
var lagrange_points := [] # LPoint instances (lazy init as needed)

const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["name", "symbol", "body_id", "class_type", "model_type",
	"light_type", "flags", "system_radius", "file_info"]
const PERSIST_OBJ_PROPERTIES := ["properties", "model_geometry", "orbit", "satellites",
	"lagrange_points"]

# public unpersisted - read-only except builder classes
var aux_graphic: Spatial # rings, commet tail, etc. (for visibility control)
var omni_light: OmniLight # star only
var hud_orbit: HUDOrbit
var hud_label: HUDLabel
var texture_2d: Texture
var texture_slice_2d: Texture # GUI navigator graphic for sun only
var model_too_far := 0.0
var aux_graphic_too_far := 0.0
var hud_too_close := 0.0
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
var _visible := false
var _model_visible := false
var _aux_graphic_visible := false
var _hud_orbit_visible := false
var _hud_label_visible := false


func get_file_prefix() -> String:
	return file_info[0]

func has_rings() -> bool:
	return file_info.size() > 2

func get_rings_file() -> String:
	if file_info.size() > 2:
		return file_info[2]
	return ""

func get_rings_radius() -> float:
	if file_info.size() > 2:
		return file_info[3]
	return 0.0

func get_latitude_longitude(translation_: Vector3, time := NAN) -> Vector2:
	if !model_geometry:
		return VECTOR2_ZERO
	return model_geometry.get_latitude_longitude(translation_, time)

func get_north(_time := NAN) -> Vector3:
	# Returns this body's north in ecliptic coordinates.
	# TODO: North precession
	if !model_geometry:
		return ECLIPTIC_Z
	return model_geometry.north_pole

func get_orbit_normal(time := NAN) -> Vector3:
	if !orbit:
		return ECLIPTIC_Z
	if is_nan(time):
		time = _times[0]
	return orbit.get_normal(time)

func get_ground_ref_basis(time := NAN) -> Basis:
	# returns rotation basis referenced to ground
	if !model_geometry:
		return IDENTITY_BASIS
	return model_geometry.get_ground_ref_basis(time)

func get_orbit_ref_basis(time := NAN) -> Basis:
	# returns rotation basis referenced to parent body
	if !orbit:
		return IDENTITY_BASIS
	if is_nan(time):
		time = _times[0]
	var x_axis := -orbit.get_position(time).normalized()
	var up := orbit.get_normal(time)
	var y_axis := up.cross(x_axis).normalized() # norm needed due to imprecision
	var z_axis := x_axis.cross(y_axis)
	return Basis(x_axis, y_axis, z_axis)

func set_orbit(orbit_: Orbit, skip_reset := false) -> void:
	if orbit == orbit_:
		return
	if orbit:
		orbit.clear_for_disposal()
	if !skip_reset:
		orbit_.reset()
	orbit = orbit_

# *****************************************************************************
# ivoyager mechanics & private

func reset_orbit():
	if orbit:
		orbit.reset()

func set_hide_hud_when_close(hide_hud_when_close: bool) -> void:
	if hide_hud_when_close:
		hud_too_close = properties.m_radius * HUD_TOO_CLOSE_M_RADIUS_MULTIPLIER
		if flags & IS_STAR:
			hud_too_close *= HUD_TOO_CLOSE_STAR_MULTIPLIER # just the label
	else:
		hud_too_close = 0.0

func set_sleep(sleep: bool) -> void: # called by SleepManager
	if flags & NEVER_SLEEP or sleep == is_asleep:
		return
	if sleep:
		is_asleep = true
		set_process(false)
		_visible = false
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

func _init():
	_on_init() # can override

func _on_init() -> void:
	hide()

func _ready():
	_on_ready() # can override

func _on_ready() -> void:
	Global.connect("about_to_free_procedural_nodes", self, "_prepare_to_free", [],
			CONNECT_ONESHOT)
	Global.connect("setting_changed", self, "_settings_listener")
	_huds_manager.connect("show_huds_changed", self, "_on_show_huds_changed")
	if orbit:
		orbit.connect("changed", self, "_on_orbit_changed")

func _prepare_to_free() -> void:
	set_process(false)
	Global.disconnect("setting_changed", self, "_settings_listener")
	_huds_manager.disconnect("show_huds_changed", self, "_on_show_huds_changed")

func _process(_delta: float) -> void:
	var global_translation := global_transform.origin
	var camera_global_translation: Vector3 = _camera_info[1]
	var camera_dist := global_translation.distance_to(camera_global_translation)
	var is_mouse_near := false
	var position_2d := VECTOR2_NULL
	var camera: Camera = _camera_info[0]
	if !camera.is_position_behind(global_translation):
		position_2d = camera.unproject_position(global_translation)
		var mouse_dist := position_2d.distance_to(_mouse_target[0])
		var click_radius := MIN_CLICK_RADIUS
		var divisor: float = _camera_info[2] * camera_dist
		if divisor > 0.0:
			var radius: float = 55.0 * properties.m_radius * _camera_info[3] / divisor
			if click_radius < radius:
				click_radius = radius
		if mouse_dist < click_radius:
			is_mouse_near = true
			if camera_dist < _mouse_target[2]:
				_mouse_target[1] = self
				_mouse_target[2] = camera_dist
	if !is_mouse_near and _mouse_target[1] == self:
		_mouse_target[1] = null
		_mouse_target[2] = INF
	var hud_dist_ok := camera_dist > hud_too_close
	if hud_dist_ok:
		var orbit_radius := translation.length() if orbit else INF
		hud_dist_ok = camera_dist < orbit_radius * HUD_TOO_FAR_ORBIT_R_MULTIPLIER
	var hud_label_visible := _show_label and hud_dist_ok and hud_label \
			and position_2d != VECTOR2_NULL
	if hud_label_visible:
		# position 2D Label before 3D translation!
		hud_label.set_position(position_2d - hud_label.rect_size / 2.0)
	var time: float = _times[0]
	if orbit:
		translation = orbit.get_position(time)
	if model_geometry:
		var model_visible := camera_dist < model_too_far
		if model_visible:
			model_geometry.process_visible(time, camera_dist)
		if _model_visible != model_visible:
			_model_visible = model_visible
			model_geometry.change_visibility(model_visible)
	if aux_graphic:
		var aux_graphic_visible := camera_dist < aux_graphic_too_far
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
	if !_visible:
		_visible = true
		visible = true

func _on_show_huds_changed() -> void:
	_show_orbit = _huds_manager.show_orbits
	_show_label = _huds_manager.show_names or _huds_manager.show_symbols

func _on_orbit_changed(is_scheduled: bool) -> void:
#	prints("Orbit change: ", (1.0 / orbit.update_frequency) / UnitDefs.HOUR, "hr", tr(name))
	if flags & IS_TIDALLY_LOCKED:
		var new_north_pole := orbit.get_normal(_times[0])
		if model_geometry.axial_tilt != 0.0:
			var correction_axis := new_north_pole.cross(orbit.reference_normal).normalized()
			new_north_pole = new_north_pole.rotated(correction_axis, model_geometry.axial_tilt)
		model_geometry.north_pole = new_north_pole
		# TODO: Adjust basis_at_epoch???
	if !is_scheduled and _state.network_state == IS_SERVER: # sync clients
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
