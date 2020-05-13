# body.gd
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
# Base class for spatial nodes that have an orbit or can be orbited, including
# non-physical barycenters & lagrange points. The system tree is composed of
# Body instances from top to bottom, each Body having its orbiting children
# (other Body instances) and other spatial children that are visuals: Model,
# Rings, HUDOrbit.
#
# TODO: Make LPoint into Body instances
# TODO: barycenters

extends Spatial
class_name Body

const DPRINT := false
const HACKFIX_MOVE_HIDDEN_FAR_AWAY := false # This *seems* to help as of Godot 3.2.1
const HUD_TOO_FAR_ORBIT_R_MULTIPLIER := 100.0
const HUD_TOO_CLOSE_M_RADIUS_MULTIPLIER := 500.0
const HUD_TOO_CLOSE_STAR_MULTIPLIER := 20.0 # combines w/ above

const BodyFlags := Enums.BodyFlags
const IS_STAR := BodyFlags.IS_STAR
const IS_TRUE_PLANET := BodyFlags.IS_TRUE_PLANET
const IS_DWARF_PLANET := BodyFlags.IS_DWARF_PLANET
const IS_MOON := BodyFlags.IS_MOON
const IS_TIDALLY_LOCKED := BodyFlags.IS_TIDALLY_LOCKED

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
var model_manager: ModelManager
var orbit: Orbit
var satellites := [] # Body instances
var lagrange_points := [] # LPoint instances (lazy init as needed)

const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["name", "symbol", "body_id", "class_type", "model_type",
	"light_type", "flags", "system_radius", "file_info"]
const PERSIST_OBJ_PROPERTIES := ["properties", "model_manager", "orbit", "satellites",
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
var satellite_indexes: Dictionary # one dict shared by all Bodies

# private
var _times: Array = Global.times
var _camera_info: Array = Global.camera_info
var _visible := false
var _model_visible := false
var _aux_graphic_visible := false
var _hud_orbit_visible := false
var _hud_label_visible := false


func set_hud_too_close(hide_hud_when_close: bool) -> void:
	if hide_hud_when_close:
		hud_too_close = properties.m_radius * HUD_TOO_CLOSE_M_RADIUS_MULTIPLIER
		if flags & IS_STAR:
			hud_too_close *= HUD_TOO_CLOSE_STAR_MULTIPLIER
	else:
		hud_too_close = 0.0

func tree_manager_process(time: float, camera: Camera, camera_global_translation: Vector3,
		show_orbits: bool, show_label: bool) -> void:
	# TODO: Need viewport size correction
	var global_translation := global_transform.origin
	var camera_dist := global_translation.distance_to(camera_global_translation)
	var hud_dist_ok := camera_dist > hud_too_close
	if hud_dist_ok:
		var orbit_radius := translation.length() if orbit else INF
		hud_dist_ok = camera_dist < orbit_radius * HUD_TOO_FAR_ORBIT_R_MULTIPLIER
	var hud_label_visible := show_label and hud_dist_ok and hud_label \
			and !camera.is_position_behind(global_translation)
	if hud_label_visible: # position 2D node before 3D translation!
		var position_2d := camera.unproject_position(global_translation)
		hud_label.set_position(position_2d - hud_label.rect_size / 2.0)
	if orbit:
		translation = orbit.get_position(time)
	if model_manager:
		var model_visible := camera_dist < model_too_far
		if model_visible:
			model_manager.process_visible(time, camera_dist)
		if _model_visible != model_visible:
			_model_visible = model_visible
			model_manager.change_visibility(model_visible)
	if aux_graphic:
		var aux_graphic_visible := camera_dist < aux_graphic_too_far
		if _aux_graphic_visible != aux_graphic_visible:
			_aux_graphic_visible = aux_graphic_visible
			aux_graphic.visible = aux_graphic_visible
	if hud_orbit:
		var hud_orbit_visible := show_orbits and hud_dist_ok
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

func hide_visuals() -> void:
	_visible = false
	visible = false # hides all tree descendants, including model
	if HACKFIX_MOVE_HIDDEN_FAR_AWAY:
		translation = Vector3(1e12, 1e12, 1e12)
	if hud_orbit: # not a child of this node!
		_hud_orbit_visible = false
		hud_orbit.visible = false
	if hud_label: # not a child of this node!
		_hud_label_visible = false
		hud_label.visible = false
	# Note: Visibility is NOT propagated from 3D to 2D nodes! So we can't just
	# add HUD label as child of this node.
	# TODO: We could add 2D labels in our tree-structure so visibility is
	# propagated that way. I think something like "set_is_top" would prevent
	# inheritin position.

func _init():
	_on_init()

func _on_init() -> void:
	connect("ready", self, "_on_ready")
	hide()

func _on_ready() -> void:
	Global.connect("setting_changed", self, "_settings_listener")
	if orbit:
		orbit.connect("changed_for_graphics", self, "_update_orbit_change")

func _update_orbit_change():
	if flags & IS_TIDALLY_LOCKED:
		var new_north_pole := orbit.get_normal(_times[0])
		if model_manager.axial_tilt != 0.0:
			var correction_axis := new_north_pole.cross(orbit.reference_normal).normalized()
			new_north_pole = new_north_pole.rotated(correction_axis, model_manager.axial_tilt)
		model_manager.north_pole = new_north_pole
		# TODO: Adjust body_ref_basis???

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
			set_hud_too_close(value)
