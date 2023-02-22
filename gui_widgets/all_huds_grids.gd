# all_huds_grids.gd
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
class_name IVAllHUDsGrids
extends VBoxContainer

# GUI widget that holds all the HUD visibility widgets.

const BodyFlags: Dictionary = IVEnums.BodyFlags

var _column_master: GridContainer


func _enter_tree() -> void:
	connect("child_entered_tree", self, "_on_child_entered_tree")


func _on_child_entered_tree(control: Control) -> void:
	match control.name:
		
		# BodyHUDsGrid instances
		"SunGrid":
			_column_master = control
			control.column0_en_width = 25
			control.ckbx_rows = [
				["LABEL_SUN", BodyFlags.IS_STAR],
			]
			control.skip_ckbx_indexes.append(7) # skips the orbit ckbx
		"PMOsGrid":
			control.column_master = _column_master
			control.has_headers = false
			control.ckbx_rows = [
				["LABEL_PLANETARY_MASS_OBJECTS", 0], # 0 causes all flags below to be set
				["   " + tr("LABEL_PLANETS"), BodyFlags.IS_TRUE_PLANET],
				["   " + tr("LABEL_DWARF_PLANETS"), BodyFlags.IS_DWARF_PLANET],
				["   " + tr("LABEL_MOONS"), BodyFlags.IS_PLANETARY_MASS_MOON],
			]
		"NonPMOMoonsGrid":
			control.column_master = _column_master
			control.has_headers = false
			control.ckbx_rows = [
				["LABEL_NON_PMO_MOONS", BodyFlags.IS_NON_PLANETARY_MASS_MOON],
			]
		"VisitedAsteroidsGrid":
			control.column_master = _column_master
			control.has_headers = false
			control.ckbx_rows = [
				["LABEL_VISITED_ASTEROIDS", BodyFlags.IS_ASTEROID], # TODO: IS_VISITED_ASTEROID flag
			]
		"SpacecraftGrid":
			control.column_master = _column_master
			control.has_headers = false
			control.ckbx_rows = [
				["LABEL_SPACECRAFT", BodyFlags.IS_SPACECRAFT],
			]

		# SmallBodiesHUDs instance
		"AsteroidsHUDs":
			control.column_master = _column_master
			control.column0_en_width = 0



