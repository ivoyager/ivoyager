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

# Generates 'default' IVView instances that GUI might want to use.

var views := {}


func _project_init() -> void:
	_make_hide_all()
	_make_planets1()
	_make_asteroids1()
	_make_default_colors()


# public API

func set_view(view_name: String, is_camera_instant_move := false) -> void:
	if !views.has(view_name):
		return
	var view: IVView = views[view_name]
	view.set_state(is_camera_instant_move)


# private

func _make_hide_all() -> void:
	var _View_: Script = IVGlobal.script_classes._View_
	var hide_all: IVView = _View_.new()
	hide_all.has_huds_visibility_state = true
	views.hide_all = hide_all


func _make_planets1() -> void:
	# Just the major bodies plus small moons (names and orbits).
	var _View_: Script = IVGlobal.script_classes._View_
	var BodyFlags: Dictionary = IVEnums.BodyFlags
	
	var planets1: IVView = _View_.new()
	planets1.has_huds_visibility_state = true
	planets1.orbit_visible_flags = (
			# must be from IVBodyHUDsState.all_flags
			BodyFlags.IS_TRUE_PLANET
			| BodyFlags.IS_DWARF_PLANET
			| BodyFlags.IS_PLANETARY_MASS_MOON
			| BodyFlags.IS_NON_PLANETARY_MASS_MOON
	)
	planets1.name_visible_flags = planets1.orbit_visible_flags | BodyFlags.IS_STAR
	views.planets1 = planets1


func _make_asteroids1() -> void:
	# We set planet & moon visibilities for perspective. All asteroid points
	# are set but not asteroid orbits (which are overwhelming).
	var _View_: Script = IVGlobal.script_classes._View_
	var BodyFlags: Dictionary = IVEnums.BodyFlags
	var SBG_CLASS_ASTEROIDS: int = IVEnums.SBGClass.SBG_CLASS_ASTEROIDS
	
	var asteroids1: IVView = _View_.new()
	asteroids1.has_huds_visibility_state = true
	asteroids1.orbit_visible_flags = (
			# must be from IVBodyHUDsState.all_flags
			BodyFlags.IS_TRUE_PLANET
			| BodyFlags.IS_DWARF_PLANET
			| BodyFlags.IS_PLANETARY_MASS_MOON
			| BodyFlags.IS_NON_PLANETARY_MASS_MOON
	)
	asteroids1.name_visible_flags = asteroids1.orbit_visible_flags | BodyFlags.IS_STAR
	
	# Set asteroid point visibilities from table.
	var visible_points_groups := asteroids1.visible_points_groups
	var table_reader: IVTableReader = IVGlobal.program.TableReader
	for row in table_reader.get_n_rows("small_bodies_groups"):
		if table_reader.get_bool("small_bodies_groups", "skip_import", row):
			continue
		if table_reader.get_int("small_bodies_groups", "sbg_class", row) != SBG_CLASS_ASTEROIDS:
			continue
		var sbg_alias := table_reader.get_string("small_bodies_groups", "sbg_alias", row)
		visible_points_groups.append(sbg_alias)

	views.asteroids1 = asteroids1


func _make_default_colors() -> void:
	# Empty dicts set default colors.
	var _View_: Script = IVGlobal.script_classes._View_
	var default_colors: IVView = _View_.new()
	default_colors.has_huds_color_state = true
	views.default_colors = default_colors


