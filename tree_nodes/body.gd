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
# Rings, HUDIcon, HUDOrbit, etc.
#
# See static/unit_defs.gd for base units. For float values, interpret -INF as
# not applicable (NA) and +INF as unknown (?). 
#
# TODO: Make LPoint into Body instances
# TODO: barycenters

extends Spatial
class_name Body

const DPRINT := false
const HACKFIX_MOVE_HIDDEN_FAR_AWAY := true # This *seems* to help as of Godot 3.2.1
const HUD_TOO_FAR_ORBIT_R_MULTIPLIER := 100.0
const HUD_TOO_CLOSE_M_RADIUS_MULTIPLIER := 500.0
const HUD_TOO_CLOSE_STAR_MULTIPLIER := 3.0 # combines w/ above

const BodyFlags := Enums.BodyFlags
const IS_STAR := BodyFlags.IS_STAR
const IS_TRUE_PLANET := BodyFlags.IS_TRUE_PLANET
const IS_DWARF_PLANET := BodyFlags.IS_DWARF_PLANET
const IS_MOON := BodyFlags.IS_MOON
const IS_TIDALLY_LOCKED := BodyFlags.IS_TIDALLY_LOCKED

# persisted
var body_id := -1
var class_type := -1 # classes.csv
var model_type := -1 # models.csv
var light_type := -1 # lights.csv (probably -1 except stars)
var flags := 0 # see Enums.BodyFlags

var system_radius := 0.0 # widest orbiting satellite
var reference_basis := Basis()


# file reading
var file_prefix: String
var rings_info: Array # [file_name, radius] if exists

var properties: Properties
var rotations: Rotations
var orbit: Orbit
var satellites := [] # Body instances
var lagrange_points := [] # LPoint instances (lazy init as needed)

const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["name", "body_id", "class_type", "model_type",
	"light_type", "flags", "system_radius", "reference_basis", "file_prefix", "rings_info"]
const PERSIST_OBJ_PROPERTIES := ["properties", "rotations", "orbit", "satellites", "lagrange_points"]

# public unpersisted - read-only except builder classes
var model: Spatial
var aux_graphic: Spatial # rings, commet tail, etc. (for visibile control)
var hud_orbit: HUDOrbit
var hud_icon: Spatial
var hud_label: Control
var texture_2d: Texture
var texture_slice_2d: Texture # GUI navigator graphic for sun only
var model_basis: Basis # at epoch
var model_too_far := 0.0
var aux_graphic_too_far := 0.0
var hud_too_close := 0.0
var satellite_indexes: Dictionary # one dict shared by all Bodies

# private
var _times: Array = Global.times
var _visible := false
var _model_visible := false
var _aux_graphic_visible := false
var _hud_orbit_visible := false
var _hud_label_visible := false
var _hud_icon_visible := false


func set_hud_too_close(hide_hud_when_close: bool) -> void:
	if hide_hud_when_close:
		hud_too_close = properties.m_radius * HUD_TOO_CLOSE_M_RADIUS_MULTIPLIER
		if flags & IS_STAR:
			hud_too_close *= HUD_TOO_CLOSE_STAR_MULTIPLIER
	else:
		hud_too_close = 0.0

func tree_manager_process(time: float, camera: Camera, camera_global_translation: Vector3,
		show_orbits: bool, show_icons: bool, show_labels: bool) -> void:
	# TODO: Need viewport size correction
	var global_translation := global_transform.origin
	var camera_dist := global_translation.distance_to(camera_global_translation)
	var hud_dist_ok := camera_dist > hud_too_close
	if hud_dist_ok:
		var orbit_radius := translation.length() if orbit else INF
		hud_dist_ok = camera_dist < orbit_radius * HUD_TOO_FAR_ORBIT_R_MULTIPLIER
	var hud_label_visible := show_labels and hud_dist_ok and hud_label \
			and !camera.is_position_behind(global_translation)
	if hud_label_visible: # position 2D node before 3D translation!
		var label_pos := camera.unproject_position(global_translation)
		var label_offset := -hud_label.rect_size / 2.0
		hud_label.set_position(label_pos + label_offset)
	if orbit:
		translation = orbit.get_position(time)
	if model:
		var model_visible := camera_dist < model_too_far
		if model_visible:
			model.transform.basis = rotations.get_basis(time, model_basis)
#			var rotation_angle := wrapf(time * TAU / rotation_period, 0.0, TAU)
#			model.transform.basis = model_basis.rotated(north_pole, rotation_angle)
		if _model_visible != model_visible:
			_model_visible = model_visible
			model.visible = model_visible
#			prints(tr(name), model_visible)
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
	if hud_icon:
		var hud_icon_visible := show_icons and hud_dist_ok
		if _hud_icon_visible != hud_icon_visible:
			_hud_icon_visible = hud_icon_visible
			hud_icon.visible = hud_icon_visible
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
		if rotations.axial_tilt != 0.0:
			var correction_axis := new_north_pole.cross(orbit.reference_normal).normalized()
			new_north_pole = new_north_pole.rotated(correction_axis, rotations.axial_tilt)
		rotations.north_pole = new_north_pole
		# TODO: Adjust reference_basis

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
