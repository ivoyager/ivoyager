# global.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2019 Charlie Whitfield
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
#
# Singleton "Global".
# References to containers and non-container init values are set and safe to
# read before non-autoload objects are created (see ProjectBuilder). It's good
# practice to make local references to whatever you need near the top of your
# class and keep "Global" out of your non-init functions.

extends Node

# simulator state (broadcasts from Main)
signal project_builder_finished()
signal table_data_imported()
signal main_inited()
signal system_tree_built_or_loaded(is_new_game)
signal system_tree_ready(is_new_game)
signal about_to_start_simulator(is_new_game)
signal about_to_free_procedural_nodes()
signal simulator_exited()
signal game_save_started()
signal game_save_finished()
signal game_load_started()
signal game_load_finished()
signal run_state_changed(is_running)

# object broadcasts
signal setting_changed(setting, value)
signal gui_entered_tree(control)
signal gui_ready(control)
signal camera_ready(camera)
signal mouse_clicked_viewport_at(position, camera, is_left_click)
signal require_stop_requested(object)
signal allow_run_requested(object)

# camera/UI requests
signal move_camera_to_selection_requested(selection_item, viewpoint, rotations, instant_move)
signal move_camera_to_body_requested(body, viewpoint, rotations, instant_move)
signal open_main_menu_requested()
signal close_main_menu_requested()
signal show_hide_gui_requested(is_show)
signal toggle_show_hide_gui_requested()
signal options_requested()
signal hotkeys_requested()
signal credits_requested()
signal save_dialog_requested()
signal load_dialog_requested()
signal gui_refresh_requested()

# shared containers - keep tight write-control! (ideally, 1 class only)
var state := {} # see Main; keys include is_inited, is_running, etc.
var time_array := [] # [0] always time; GregorianTimekeeper [time, year, month, day]
var objects := {} # "small s singletons" populated by ProjectBuilder
var script_classes := {} # classes defined in ProjectBuilder dictionaries
var assets := {} # generic resources loaded from an assets directory
var settings := {} # maintained by SettingsManager
var table_data := {} # populated by TableReader
var themes := {} # see ThemeManager
var fonts := {} # see FontManager
var bodies := [] # indexed by body_id; maintained by Registrar
var bodies_by_name := {} # maintained by Registrar
var enums := {} # populated by EnumGlobalizer
var project := {} # available for extension "project"
var addon := {} # available for extension "addons"

# shared resources
var icon_quad_mesh := QuadMesh.new() # shared by HUDIcons; scaled by TreeManager
var globe_mesh := SphereMesh.new() # shared by spheroid Models

# project vars - modify at project init (see ProjectBuilder)
var project_name := "I, Voyager"
var enable_save_load := true
var save_file_extension := "IVoyagerSave"
var save_file_extension_name := "I Voyager Save"
var use_threads := true # false for debugging (saver_loader.gd has its own)
var dynamic_orbits := true # allows use of orbit element rates
var skip_asteroids := false
var asteroid_mag_cutoff_override := INF # != INF overrides asteroid_group_data.csv
var skip_splash_screen := false
var allow_dev_tools := true
var start_body_name := "PLANET_EARTH"
var start_time: float = -3608.0 # days from J2000 epoch (=2000-01-01 12:00)
var allow_time_reversal := true
var toggle_real_time_not_pause := false
var vertecies_per_orbit: int = 500
var max_camera_distance: float = 3e10 # km
var scale := 1e-9 # Godot length per km; check graphics at close/far extremes!
var gravitational_constant := 4.982174e-10 * scale * scale * scale # km^3/(days^2 x tonnes)
var obliquity_of_the_ecliptic := deg2rad(23.439)
var ecliptic_rotation := Math.get_x_rotation_matrix(obliquity_of_the_ecliptic)

var colors := { # user settable are in SettingsManager
	normal = Color.white,
	good = Color.green,
	warning = Color.yellow,
	danger = Color(1.0, 0.5, 0.5), # "red" is hard to see
	}

var planetary_system_dir := "res://ivoyager/data/solar_system"
var asteroid_binaries_dir := "res://ivoyager_assets/asteroid_binaries"
var models_dir := "res://ivoyager_assets/models"
var globe_wraps_dir := "res://ivoyager_assets/globe_wraps"
var rings_dir := "res://ivoyager_assets/planet_rings"
var texture_2d_dir := "res://ivoyager_assets/2d_bodies"
var hud_icons_dir := "res://ivoyager_assets/icons/hud_icons"

# Avoid preload to ivoyager_assets directory since that could be replaced
var asset_paths := {
	generic_moon_icon = "res://ivoyager_assets/icons/hud_icons/generic_o.icon.png",
	fallback_icon = "res://ivoyager_assets/icons/hud_icons/generic_o.icon.png",
	fallback_globe_wrap = "res://ivoyager_assets/fallbacks/grid_only_globe.jpg",
	fallback_texture_2d = "res://ivoyager_assets/fallbacks/grid_only_globe.256.png",
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
var ivoyager_version := "v0.0.2+ dev"
var is_modded := false # this is aspirational

const PERSIST_AS_PROCEDURAL_OBJECT := false
const PERSIST_PROPERTIES := ["project_version", "ivoyager_version", "is_modded"]

# *****************************************************************************

var _project_version := project_version
var _ivoyager_version := ivoyager_version

func project_init() -> void:
	prints(project_name, ivoyager_version, project_version)
	for asset_name in asset_paths:
		assets[asset_name] = load(asset_paths[asset_name])

func check_load_version() -> void:
	if _project_version != project_version or _ivoyager_version != ivoyager_version:
		print("WARNING! Loaded game was created with a different version...")
		prints("Present running version:      ", _ivoyager_version, _project_version)
		prints("Save created originally with: ", ivoyager_version, project_version)

func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS
