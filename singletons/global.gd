# global.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2019 Charlie Whitfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# *****************************************************************************
#
# Singleton "Global".
# References to containers and non-container init values are set and safe to
# read before non-autoload objects are created (see ProjectBuilder). It's good
# practice to make local references to whatever you need near the top of your
# class and keep "Global" out of your non-init functions.

extends Node

# simulator state (Main broadcasts)
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
signal run_gui_entered_tree(control)
signal run_gui_ready(control)
signal camera_ready(camera)
signal mouse_clicked_viewport_at(position, camera, is_left_click)
signal require_stop_requested(object)
signal allow_run_requested(object)

# camera/UI requests
signal move_camera_to_selection_requested(selection_item, viewpoint, instant_move)
signal move_camera_to_body_requested(body, viewpoint, instant_move)
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

# ivoyager constants
const SCALE := 1e-9 # Godot length units per km
const G := 4.982174e-10 * SCALE * SCALE * SCALE # km^3/(days^2 x tonnes)

# shared containers & resources - do not modify! (except by maintaining class)
var state := {} # see Main; keys include is_inited, is_running, etc.
var time_array := [] # [0] always time; GregorianTimekeeper [time, year, month, day]
var objects := {} # "small s singletons" populated by ProjectBuilder
var script_classes := {} # classes defined in ProjectBuilder dictionaries
var settings := {} # maintained by SettingsManager
var table_data := {} # populated by TableReader
var themes := {} # see ThemeManager
var fonts := {} # see FontManager
var bodies := [] # indexed by body_id; maintained by Registrar
var bodies_by_name := {} # maintained by Registrar
var enums := {} # populated by EnumGlobalizer
var project := {} # available for extension projects
var icon_quad_mesh := QuadMesh.new() # shared by HUDIcons; scaled by TreeManager
var globe_mesh := SphereMesh.new() # shared by spheroid Models

# project vars - modify at project init; see ProjectBuilder
var enable_save_load := true
var save_file_extension := "IVoyagerSave"
var save_file_extension_name := "I Voyager Save"
var use_threads := true # false can help debugging
var dynamic_orbits := true # allows use of orbit element rates
var skip_asteroids := false
var skip_splash_screen := false
var allow_dev_tools := true # AsteroidImporter WikiBot, etc.
var start_body_name := "PLANET_EARTH"
var start_time := 0.0 # in days from J2000 epoch (01/01/2000 noon)
var allow_time_reversal := true
var vertecies_per_orbit := 500
var max_camera_distance := 3e10 # km
var obliquity_of_the_ecliptic := deg2rad(23.439)
var ecliptic_rotation := Math.get_x_rotation_matrix(obliquity_of_the_ecliptic)
var normal_text_color := Color.white
var good_text_color := Color.green
var warning_text_color := Color.yellow
var danger_text_color := Color(1.0, 0.5, 0.5)
var planetary_system_dir := "res://ivoyager/data/solar_system"
var asteroid_binaries_dir := "res://ivoyager_assets/asteroid_binaries"
var models_dir := "res://ivoyager_assets/models"
var globe_wraps_dir := "res://ivoyager_assets/globe_wraps"
var rings_dir := "res://ivoyager_assets/planet_rings"
var texture_2d_dir := "res://ivoyager_assets/2d_bodies"
var hud_icons_dir := "res://ivoyager_assets/icons/orbiting_bodies"
var primary_font_data: DynamicFontData = preload("res://ivoyager_assets/fonts/Roboto-Regular.ttf")
var generic_moon_icon: Texture = preload("res://ivoyager_assets/icons/orbiting_bodies/generic_o.icon.png")
var fallback_globe_wrap: Texture = preload("res://ivoyager_assets/fallbacks/grid_only_globe.jpg")
var fallback_texture_2d: Texture = preload("res://ivoyager_assets/fallbacks/grid_only_globe.256.png")
var fallback_star_slice: Texture = preload("res://ivoyager_assets/2d_bodies/Sun_slice.256.png")
var fallback_icon: Texture = preload("res://ivoyager_assets/icons/orbiting_bodies/generic_o.icon.png")
var orbit_ellipse_shader: Shader = preload("res://ivoyager/shaders/orbit_ellipse.shader")
var orbit_points_shader: Shader = preload("res://ivoyager/shaders/orbit_points.shader")
var orbit_points_lagrangian_shader: Shader = preload("res://ivoyager/shaders/orbit_points_lagrangian.shader")
# TODO: rings_shader!


# *****************************************************************************
# stuff below is needed for child nodes of this node

const PERSIST_AS_PROCEDURAL_OBJECT := false

func _ready():
	pause_mode = PAUSE_MODE_PROCESS


