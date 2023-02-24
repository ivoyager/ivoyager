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

var _column_master: GridContainer

onready var _body_huds_visibility: IVBodyHUDsVisibility = IVGlobal.program.BodyHUDsVisibility
onready var _sbg_huds_visibility: IVSBGHUDsVisibility = IVGlobal.program.SBGHUDsVisibility


func _enter_tree() -> void:
	connect("child_entered_tree", self, "_on_child_entered_tree")


func _ready() -> void:
	$"%HideAllButton".connect("pressed", self, "_hide_all")
	$"%ShowDefaultButton".connect("pressed", self, "_show_default")


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
	pass


func _show_default() -> void:
	pass


func _save_as_default() -> void:
	pass


