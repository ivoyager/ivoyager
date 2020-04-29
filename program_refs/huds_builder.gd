# huds_builder.gd
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

class_name HUDsBuilder

const file_utils := preload("res://ivoyager/static/file_utils.gd")

const ORBIT_ARRAY_FLAGS := VisualServer.ARRAY_FORMAT_VERTEX & VisualServer.ARRAY_FORMAT_NORMAL
const ICON_TRANSFORM = Transform(Vector3(100, 0, 0), Vector3(0, 100, 0), Vector3(0, 0, 100),
	Vector3(0, 0, 0))

var _settings: Dictionary = Global.settings
var _icon_quad_mesh: QuadMesh = Global.icon_quad_mesh
var _hud_2d_surface: Control
var _label_font: Font
var _generic_moon_icon: Texture
var _fallback_icon: Texture
var _hud_icons_dir: String
var _orbit_mesh_arrays := []

func project_init() -> void:
	_hud_2d_surface = Global.program.HUD2dSurface
	_label_font = Global.fonts.hud_labels
	_generic_moon_icon = Global.assets.generic_moon_icon
	_fallback_icon = Global.assets.fallback_icon
	_hud_icons_dir = Global.asset_paths.hud_icons_dir
	_build_orbit_mesh_arrays(Global.vertecies_per_orbit)

func add_label(body: Body) -> void:
	var label := Label.new()
	label.text = tr(body.name)
	label.set("custom_fonts/font", Global.fonts.hud_labels)
	label.hide()
	body.hud_label = label
	_hud_2d_surface.add_child(label)

func add_icon(body: Body) -> void:
	var icon := MeshInstance.new()
	var icon_material := SpatialMaterial.new()
	var icon_texture: Texture = file_utils.find_resource(_hud_icons_dir, body.file_prefix)
	if !icon_texture:
		if body.is_moon:
			icon_texture = _generic_moon_icon
		else:
			icon_texture = _fallback_icon
	icon_material.albedo_texture = icon_texture
	icon_material.flags_transparent = true
	icon_material.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
	icon_material.flags_unshaded = true
	icon_material.flags_fixed_size = true
	icon_material.flags_albedo_tex_force_srgb = true
	icon_material.params_billboard_mode = SpatialMaterial.BILLBOARD_ENABLED
	icon.transform = ICON_TRANSFORM
	icon.mesh = _icon_quad_mesh
	icon.material_override = icon_material
	icon.hide()
	body.hud_icon = icon
	body.add_child(icon)

func add_orbit(body: Body) -> void:
	if !body.orbit:
		return
	var hud_orbit := HUDOrbit.new()
	var color: Color
	if body.is_minor_moon:
		color = _settings.minor_moon_orbit_color
	elif body.is_moon:
		color = _settings.moon_orbit_color
	elif body.is_dwarf_planet:
		color = _settings.dwarf_planet_orbit_color
	elif body.is_planet:
		color = _settings.planet_orbit_color
	else:
		color = _settings.default_orbit_color
	hud_orbit.orbit = body.orbit
	hud_orbit.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	hud_orbit.shader_material.shader = Global.shaders.orbit_ellipse
	hud_orbit.material_override = hud_orbit.shader_material
	hud_orbit.orbit_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_LOOP,
			_orbit_mesh_arrays, [], ORBIT_ARRAY_FLAGS)
	hud_orbit.mesh = hud_orbit.orbit_mesh
	hud_orbit.orbit.connect("changed_for_graphics", hud_orbit, "draw_orbit")
	hud_orbit.change_color(color)
	hud_orbit.draw_orbit()
	hud_orbit.hide()
	body.hud_orbit = hud_orbit
	var parent: Spatial = body.get_parent()
	parent.call_deferred("add_child", hud_orbit)

func _build_orbit_mesh_arrays(n_vertecies: int) -> void:
	var verteces := PoolVector3Array()
	var normals := PoolVector3Array()
	verteces.resize(n_vertecies)
	normals.resize(n_vertecies)
	var angle_increment := TAU / n_vertecies
	var i := 0
	while i < n_vertecies:
		var angle: float = i * angle_increment
		verteces[i] = Vector3(sin(angle), cos(angle), 0.0) # circle if shader doesn't work
		normals[i] = Vector3(angle, angle, 0.0) # E, nu, e in orbit_ellipse.shader
		i += 1
	_orbit_mesh_arrays.resize(ArrayMesh.ARRAY_MAX)
	_orbit_mesh_arrays[ArrayMesh.ARRAY_VERTEX] = verteces
	_orbit_mesh_arrays[ArrayMesh.ARRAY_NORMAL] = normals
