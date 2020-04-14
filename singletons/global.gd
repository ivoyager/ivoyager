# global.gd
# This file is part of I, Voyager
# https://ivoyager.dev
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

# sim state broadcasts (from ProjectBuilder & Main)
signal project_builder_finished()
signal table_data_imported()
signal main_inited()
signal system_tree_built_or_loaded(is_new_game)
signal system_tree_ready(is_new_game)
signal about_to_start_simulator(is_new_game)
signal about_to_free_procedural_nodes()
signal about_to_exit()
signal simulator_exited()
signal game_save_started()
signal game_save_finished()
signal game_load_started()
signal game_load_finished()
signal run_state_changed(is_running)
signal about_to_quit()

# other object broadcasts
signal setting_changed(setting, value)
signal gui_entered_tree(control)
signal gui_ready(control)
signal camera_ready(camera)
signal mouse_clicked_viewport_at(position, camera, is_left_click)
signal about_to_add_environment(environment, is_world_env)

# sim state external control
signal sim_stop_required(who) # see Main for external thread coordination
signal sim_run_allowed(who)

# camera/UI requests
signal move_camera_to_selection_requested(selection_item, view_type, spherical_position,
		camera_rotation, is_instant_move) # 1st arg can be null; all others optional
signal move_camera_to_body_requested(body, view_type, spherical_position, camera_rotation,
		is_instant_move) # 1st arg can be null; all others optional
signal open_main_menu_requested()
signal close_main_menu_requested()
signal show_hide_gui_requested(is_show)
signal toggle_show_hide_gui_requested()
signal options_requested()
signal hotkeys_requested()
signal credits_requested()
signal rich_text_popup_requested(header_text, bbcode_text)
signal save_dialog_requested()
signal load_dialog_requested()
signal gui_refresh_requested()

# containers - managing object is indicated; safe to keep container reference
var state := {} # Main; keys include is_inited, is_running, etc.
var time_date := [] # Timekeeper [time, year, quarter, month, day] int except time
var program := {} # program nodes & refs populated by ProjectBuilder
var script_classes := {} # classes defined in ProjectBuilder dictionaries
var assets := {} # populated by this node project_init()
var settings := {} # SettingsManager
var tables := {} # TableReader; table data (arrays of arrays) & field dicts
var table_types := {} # TableReader; enum-like row keys (all) & table key dicts
var wiki_titles := {} # TableReader; Wiki url identifiers by item key
var themes := {} # ThemeManager
var fonts := {} # FontManager
var bodies := [] # Registrar; indexed by body_id
var bodies_by_name := {} # Registrar
var project := {} # available for extension "project"
var addon := {} # available for extension "addons"

# shared resources
var icon_quad_mesh := QuadMesh.new() # shared by HUDIcons; scaled by TreeManager
var globe_mesh := SphereMesh.new() # shared by ellipsoidal Models

# project vars - modify at project init (see ProjectBuilder)
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
var allow_dev_tools := false
var start_body_name := "PLANET_EARTH"
var start_time: float = 20.0 * UnitDefs.YEAR # from J2000 epoch
var allow_time_reversal := true
var toggle_real_time_not_pause := false
var vertecies_per_orbit: int = 500
var max_camera_distance: float = 3e10 * UnitDefs.KM
var gravitational_constant := UnitDefs.conv(0.0667430, "km^3/(kg s^2)")
var obliquity_of_the_ecliptic := 23.439 * UnitDefs.DEG
var ecliptic_rotation := Math.get_x_rotation_matrix(obliquity_of_the_ecliptic)

var colors := { # user settable are in SettingsManager
	normal = Color.white,
	good = Color.green,
	warning = Color.yellow,
	danger = Color(1.0, 0.5, 0.5), # "red" is hard to see
}

var planetary_system_dir := "res://ivoyager/data/solar_system"

# The ivoyager_assets directory may be replaced by project or in specific
# deployments. E.g., we set asset_replacement_dir = "ivoyager_assets_web" for
# web deployment of the Planetarium.
var asset_replacement_dir := "" 
var asset_paths := {
	asteroid_binaries_dir = "res://ivoyager_assets/asteroid_binaries",
	models_dir = "res://ivoyager_assets/models",
	globe_wraps_dir = "res://ivoyager_assets/globe_wraps",
	rings_dir = "res://ivoyager_assets/rings",
	texture_2d_dir = "res://ivoyager_assets/2d_bodies",
	hud_icons_dir = "res://ivoyager_assets/icons/hud_icons",
}
var asset_paths_for_load := { # project_init() will load these into assets
	starfield = "res://ivoyager_assets/starfields/starmap_16k.jpg",
	generic_moon_icon = "res://ivoyager_assets/icons/hud_icons/generic_o.icon.png",
	fallback_icon = "res://ivoyager_assets/icons/hud_icons/generic_o.icon.png",
	fallback_globe_wrap = "res://ivoyager_assets/fallbacks/blank_grid.jpg",
	fallback_texture_2d = "res://ivoyager_assets/fallbacks/blank_grid_2d_globe.256.png",
	fallback_model = "res://ivoyager_assets/models/Phobos.4000_1_1000.glb",
	fallback_star_slice = "res://ivoyager_assets/2d_bodies/Sun_slice.256.png",
	primary_font_data = "res://ivoyager_assets/fonts/Roboto-Regular.ttf",
}

var shaders := {
	orbit_ellipse = preload("res://ivoyager/shaders/orbit_ellipse.shader"),
	orbit_points = preload("res://ivoyager/shaders/orbit_points.shader"),
	orbit_points_lagrangian = preload("res://ivoyager/shaders/orbit_points_lagrangian.shader"),
	# TODO: a rings shader! See: https://bjj.mmedia.is/data/s_rings
}

# ******************************* PERSISTED ***********************************

var project_version := "" # external project can set for save debuging
var ivoyager_version := "0.0.5"
var is_modded := false # this is aspirational

const PERSIST_AS_PROCEDURAL_OBJECT := false
const PERSIST_PROPERTIES := ["project_version", "ivoyager_version", "is_modded"]

# *****************************************************************************

# these may differ after game load; see check_load_version()
var _project_version := project_version
var _ivoyager_version := ivoyager_version

func project_init() -> void:
	# This is the first of all project_init() calls.
	prints(project_name, ivoyager_version, project_version)
	if asset_replacement_dir:
		for dict in [asset_paths, asset_paths_for_load]:
			for asset_name in dict:
				var old_path: String = dict[asset_name]
				var new_path := old_path.replace("ivoyager_assets", asset_replacement_dir)
				dict[asset_name] = new_path
	for asset_name in asset_paths_for_load:
		var path: String = asset_paths_for_load[asset_name]
		assets[asset_name] = load(path)

func check_load_version() -> void:
	if _project_version != project_version or _ivoyager_version != ivoyager_version:
		print("WARNING! Loaded game was created with a different version...")
		prints("Present running version: ", _ivoyager_version, _project_version)
		prints("Loaded game started as:  ", ivoyager_version, project_version)

func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS # inherited by all "program nodes"
