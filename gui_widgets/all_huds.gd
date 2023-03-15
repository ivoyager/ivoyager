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

# GUI container widget that holds all the HUD widgets.

const BodyFlags: Dictionary = IVEnums.BodyFlags

var default_view_name := "LABEL_CUSTOM1" # will increment if taken
var set_name := "AH"
var is_cached := true
var view_flags := IVView.ALL_HUDS
var reserved_view_names := [tr("BUTTON_PLANETS1"), tr("BUTTON_ASTEROIDS1"), tr("BUTTON_COLORS1")]

var _column_master: GridContainer

#onready var _view_defaults: IVViewDefaults = IVGlobal.program.ViewDefaults


func _enter_tree() -> void:
	connect("child_entered_tree", self, "_on_child_entered_tree")


func _ready() -> void:
	$"%ViewSaveButton".hint_tooltip = "HINT_SAVE_VISIBILITIES_AND_COLORS"
	$ViewSaveFlow.init($"%ViewSaveButton", default_view_name, set_name, is_cached,
			view_flags, view_flags, reserved_view_names)


func _on_child_entered_tree(control: Control) -> void:
	match control.name:
		
		# BodyHUDs instances
		"SunHUDs":
			# This grid controls all other grid's column widths.
			_column_master = control
			control.column0_en_width = 23
			control.columns_en_width = 6
			control.rows = [
				["STAR_SUN", BodyFlags.IS_STAR, false],
			]
			control.disable_orbits_rows.append(0) # no orbit for the Sun
		"PMOsHUDs":
			control.column_master = _column_master
			control.has_headers = false
			control.rows = [
				["LABEL_PLANETARY_MASS_OBJECTS", 0, false], # 0 causes all flags below to be set
				["LABEL_PLANETS", BodyFlags.IS_TRUE_PLANET, true],
				["LABEL_DWARF_PLANETS", BodyFlags.IS_DWARF_PLANET, true],
				["LABEL_MOONS_WIKI_PMO", BodyFlags.IS_PLANETARY_MASS_MOON, true],
			]
		"NonPMOMoonsHUDs":
			control.column_master = _column_master
			control.has_headers = false
			control.rows = [
				["LABEL_MOONS_NON_PMO", BodyFlags.IS_NON_PLANETARY_MASS_MOON, false],
			]
		"VisitedAsteroidsHUDs":
			control.column_master = _column_master
			control.has_headers = false
			control.rows = [
				["LABEL_ASTEROIDS_VISITED", BodyFlags.IS_ASTEROID, false], # TODO: IS_VISITED_ASTEROID flag
			]
		"SpacecraftHUDs":
			control.column_master = _column_master
			control.has_headers = false
			control.rows = [
				["LABEL_SPACECRAFT", BodyFlags.IS_SPACECRAFT, false],
			]
		
		# SBGHUDs instance
		"AsteroidsHUDs":
			control.column_master = _column_master
			control.rows = [
				["LABEL_ASTEROIDS",
						["NE", "MC", "IMB", "MMB", "OMB", "HI", "JT4", "JT5", "CE", "TN"], false],
				["SBG_NEAR_EARTH", ["NE"], true],
				["SBG_MARS_CROSSERS", ["MC"], true],
				["SBG_INNER_MAIN_BELT", ["IMB"], true],
				["SBG_MIDDLE_MAIN_BELT", ["MMB"], true],
				["SBG_OUTER_MAIN_BELT", ["OMB"], true],
				["SBG_HILDAS", ["HI"], true],
				["LABEL_JUPITER_TROJANS", ["JT4", "JT5"], true],
				["SBG_CENTAURS", ["CE"], true],
				["SBG_TRANS_NEPTUNE", ["TN"], true],
			]


