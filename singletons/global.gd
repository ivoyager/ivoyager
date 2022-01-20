# global.gd
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
extends Node

# Singleton "IVGlobal"
#
# IVGlobal init values should be modified by extension in their
# _extension_init() function and treated as immutable thereafter.
# Containers here (arrays and dictionaries) are never replaced, so it is safe
# to keep a local reference in class files.

const IVOYAGER_VERSION := "0.0.12"
const IVOYAGER_VERSION_YMD := 20220120
const DEBUG_BUILD := ""

# simulator state broadcasts
signal extentions_inited() # IVProjectBuilder; nothing else added yet
signal translations_imported() # IVTranslationImporter; useful for boot screen
signal project_objects_instantiated() # IVProjectBuilder; IVGlobal.program populated
signal project_inited() # IVProjectBuilder; after all _project_init() calls
signal project_nodes_added() # IVProjectBuilder; prog_nodes & gui_nodes added
signal project_builder_finished() # IVProjectBuilder; 1 frame after above
signal state_manager_inited()
signal world_environment_added() # on Main after I/O thread finishes (slow!)
signal about_to_build_system_tree()
signal system_tree_built_or_loaded(is_new_game) # still some I/O tasks to do!
signal system_tree_ready(is_new_game) # I/O thread has finished!
signal about_to_start_simulator(is_new_game) # delayed 1 frame after above
signal update_gui_requested() # send signals with GUI info now!
signal simulator_started()
signal paused_changed() # there is no SceneTree signal, so we hacked one here
signal about_to_free_procedural_nodes() # on exit and game load
signal about_to_stop_before_quit()
signal about_to_quit()
signal about_to_exit()
signal simulator_exited()
signal game_save_started()
signal game_save_finished()
signal game_load_started()
signal game_load_finished()
signal run_state_changed(is_running) # is_system_built and !SceneTree.paused
signal network_state_changed(network_state) # IVEnums.NetworkState

# other broadcasts
signal setting_changed(setting, value)
signal camera_ready(camera)

# requests for state change
signal sim_stop_required(who, network_sync_type, bypass_checks) # see IVStateManager
signal sim_run_allowed(who) # all objects requiring stop must allow!
signal change_pause_requested(is_toggle, is_pause) # 2nd arg ignored if is_toggle
signal quit_requested(force_quit) # force_quit bypasses dialog
signal exit_requested(force_exit) # force_exit bypasses dialog
signal save_requested(path, is_quick_save) # ["", false] will trigger dialog
signal load_requested(path, is_quick_load) # ["", false] will trigger dialog
signal save_quit_requested()

# requests for camera action
signal move_camera_to_selection_requested(selection_item, view_type, view_position,
		view_rotations, track_type, is_instant_move) # 1st arg can be null; all others optional
signal move_camera_to_body_requested(body, view_type, view_position, view_rotations,
		track_type, is_instant_move) # 1st arg can be null; all others optional

# requests for GUI
signal open_main_menu_requested()
signal close_main_menu_requested()
signal show_hide_gui_requested(is_toggle, is_show) # 2nd arg ignored if is_toggle
signal options_requested()
signal hotkeys_requested()
signal credits_requested()
signal help_requested() # hooked up in Planetarium
signal save_dialog_requested()
signal load_dialog_requested()
signal close_all_admin_popups_requested() # main menu, options, etc.
signal rich_text_popup_requested(header_text, bbcode_text)
signal open_wiki_requested(wiki_title)

# containers - write authority indicated; safe to keep container reference
var state := {} # see comments in IVStateManager; is_inited, is_running, etc.
var times := [] # IVTimekeeper [time (s, J2000), engine_time (s), solar_day (d)] (floats)
var date := [] # IVTimekeeper; Gregorian [year, month, day] (ints)
var clock := [] # IVTimekeeper; UT [hour, minute, second] (ints)
var program := {} # all objects instantiated by IVProjectBuilder 
var script_classes := {} # IVProjectBuilder; script classes (possibly overriden)
var assets := {} # AssetsInitializer; loaded from dynamic paths specified here
var settings := {} # IVSettingsManager
var table_rows := {} # IVTableImporter; row number for all row names
var wiki_titles := {} # IVTableImporter; en.wikipedia; TODO: non-en & internal
var themes := {} # IVThemeManager
var fonts := {} # IVFontManager
var bodies := [] # IVBodyRegistry; indexed by body_id
var bodies_by_name := {} # IVBodyRegistry; indexed by name (e.g., MOON_EUROPA)
var blocking_popups := [] # add popups that want & test for exclusivity
var project := {} # available for extension "project"
var addons := {} # available for extension "addons"
var extensions := [] # IVProjectBuilder [[name, version, version_ymd], ...]

# project vars - extensions modify via _extension_init(); see IVProjectBuilder
var project_name := ""
var project_version := "" # external project can set for gamesave debuging
var project_version_ymd := 0
var is_modded := false # this is aspirational
var enable_save_load := true
var save_file_extension := "IVoyagerSave"
var save_file_extension_name := "I Voyager Save"
var enums: Script = IVEnums # replace w/ extended static class
var use_threads := true # false helps for debugging
var dynamic_orbits := true # allows use of orbit element rates
var skip_asteroids := false
var asteroid_mag_cutoff_override := INF # overrides table cutoff if <INF
var skip_splash_screen := false
var disable_pause := false
var disable_exit := false
var disable_quit := false
var enable_wiki := false
var use_internal_wiki := false # skip data column en.wikipedia, etc., use wiki
var start_body_name := "PLANET_EARTH"
var start_time: float = 22.0 * IVUnits.YEAR # from J2000 epoch
var allow_real_world_time := false # get UT from user system seconds
var allow_time_reversal := false
var home_view_from_user_time_zone := false # get user latitude
var popops_can_stop_sim := true # false overrides stop_sim member in all popups
var limit_stops_in_multiplayer := true # overrides most stops
#var multiplayer_disables_pause := false # server can pause if false, no one if true
#var multiplayer_min_speed := 1
var allow_fullscreen_toggle := true
var auto_exposure_enabled := true # no effect in GLES2
var vertecies_per_orbit: int = 500
var max_camera_distance: float = 200.0 * IVUnits.AU
var obliquity_of_the_ecliptic := 23.439 * IVUnits.DEG
var ecliptic_rotation := IVMath.get_x_rotation_matrix(obliquity_of_the_ecliptic)
var unit_multipliers := IVUnits.MULTIPLIERS
var unit_functions := IVUnits.FUNCTIONS
var cache_dir := "user://cache"

var colors := { # user settable colors in program_refs/settings_manager.gd
	normal = Color.white,
	good = Color.green,
	warning = Color.yellow,
	danger = Color(1.0, 0.5, 0.5), # "red" is hard to see
}

var shared_resources := {
	globe_mesh = SphereMesh.new(), # all ellipsoid models
	# shaders
	orbit_ellipse_shader = preload("res://ivoyager/shaders/orbit_ellipse.shader"),
	orbit_points_shader = preload("res://ivoyager/shaders/orbit_points.shader"),
	orbit_points_lagrangian_shader = preload("res://ivoyager/shaders/orbit_points_lagrangian.shader"),
	# TODO: a rings shader! See: https://bjj.mmedia.is/data/s_rings
}

# Data table import
var table_import := {
	stars = "res://ivoyager/data/solar_system/stars.tsv",
	planets = "res://ivoyager/data/solar_system/planets.tsv",
	moons = "res://ivoyager/data/solar_system/moons.tsv",
	lights = "res://ivoyager/data/solar_system/lights.tsv",
	asteroid_groups = "res://ivoyager/data/solar_system/asteroid_groups.tsv",
	classes = "res://ivoyager/data/solar_system/classes.tsv",
	models = "res://ivoyager/data/solar_system/models.tsv",
	asset_adjustments = "res://ivoyager/data/solar_system/asset_adjustments.tsv",
}
var wiki_titles_import := ["res://ivoyager/data/solar_system/wiki_extras.tsv"]
var wikipedia_locales := ["en"] # add locales present in data tables

# We search for assets based on "file_prefix" and sometimes other name elements
# like "albedo". To build a model, IVModelBuilder first looks for an existing
# model in models_search (1st path element to last). Failing that, it will use
# a premade generic mesh (e.g., globe_mesh) and search for map textures in
# maps_search. If it can't find "<file_prifix>.albedo" in maps_search, it will
# use fallback_albedo_map.

var asset_replacement_dir := ""  # replaces all "ivoyager_assets" below

var models_search := ["res://ivoyager_assets/models"] # prepend to prioritize
var maps_search := ["res://ivoyager_assets/maps"]
var bodies_2d_search := ["res://ivoyager_assets/bodies_2d"]
var rings_search := ["res://ivoyager_assets/rings"]

var asset_paths := {
	asteroid_binaries_dir = "res://ivoyager_assets/asteroid_binaries",
	starmap_8k = "res://ivoyager_assets/starmaps/starmap_8k.jpg",
	starmap_16k = "res://ivoyager_assets/starmaps/starmap_16k.jpg",
}
var asset_paths_for_load := { # loaded into "assets" dict by IVAssetInitializer
	primary_font_data = "res://ivoyager_assets/fonts/Roboto-NotoSansSymbols-merged.ttf",
	fallback_albedo_map = "res://ivoyager_assets/fallbacks/blank_grid.jpg",
	fallback_body_2d = "res://ivoyager_assets/fallbacks/blank_grid_2d_globe.256.png",
	fallback_model = "res://ivoyager_assets/models/Phobos.4000_1_1000.glb", # NOT IMPLEMENTED!
}
var translations := [
	# Added here so extensions can modify. Note that IVTranslationImporter will
	# process text (eg, interpret \uXXXX) and report duplicate keys only if
	# import file has compress=false. For duplicates, 1st in array below will
	# be kept. So prepend this array if you want to override ivoyager text keys.
	"res://ivoyager/data/text/entities_text.en.translation",
	"res://ivoyager/data/text/gui_text.en.translation",
	"res://ivoyager/data/text/hints_text.en.translation",
	"res://ivoyager/data/text/long_text.en.translation",
]

var debug_log_path := "user://logs/debug.log" # modify or set "" to disable

# *****************************************************************************

# read-only!
var is_gles2: bool = ProjectSettings.get_setting("rendering/quality/driver/driver_name") == "GLES2"
var is_html5: bool = OS.has_feature('JavaScript')
var wiki: String # IVWikiInitializer sets; "wiki" (internal), "en.wikipedia", etc.
var debug_log: File # IVLogInitializer sets if debug build and debug_log_path


func _ready():
	prints("I, Voyager", IVOYAGER_VERSION, str(IVOYAGER_VERSION_YMD) + DEBUG_BUILD,
			"- https://www.ivoyager.dev")
