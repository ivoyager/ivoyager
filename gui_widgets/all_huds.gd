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
#	$"%HideAllButton".connect("pressed", self, "_hide_all")
#	$"%Planets1Button".connect("pressed", self, "_planets1")
#	$"%Asteroids1Button".connect("pressed", self, "_asteroids1")
#	$"%Colors1Button".connect("pressed", self, "_colors1")
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
				["LABEL_MOONS_NON_PMO", BodyFlags.IS_NON_PLANETARY_MASS_MOON],
			]
		"VisitedAsteroidsHUDs":
			control.column_master = _column_master
			control.has_headers = false
			control.rows = [
				["LABEL_ASTEROIDS_VISITED", BodyFlags.IS_ASTEROID], # TODO: IS_VISITED_ASTEROID flag
			]
		"SpacecraftHUDs":
			control.column_master = _column_master
			control.has_headers = false
			control.rows = [
				["LABEL_SPACECRAFT", BodyFlags.IS_SPACECRAFT],
			]
		
		# SBGHUDs instance
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


#func _hide_all() -> void:
#	_view_defaults.set_view("hide_all")
#
#
#func _planets1() -> void:
#	_view_defaults.set_view("planets1")
#
#
#func _asteroids1() -> void:
#	_view_defaults.set_view("asteroids1")
#
#
#func _colors1() -> void:
#	_view_defaults.set_view("default_colors")


