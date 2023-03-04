# view_defaults.gd
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
class_name IVViewDefaults
extends Reference

# Generates 'default' IVView instances that we might want to use.


const CameraFlags := IVEnums.CameraFlags
const BodyFlags := IVEnums.BodyFlags
const AU := IVUnits.AU
const KM := IVUnits.KM
const NULL_VECTOR3 := Vector3(-INF, -INF, -INF)


var views := {}



var _View_: Script


func _project_init() -> void:
	_View_ = IVGlobal.script_classes._View_
	
	# visibilities & colors only
	_hide_all()
	_planets1()
	_asteroids1()
	_colors1()
	
	# camera (no selection)
	_zoom()
	_fortyfive()
	_top()
	
	# selection, camera, and more...
	_home()
	_cislunar()
	_system()
	_asteroids()


# public API

func set_view(view_name: String, is_camera_instant_move := false) -> void:
	if !views.has(view_name):
		return
	var view: IVView = views[view_name]
	view.set_state(is_camera_instant_move)


func has_view(view_name: String) -> bool:
	return views.has(view_name)


# visibilities & colors only

func _hide_all() -> void:
	# No HUDs visible.
	var view: IVView = _View_.new()
	view.flags = IVView.HUDS_VISIBILITY
	views.HideAll = view


func _planets1() -> void:
	# HUDs visible for the major bodies plus small moons (names and orbits).
	var view: IVView = _View_.new()
	view.flags = IVView.HUDS_VISIBILITY
	view.orbit_visible_flags = (
			# Must be from visibility_groups.tsv subset!
			BodyFlags.IS_TRUE_PLANET
			| BodyFlags.IS_DWARF_PLANET
			| BodyFlags.IS_PLANETARY_MASS_MOON
			| BodyFlags.IS_NON_PLANETARY_MASS_MOON
	)
	view.name_visible_flags = view.orbit_visible_flags | BodyFlags.IS_STAR
	views.Planets1 = view


func _asteroids1() -> void:
	# We set planet & moon visibilities for perspective. All asteroid points
	# are set but not asteroid orbits (which are overwhelming).
	var view: IVView = _View_.new()
	view.flags = IVView.HUDS_VISIBILITY
	view.orbit_visible_flags = (
			# Must be from visibility_groups.tsv subset!
			BodyFlags.IS_TRUE_PLANET
			| BodyFlags.IS_DWARF_PLANET
			| BodyFlags.IS_PLANETARY_MASS_MOON
			| BodyFlags.IS_NON_PLANETARY_MASS_MOON
	)
	view.name_visible_flags = view.orbit_visible_flags | BodyFlags.IS_STAR
	
	# Set asteroid point visibilities from table.
	var visible_points_groups := view.visible_points_groups
	var table_reader: IVTableReader = IVGlobal.program.TableReader
	var SBG_CLASS_ASTEROIDS: int = IVEnums.SBGClass.SBG_CLASS_ASTEROIDS
	for row in table_reader.get_n_rows("small_bodies_groups"):
		if table_reader.get_bool("small_bodies_groups", "skip_import", row):
			continue
		if table_reader.get_int("small_bodies_groups", "sbg_class", row) != SBG_CLASS_ASTEROIDS:
			continue
		var sbg_alias := table_reader.get_string("small_bodies_groups", "sbg_alias", row)
		visible_points_groups.append(sbg_alias)
	
	views.Asteroids1 = view


func _colors1() -> void:
	# Empty View dicts set default colors.
	var view: IVView = _View_.new()
	view.flags = IVView.HUDS_COLOR
	views.Colors1 = view


# camera (no selection)

func _zoom() -> void:
	# Camera positioned for best dramatic view. Orbit tracking. No selection.
	var view: IVView = _View_.new()
	view.flags = IVView.CAMERA_ORIENTATION | IVView.CAMERA_LONGITUDE
	view.camera_flags = CameraFlags.UP_LOCKED # | CameraFlags.TRACK_ORBIT
	view.view_position = Vector3(deg2rad(207.0), deg2rad(18.0), 3.0) # z, radii dist when close
	view.view_rotations = Vector3.ZERO
	views.Zoom = view


func _fortyfive() -> void:
	# Camera positioned 45 degree above view. No selection or longitude.
	var view: IVView = _View_.new()
	view.flags = IVView.CAMERA_ORIENTATION
	view.camera_flags = CameraFlags.UP_LOCKED # | CameraFlags.TRACK_ORBIT
	view.view_position = Vector3(-INF, deg2rad(45.0), 10.0) # z, radii dist when close
	view.view_rotations = Vector3.ZERO
	views.Fortyfive = view


func _top() -> void:
	# Camera positioned almost 90 degrees above. No selection or longitude.
	var view: IVView = _View_.new()
	view.flags = IVView.CAMERA_ORIENTATION
	view.camera_flags = CameraFlags.UP_LOCKED # | CameraFlags.TRACK_ORBIT
	view.view_position = Vector3(-INF, deg2rad(85.0), 25.0) # z, radii dist when close
	view.view_rotations = Vector3.ZERO
	views.Top = view


# selection, camera, and more...

func _home() -> void:
	# Earth zoom. Ground tracking.
	# If project allows, home longitude (from sys timezone) and actual time.
	# Planets, moons & spacecraft visible.
	var view: IVView = _View_.new()
	view.flags = (
			IVView.ALL_CAMERA
			| IVView.HUDS_VISIBILITY
			| IVView.IS_NOW
	)
	view.selection_name = "PLANET_EARTH"
	view.camera_flags = (
			CameraFlags.UP_LOCKED
			| CameraFlags.TRACK_GROUND
			| CameraFlags.SET_USER_LONGITUDE
	)
	view.view_position = Vector3(-INF, 0.0, 3.0) # z, radii dist when close
	view.view_rotations = Vector3.ZERO
	view.orbit_visible_flags = (
			# Must be from visibility_groups.tsv subset!
			BodyFlags.IS_TRUE_PLANET
			| BodyFlags.IS_DWARF_PLANET
			| BodyFlags.IS_PLANETARY_MASS_MOON
			| BodyFlags.IS_NON_PLANETARY_MASS_MOON
			| BodyFlags.IS_SPACECRAFT
	)
	view.name_visible_flags = view.orbit_visible_flags | BodyFlags.IS_STAR
	views.Home = view


func _cislunar() -> void:
	# Camera 15 degrees above Earth (ecliptic) at 120 Earth radii.
	# Planets, moons & spacecraft visible.
	var view: IVView = _View_.new()
	view.flags = IVView.ALL_CAMERA | IVView.HUDS_VISIBILITY
	view.selection_name = "PLANET_EARTH"
	view.camera_flags = CameraFlags.UP_LOCKED | CameraFlags.TRACK_ORBIT
	view.view_position = Vector3(deg2rad(180.0), deg2rad(15.0), 120.0) # z, radii dist when close
	view.view_rotations = Vector3.ZERO
	view.orbit_visible_flags = (
			# Must be from visibility_groups.tsv subset!
			BodyFlags.IS_TRUE_PLANET
			| BodyFlags.IS_DWARF_PLANET
			| BodyFlags.IS_PLANETARY_MASS_MOON
			| BodyFlags.IS_NON_PLANETARY_MASS_MOON
			| BodyFlags.IS_SPACECRAFT
	)
	view.name_visible_flags = view.orbit_visible_flags | BodyFlags.IS_STAR
	views.Cislunar = view


func _system() -> void:
	# Camera 15 degrees above the Sun at 70au.
	# Planets & moons visible.
	var view: IVView = _View_.new()
	view.flags = IVView.ALL_CAMERA | IVView.HUDS_VISIBILITY
	view.selection_name = "STAR_SUN"
	view.camera_flags = CameraFlags.UP_LOCKED | CameraFlags.TRACK_ECLIPTIC
	view.view_position = Vector3(deg2rad(-90.0), deg2rad(15.0), 70.0 * AU) # z, real dist when far
	view.view_rotations = Vector3.ZERO
	view.orbit_visible_flags = (
			# Must be from visibility_groups.tsv subset!
			BodyFlags.IS_TRUE_PLANET
			| BodyFlags.IS_DWARF_PLANET
			| BodyFlags.IS_PLANETARY_MASS_MOON
			| BodyFlags.IS_NON_PLANETARY_MASS_MOON
	)
	view.name_visible_flags = view.orbit_visible_flags | BodyFlags.IS_STAR
	views.System = view


func _asteroids() -> void:
	# Camera 45 degree above the Sun at 15au for best view of Main Belt, Hildas
	# and Jupiter Trojans.
	# We set planet & moon visibilities for perspective. All asteroid points
	# are set but not asteroid orbits (which are overwhelming).
	var view: IVView = _View_.new()
	view.flags =  IVView.ALL_CAMERA | IVView.HUDS_VISIBILITY
	view.selection_name = "STAR_SUN"
	view.camera_flags = CameraFlags.UP_LOCKED | CameraFlags.TRACK_ECLIPTIC
	view.view_position = Vector3(deg2rad(-90.0), deg2rad(45.0), 15.0 * AU) # z, real dist when far
	view.view_rotations = Vector3.ZERO

	view.orbit_visible_flags = (
			# Must be from visibility_groups.tsv subset!
			BodyFlags.IS_TRUE_PLANET
			| BodyFlags.IS_DWARF_PLANET
			| BodyFlags.IS_PLANETARY_MASS_MOON
			| BodyFlags.IS_NON_PLANETARY_MASS_MOON
			| BodyFlags.IS_ASTEROID
	)
	view.name_visible_flags = view.orbit_visible_flags | BodyFlags.IS_STAR
	
	# Set asteroid point visibilities from table.
	var visible_points_groups := view.visible_points_groups
	var table_reader: IVTableReader = IVGlobal.program.TableReader
	var SBG_CLASS_ASTEROIDS: int = IVEnums.SBGClass.SBG_CLASS_ASTEROIDS
	for row in table_reader.get_n_rows("small_bodies_groups"):
		if table_reader.get_bool("small_bodies_groups", "skip_import", row):
			continue
		if table_reader.get_int("small_bodies_groups", "sbg_class", row) != SBG_CLASS_ASTEROIDS:
			continue
		var sbg_alias := table_reader.get_string("small_bodies_groups", "sbg_alias", row)
		visible_points_groups.append(sbg_alias)
	
	views.Asteroids = view

