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

const NULL_ROTATION := Vector3(-INF, -INF, -INF)


var views := {}


func _project_init() -> void:
	_hide_all()
	_planets1()
	_asteroids1()
	_default_colors()
#	_zoom()


# public API

func set_view(view_name: String, is_camera_instant_move := false) -> void:
	if !views.has(view_name):
		return
	var view: IVView = views[view_name]
	view.set_state(is_camera_instant_move)


# private

func _hide_all() -> void:
	var _View_: Script = IVGlobal.script_classes._View_
	var view: IVView = _View_.new()
	view.flags = IVView.HUDS_VISIBILITY
	views.hide_all = view


func _planets1() -> void:
	# Just the major bodies plus small moons (names and orbits).
	var _View_: Script = IVGlobal.script_classes._View_
	var BodyFlags: Dictionary = IVEnums.BodyFlags
	
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
	views.planets1 = view


func _asteroids1() -> void:
	# We set planet & moon visibilities for perspective. All asteroid points
	# are set but not asteroid orbits (which are overwhelming).
	var _View_: Script = IVGlobal.script_classes._View_
	var BodyFlags: Dictionary = IVEnums.BodyFlags
	var SBG_CLASS_ASTEROIDS: int = IVEnums.SBGClass.SBG_CLASS_ASTEROIDS
	
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
	for row in table_reader.get_n_rows("small_bodies_groups"):
		if table_reader.get_bool("small_bodies_groups", "skip_import", row):
			continue
		if table_reader.get_int("small_bodies_groups", "sbg_class", row) != SBG_CLASS_ASTEROIDS:
			continue
		var sbg_alias := table_reader.get_string("small_bodies_groups", "sbg_alias", row)
		visible_points_groups.append(sbg_alias)
	
	views.asteroids1 = view


func _default_colors() -> void:
	# Empty View dicts set default colors.
	var _View_: Script = IVGlobal.script_classes._View_
	var view: IVView = _View_.new()
	view.flags = IVView.HUDS_COLOR
	views.default_colors = view


# WIP
#
#func _zoom() -> void:
#	var CameraFlags := IVEnums.CameraFlags
#
#	var _View_: Script = IVGlobal.script_classes._View_
#	var view: IVView = _View_.new()
#	view.flags = IVView.CAMERA_ORIENTATION
#	view.camera_flags = (
#			CameraFlags.UP_LOCKED
#			| CameraFlags.TRACK_ORBIT
#	)
#
#	view.view_position
#
#	view.view_rotations = Vector3.ZERO
#
#	views.zoom = view
	
	
	
	




