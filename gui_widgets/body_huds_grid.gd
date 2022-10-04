# body_huds_grid.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2022 Charlie Whitfield
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
extends GridContainer

# GUI widget. 

const IS_STAR_OR_TRUE_PLANET := IVEnums.BodyFlags.IS_STAR | IVEnums.BodyFlags.IS_TRUE_PLANET
const IS_DWARF_PLANET := IVEnums.BodyFlags.IS_DWARF_PLANET
const IS_MOON := IVEnums.BodyFlags.IS_MOON
const IS_ASTEROID := IVEnums.BodyFlags.IS_ASTEROID
const IS_SPACECRAFT := IVEnums.BodyFlags.IS_SPACECRAFT


onready var _huds_manager: IVHUDsManager = IVGlobal.program.HUDsManager
onready var _all_visible_flags := _huds_manager.all_visible_flags
onready var _all_orbits: CheckBox = $AllOrbits
onready var _all_names: CheckBox = $AllNames
onready var _all_symbols: CheckBox = $AllSymbols
onready var _sun_and_planets_orbits: CheckBox = $SunAndPlanetsOrbits
onready var _sun_and_planets_names: CheckBox = $SunAndPlanetsNames
onready var _sun_and_planets_symbols: CheckBox = $SunAndPlanetsSymbols
onready var _dwarf_planets_orbits: CheckBox = $DwarfPlanetsOrbits
onready var _dwarf_planets_names: CheckBox = $DwarfPlanetsNames
onready var _dwarf_planets_symbols: CheckBox = $DwarfPlanetsSymbols
onready var _moons_orbits: CheckBox = $MoonsOrbits
onready var _moons_names: CheckBox = $MoonsNames
onready var _moons_symbols: CheckBox = $MoonsSymbols
onready var _asteroids_orbits: CheckBox = $AsteroidsOrbits
onready var _asteroids_names: CheckBox = $AsteroidsNames
onready var _asteroids_symbols: CheckBox = $AsteroidsSymbols
onready var _spacecraft_orbits: CheckBox = $SpacecraftOrbits
onready var _spacecraft_names: CheckBox = $SpacecraftNames
onready var _spacecraft_symbols: CheckBox = $SpacecraftSymbols


func _ready() -> void:
	_huds_manager.connect("visibility_changed", self, "_update_ckbxs")
	_all_orbits.connect("pressed", self, "_show_hide_orbits",
			[_all_orbits, _all_visible_flags])
	_all_names.connect("pressed", self, "_show_hide_names",
			[_all_names, _all_visible_flags])
	_all_symbols.connect("pressed", self, "_show_hide_symbols",
			[_all_symbols, _all_visible_flags])
	_sun_and_planets_orbits.connect("pressed", self, "_show_hide_orbits",
			[_sun_and_planets_orbits, IS_STAR_OR_TRUE_PLANET])
	_sun_and_planets_names.connect("pressed", self, "_show_hide_names",
			[_sun_and_planets_names, IS_STAR_OR_TRUE_PLANET])
	_sun_and_planets_symbols.connect("pressed", self, "_show_hide_symbols",
			[_sun_and_planets_symbols, IS_STAR_OR_TRUE_PLANET])
	_dwarf_planets_orbits.connect("pressed", self, "_show_hide_orbits",
			[_dwarf_planets_orbits, IS_DWARF_PLANET])
	_dwarf_planets_names.connect("pressed", self, "_show_hide_names",
			[_dwarf_planets_names, IS_DWARF_PLANET])
	_dwarf_planets_symbols.connect("pressed", self, "_show_hide_symbols",
			[_dwarf_planets_symbols, IS_DWARF_PLANET])
	_moons_orbits.connect("pressed", self, "_show_hide_orbits", [_moons_orbits, IS_MOON])
	_moons_names.connect("pressed", self, "_show_hide_names", [_moons_names, IS_MOON])
	_moons_symbols.connect("pressed", self, "_show_hide_symbols", [_moons_symbols, IS_MOON])
	_asteroids_orbits.connect("pressed", self, "_show_hide_orbits", [_asteroids_orbits, IS_ASTEROID])
	_asteroids_names.connect("pressed", self, "_show_hide_names", [_asteroids_names, IS_ASTEROID])
	_asteroids_symbols.connect("pressed", self, "_show_hide_symbols", [_asteroids_symbols, IS_ASTEROID])
	_spacecraft_orbits.connect("pressed", self, "_show_hide_orbits", [_spacecraft_orbits, IS_SPACECRAFT])
	_spacecraft_names.connect("pressed", self, "_show_hide_names", [_spacecraft_names, IS_SPACECRAFT])
	_spacecraft_symbols.connect("pressed", self, "_show_hide_symbols", [_spacecraft_symbols, IS_SPACECRAFT])



func _show_hide_orbits(ckbx: CheckBox, flags: int) -> void:
	_huds_manager.set_orbit_visibility(flags, ckbx.pressed)


func _show_hide_names(ckbx: CheckBox, flags: int) -> void:
	_huds_manager.set_name_visibility(flags, ckbx.pressed)


func _show_hide_symbols(ckbx: CheckBox, flags: int) -> void:
	_huds_manager.set_symbol_visibility(flags, ckbx.pressed)


func _update_ckbxs() -> void:
	_all_orbits.pressed = _huds_manager.is_orbit_visible(_all_visible_flags, true)
	_all_names.pressed = _huds_manager.is_name_visible(_all_visible_flags, true)
	_all_symbols.pressed = _huds_manager.is_symbol_visible(_all_visible_flags, true)
	_sun_and_planets_orbits.pressed = _huds_manager.is_orbit_visible(IS_STAR_OR_TRUE_PLANET, true)
	_sun_and_planets_names.pressed = _huds_manager.is_name_visible(IS_STAR_OR_TRUE_PLANET, true)
	_sun_and_planets_symbols.pressed = _huds_manager.is_symbol_visible(IS_STAR_OR_TRUE_PLANET, true)
	_dwarf_planets_orbits.pressed = _huds_manager.is_orbit_visible(IS_DWARF_PLANET)
	_dwarf_planets_names.pressed = _huds_manager.is_name_visible(IS_DWARF_PLANET)
	_dwarf_planets_symbols.pressed = _huds_manager.is_symbol_visible(IS_DWARF_PLANET)
	_moons_orbits.pressed = _huds_manager.is_orbit_visible(IS_MOON)
	_moons_names.pressed = _huds_manager.is_name_visible(IS_MOON)
	_moons_symbols.pressed = _huds_manager.is_symbol_visible(IS_MOON)
	_asteroids_orbits.pressed = _huds_manager.is_orbit_visible(IS_ASTEROID)
	_asteroids_names.pressed = _huds_manager.is_name_visible(IS_ASTEROID)
	_asteroids_symbols.pressed = _huds_manager.is_symbol_visible(IS_ASTEROID)
	_spacecraft_orbits.pressed = _huds_manager.is_orbit_visible(IS_SPACECRAFT)
	_spacecraft_names.pressed = _huds_manager.is_name_visible(IS_SPACECRAFT)
	_spacecraft_symbols.pressed = _huds_manager.is_symbol_visible(IS_SPACECRAFT)

