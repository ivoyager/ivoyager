# global.gd
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
# Singleton "Global".
# References to containers and non-container init values are set and safe to
# read before non-autoload objects are created (see ProjectBuilder). It's good
# practice to make local references to whatever you need near the top of your
# class and keep "Global" out of your non-init functions.

extends Node

# ProjectBuilder & Main broadcasts (program/simulator state)
signal project_builder_finished()
signal table_data_imported()
signal main_inited()
signal system_tree_built_or_loaded(is_new_game)
signal system_tree_ready(is_new_game)
signal about_to_start_simulator(is_new_game)
signal about_to_free_procedural_nodes() # on exit and game load
signal about_to_exit()
signal simulator_exited()
signal game_save_started()
signal game_save_finished()
signal game_load_started()
signal game_load_finished()
signal run_state_changed(is_running)
signal about_to_quit()

# other broadcasts
signal setting_changed(setting, value)
signal gui_entered_tree(control) # depreciate?
signal gui_ready(control) # depreciate?
signal environment_created(environment, is_world_env)
signal camera_ready(camera)
signal mouse_clicked_viewport_at(position, camera, is_left_click)

# sim state control
signal sim_stop_required(who) # see Main for external thread coordination
signal sim_run_allowed(who) # all requiring stop must allow!

# camera control
signal move_camera_to_selection_requested(selection_item, view_type, view_position,
		view_orientation, is_instant_move) # 1st arg can be null; all others optional
signal move_camera_to_body_requested(body, view_type, view_position, view_orientation,
		is_instant_move) # 1st arg can be null; all others optional

# GUI requests
signal open_main_menu_requested()
signal close_main_menu_requested()
signal show_hide_gui_requested(is_show)
signal toggle_show_hide_gui_requested()
signal options_requested()
signal hotkeys_requested()
signal credits_requested()
signal help_requested() # hooked up in Planetarium
signal save_dialog_requested()
signal load_dialog_requested()
signal gui_refresh_requested()
signal rich_text_popup_requested(header_text, bbcode_text)

# containers - managing object indicated; safe to keep container reference
var state := {} # Main; keys include is_inited, is_running, etc.
var times := [] # Timekeeper; [time (s, J2000), engine_time (s), UT1 (d)] (floats)
var date := [] # Timekeeper; Gregorian [year, month, day] (ints)
var clock := [] # Timekeeper; UT1 [hour, minute, second] (ints)
var program := {} # program nodes & refs populated by ProjectBuilder
var script_classes := {} # classes defined in ProjectBuilder dictionaries
var assets := {} # populated by this node project_init()
var settings := {} # SettingsManager
var table_rows := {} # TableImporter; row ints for ALL row keys
var table_row_dicts := {} # TableImporter; a row dict for each table
var wiki_titles := {} # TableImporter; Wiki url identifiers by item key
var themes := {} # ThemeManager
var fonts := {} # FontManager
var bodies := [] # Registrar; indexed by body_id
var bodies_by_name := {} # Registrar; indexed by name (e.g., MOON_EUROPA)
var project := {} # available for extension "project"
var addon := {} # available for extension "addons"

# project vars - set on extension_init(); see singletons/project_builder.gd
var project_name := "I, Voyager"
var enable_save_load := true
var save_file_extension := "IVoyagerSave"
var save_file_extension_name := "I Voyager Save"
var enums: Script = Enums # replace w/ extended static class
var use_threads := true # false for debugging (saver_loader.gd has its own)
var dynamic_orbits := true # allows use of orbit element rates
var skip_asteroids := false
var asteroid_mag_cutoff_override := INF # != INF overrides asteroid_group_data.csv
var skip_splash_screen := false
var disable_exit := false
var disable_quit := false
var enable_wiki := false
var allow_dev_tools := false
var start_body_name := "PLANET_EARTH"
var start_time: float = 20.0 * UnitDefs.YEAR # from J2000 epoch
var allow_real_world_time := false # UT1 from user system seconds
var allow_time_reversal := false
var disable_pause := false
var vertecies_per_orbit: int = 500
var max_camera_distance: float = 200.0 * UnitDefs.AU
var obliquity_of_the_ecliptic := 23.439 * UnitDefs.DEG
var ecliptic_rotation := Math.get_x_rotation_matrix(obliquity_of_the_ecliptic)
var unit_multipliers := UnitDefs.MULTIPLIERS
var unit_functions := UnitDefs.FUNCTIONS

var colors := { # user settable colors in program_refs/settings_manager.gd
	normal = Color.white,
	good = Color.green,
	warning = Color.yellow,
	danger = Color(1.0, 0.5, 0.5), # "red" is hard to see
}

var shared_resources := {
	icon_quad_mesh = QuadMesh.new(), # all HUD icons; scaled by TreeManager
	globe_mesh = SphereMesh.new(), # all ellipsoid models
	# shaders
	orbit_ellipse_shader = preload("res://ivoyager/shaders/orbit_ellipse.shader"),
	orbit_points_shader = preload("res://ivoyager/shaders/orbit_points.shader"),
	orbit_points_lagrangian_shader = preload("res://ivoyager/shaders/orbit_points_lagrangian.shader"),
	# TODO: a rings shader! See: https://bjj.mmedia.is/data/s_rings
}

# Data table import
var table_import := {
	stars = "res://ivoyager/data/solar_system/stars.csv",
	planets = "res://ivoyager/data/solar_system/planets.csv",
	moons = "res://ivoyager/data/solar_system/moons.csv",
	lights = "res://ivoyager/data/solar_system/lights.csv",
	asteroid_groups = "res://ivoyager/data/solar_system/asteroid_groups.csv",
	classes = "res://ivoyager/data/solar_system/classes.csv",
	models = "res://ivoyager/data/solar_system/models.csv",
}
var table_import_wiki_only := ["res://ivoyager/data/solar_system/wiki_extras.csv"]

# We search for assets based on "file_prefix" and sometimes other name elements
# like "albedo". To build a model, ModelBuilder first looks for an existing
# model in models_search (1st path element to last). Failing that, it will use
# a premade generic mesh (e.g., globe_mesh) and search for map textures in
# maps_search. If it can't find "<file_prifix>.albedo" in maps_search, it will
# use fallback_albedo_map.

var asset_replacement_dir := ""  # replaces all "ivoyager_assets" below

var models_search := ["res://ivoyager_assets/models"] # prepend to prioritize
var maps_search := ["res://ivoyager_assets/maps"]
var bodies_2d_search := ["res://ivoyager_assets/bodies_2d"]
var icons_search := ["res://ivoyager_assets/icons"]
var rings_search := ["res://ivoyager_assets/rings"]

var asset_paths := {
	asteroid_binaries_dir = "res://ivoyager_assets/asteroid_binaries",
	starmap_8k = "res://ivoyager_assets/starmaps/starmap_8k.jpg",
	starmap_16k = "res://ivoyager_assets/starmaps/starmap_16k.jpg",
}
var asset_paths_for_load := { # loaded into "assets" dict at project init
	primary_font_data = "res://ivoyager_assets/fonts/Roboto-Regular.ttf",
	generic_moon_icon = "res://ivoyager_assets/icons/generic_o.icon.png",
	fallback_icon = "res://ivoyager_assets/icons/generic_o.icon.png",
	fallback_albedo_map = "res://ivoyager_assets/fallbacks/blank_grid.jpg",
	fallback_body_2d = "res://ivoyager_assets/fallbacks/blank_grid_2d_globe.256.png",
	fallback_model = "res://ivoyager_assets/models/Phobos.4000_1_1000.glb", # NOT IMPLEMENTED!
	fallback_star_slice = "res://ivoyager_assets/bodies_2d/Sun_slice.256.png",
}

# ******************************* PERSISTED ***********************************

var project_version := "" # external project can set for save debuging
var ivoyager_version := "0.0.6-alpha dev"
var is_modded := false # this is aspirational

const PERSIST_AS_PROCEDURAL_OBJECT := false
const PERSIST_PROPERTIES := ["project_version", "ivoyager_version", "is_modded"]

# *****************************************************************************

# these may differ after game load; Main uses for version warning
var current_project_version := project_version
var current_ivoyager_version := ivoyager_version

# private
var _asset_path_arrays := [models_search, maps_search, bodies_2d_search, icons_search,
	rings_search]
var _asset_path_dicts := [asset_paths, asset_paths_for_load]

func project_init() -> void:
	# 1st, so assets are present at other class's project_init()
	prints(project_name, ivoyager_version, project_version)
	_modify_asset_paths()
	_load_assets()

func _modify_asset_paths() -> void:
	if !asset_replacement_dir:
		return
	for array in _asset_path_arrays:
		var index := 0
		var array_size: int = array.size()
		while index < array_size:
			var old_path: String = array[index]
			var new_path := old_path.replace("ivoyager_assets", asset_replacement_dir)
			array[index] = new_path
			index += 1
	for dict in _asset_path_dicts:
		for asset_name in dict:
			var old_path: String = dict[asset_name]
			var new_path := old_path.replace("ivoyager_assets", asset_replacement_dir)
			dict[asset_name] = new_path

func _load_assets() -> void:
	for asset_name in asset_paths_for_load:
		var path: String = asset_paths_for_load[asset_name]
		assets[asset_name] = load(path)

func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS # inherited by all "program nodes"
