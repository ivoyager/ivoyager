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
const HUD_TOO_FAR_ORBIT_R_MULTIPLIER := 100.0
const HUD_TOO_CLOSE_M_RADIUS_MULTIPLIER := 500.0
const HUD_TOO_CLOSE_STAR_MULTIPLIER := 3.0 # combines w/ above

# persisted
var body_id := -1
var is_star := false
var is_planet := false # true for dwarf planets
var is_moon := false # true for minor moons
var is_spacecraft := false
var body_type := -1 # stays -1 for non-physical barycenters & lagrange points
var selection_type := -1
var starlight_type := -1
var classification := "" # move to SelectionItem
var is_top := false # true for top spatial node only (the sun in I, Voyager)
var is_star_orbiting := false
var is_gas_giant := false
var is_dwarf_planet := false
var is_minor_moon := false
var has_atmosphere := false
var tidally_locked := false
var mass := 0.0
var gm := 0.0
var esc_vel := 0.0
var m_radius := 0.0
var e_radius := 0.0
var system_radius := 0.0 # widest orbiting satellite
var rotation_period := 0.0
var axial_tilt := 0.0
var right_ascension := -INF
var declination := -INF
var has_minor_moons: bool
var reference_basis := Basis()
var north_pole := Vector3(0.0, 0.0, 1.0)
# optional characteristics (for display, INF -> ?; -INF -> don't show)
var density := INF
var albedo := -INF
var surf_pres := -INF
var surf_t := -INF # NA for gas giants
var min_t := -INF
var max_t := -INF
var one_bar_t := -INF # venus, gas giants
var half_bar_t := -INF # earth, venus, gas giants
var tenth_bar_t := -INF # gas giants
# file reading
var file_prefix: String
var rings_info: Array # [file_name, radius] if exists

var orbit: Orbit
var satellites := [] # Body instances
var lagrange_points := [] # instanced when needed

const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["name", "body_id", "is_star", "is_planet", "is_moon",
	"is_spacecraft", "body_type", "selection_type",
	"starlight_type", "classification", "is_top", "is_star_orbiting",
	"is_gas_giant", "is_dwarf_planet", "is_minor_moon",
	"has_atmosphere", "tidally_locked", "mass", "gm",
	"esc_vel", "m_radius", "e_radius", "system_radius", "rotation_period", "axial_tilt",
	"right_ascension", "declination",
	"has_minor_moons", "reference_basis", "north_pole",
	 "density", "albedo", "surf_pres", "surf_t", "min_t", "max_t",
	"one_bar_t", "half_bar_t", "tenth_bar_t",
	"file_prefix", "rings_info"]
const PERSIST_OBJ_PROPERTIES := ["orbit", "satellites", "lagrange_points"]

# public unpersisted - set by BodyBuilder
var model: Spatial
var aux_graphic: Spatial # rings, commet tail, etc.
var hud_orbit: HUDOrbit
var hud_icon: HUDIcon
var hud_label: HUDLabel
var texture_2d: Texture
var texture_slice_2d: Texture # GUI graphic for sun only
var model_basis: Basis # at epoch
var model_too_far := 0.0
var aux_graphic_too_far := 0.0
var aux_graphic_process := false
var hud_too_close := 0.0
var satellite_indexes: Dictionary # shared

# private
var _times: Array = Global.times
var _visible := false
var _model_visible := false
var _aux_graphic_visible := false
var _hud_orbit_visible := false
var _hud_label_visible := false
var _hud_icon_visible := false


func set_label_text(text: String) -> void:
	if hud_label:
		hud_label.text = text

func set_hud_too_close(hide_hud_when_close: bool) -> void:
	if hide_hud_when_close:
		hud_too_close = m_radius * HUD_TOO_CLOSE_M_RADIUS_MULTIPLIER
		if is_star:
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
			var rotation_angle := wrapf(time * TAU / rotation_period, 0.0, TAU)
			model.transform.basis = model_basis.rotated(north_pole, rotation_angle)
		if _model_visible != model_visible:
			_model_visible = model_visible
			model.visible = model_visible
#			prints(tr(name), model_visible)
	if aux_graphic:
		var aux_graphic_visible := camera_dist < aux_graphic_too_far
		if aux_graphic_visible and aux_graphic_process:
			aux_graphic.body_process(time)
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
	if hud_orbit: # not a child of this node!
		_hud_orbit_visible = false
		hud_orbit.visible = false
	if hud_label: # not a child of this node!
		_hud_label_visible = false
		hud_label.visible = false
	# Note: Visibility is NOT propagated from 3D to 2D nodes! So we can't just
	# add HUDLabel as child of this node.
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
	if tidally_locked:
		var new_north_pole := orbit.get_normal(_times[0])
		if axial_tilt != 0.0:
			var correction_axis := new_north_pole.cross(orbit.reference_normal).normalized()
			new_north_pole = new_north_pole.rotated(correction_axis, axial_tilt)
		north_pole = new_north_pole
		# TODO: Adjust reference_basis

func _settings_listener(setting: String, value) -> void:
	match setting:
		"planet_orbit_color":
			if is_planet and !is_dwarf_planet and hud_orbit:
				hud_orbit.change_color(value)
		"dwarf_planet_orbit_color":
			if is_dwarf_planet and hud_orbit:
				hud_orbit.change_color(value)
		"moon_orbit_color":
			if is_moon and !is_minor_moon and hud_orbit:
				hud_orbit.change_color(value)
		"minor_moon_orbit_color":
			if is_minor_moon and hud_orbit:
				hud_orbit.change_color(value)
		"hide_hud_when_close":
			set_hud_too_close(value)
