# all_huds.gd
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
class_name IVAllHUDs
extends VBoxContainer

# GUI widget that holds all the HUD visibility widgets.
#
# IMPORTANT! For correct visibility control, BodyFlags used in rows of BodyHUDs
# instances must be a subset of IVHUDOrbit.VISIBILITY_BODY_FLAGS.
#
# WIP - hidden buttons [Hide All][Show Default]

const BodyFlags: Dictionary = IVEnums.BodyFlags
const HUDS_VISIBILITY_STATE := IVViewManager.HUDS_VISIBILITY_STATE
const HUDS_COLOR_STATE := IVViewManager.HUDS_COLOR_STATE



# WIP - New buttons [Default Visible][Default Colors] work via BodyHUDsState
# Then, remove 'default' view construction here...

# default HUDs view if user hasn't saved their own
var default_orbit_visible_flags: int = (
		BodyFlags.IS_STAR
		| BodyFlags.IS_TRUE_PLANET
		| BodyFlags.IS_DWARF_PLANET
		| BodyFlags.IS_PLANETARY_MASS_MOON
		| BodyFlags.IS_NON_PLANETARY_MASS_MOON
)
var default_name_visible_flags: int = (
		BodyFlags.IS_STAR
		| BodyFlags.IS_TRUE_PLANET
		| BodyFlags.IS_DWARF_PLANET
		| BodyFlags.IS_PLANETARY_MASS_MOON
		| BodyFlags.IS_NON_PLANETARY_MASS_MOON
)
var default_symbol_visible_flags := 0 # exclusive w/ name_visible_flags
var default_visible_points_groups := []
var default_visible_orbits_groups := []


var _column_master: GridContainer

onready var _body_huds_state: IVBodyHUDsState = IVGlobal.program.BodyHUDsState
onready var _sbg_huds_visibility: IVSBGHUDsVisibility = IVGlobal.program.SBGHUDsVisibility
onready var _view_manager: IVViewManager = IVGlobal.program.ViewManager


func _enter_tree() -> void:
	connect("child_entered_tree", self, "_on_child_entered_tree")


func _ready() -> void:
	$"%HideAllButton".connect("pressed", self, "_hide_all")
	$"%ShowDefaultButton".connect("pressed", self, "_show_default")
	$"%SaveAsDefaultButton".connect("pressed", self, "_save_as_default")
	if _view_manager.has_view("default", "all_huds", true):
		return
	var _View_: Script = IVGlobal.script_classes._View_
	var view: IVView = _View_.new()
	view.set_huds_visibility_data(
		true,
		default_name_visible_flags,
		default_symbol_visible_flags,
		default_orbit_visible_flags,
		default_visible_points_groups,
		default_visible_orbits_groups
	)
	_view_manager.save_view_object(view, "default", "all_huds", true)


func _on_child_entered_tree(control: Control) -> void:
	match control.name:
		
		# BodyHUDs instances
		"SunHUDs":
			# This grid controls all other grid's column widths.
			_column_master = control
			control.column0_en_width = 23
			control.columns_en_width = 6
			control.rows = [
				["LABEL_SUN", BodyFlags.IS_STAR],
			]
			control.disable_orbits_rows.append(0) # no orbit for the Sun
		"PMOsHUDs":
			control.column_master = _column_master
			control.has_headers = false
			control.rows = [
				["LABEL_PLANETARY_MASS_OBJECTS", 0], # 0 causes all flags below to be set
				["   " + tr("LABEL_PLANETS"), BodyFlags.IS_TRUE_PLANET],
				["   " + tr("LABEL_DWARF_PLANETS"), BodyFlags.IS_DWARF_PLANET],
				["   " + tr("LABEL_MOONS"), BodyFlags.IS_PLANETARY_MASS_MOON],
			]
		"NonPMOMoonsHUDs":
			control.column_master = _column_master
			control.has_headers = false
			control.rows = [
				["LABEL_NON_PMO_MOONS", BodyFlags.IS_NON_PLANETARY_MASS_MOON],
			]
		"VisitedAsteroidsHUDs":
			control.column_master = _column_master
			control.has_headers = false
			control.rows = [
				["LABEL_VISITED_ASTEROIDS", BodyFlags.IS_ASTEROID], # TODO: IS_VISITED_ASTEROID flag
			]
		"SpacecraftHUDs":
			control.column_master = _column_master
			control.has_headers = false
			control.rows = [
				["LABEL_SPACECRAFT", BodyFlags.IS_SPACECRAFT],
			]
		
		# SmallBodiesHUDs instance
		"AsteroidsHUDs":
			control.column_master = _column_master
			control.rows = [
				["LABEL_ASTEROIDS", ["NE", "MC", "IMB", "MMB", "OMB", "HI", "JT4", "JT5", "CE", "TN"]],
				["   " + tr("LABEL_NEAR_EARTH"), ["NE"]],
				["   " + tr("LABEL_MARS_CROSSERS"), ["MC"]],
				["   " + tr("LABEL_MAIN_BELT_INNER"), ["IMB"]],
				["   " + tr("LABEL_MAIN_BELT_MIDDLE"), ["MMB"]],
				["   " + tr("LABEL_MAIN_BELT_OUTER"), ["OMB"]],
				["   " + tr("LABEL_HILDAS"), ["HI"]],
				["   " + tr("LABEL_JUPITER_TROJANS"), ["JT4", "JT5"]],
				["   " + tr("LABEL_CENTAURS"), ["CE"]],
				["   " + tr("LABEL_TRANS_NEPTUNIAN"), ["TN"]],
			]


func _hide_all() -> void:
	_body_huds_state.hide_all()
	_sbg_huds_visibility.hide_all()


func _show_default() -> void:
	_view_manager.set_view("default", "all_huds", true, HUDS_VISIBILITY_STATE | HUDS_COLOR_STATE)


func _save_as_default() -> void:
	_view_manager.save_view("default", "all_huds", true, HUDS_VISIBILITY_STATE | HUDS_COLOR_STATE)


