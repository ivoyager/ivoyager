# global.gd
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
extends Node

# Instance global "IVGlobal"
#
# Project init values should be modified by extension in _extension_init() and
# treated as immutable thereafter.
#
# Containers (arrays and dictionaries) are never replaced, so it is safe and
# good practice to keep a local reference in class files.

const IVOYAGER_VERSION := "0.0.16"
const IVOYAGER_BUILD := "" # hotfix or debug build
const IVOYAGER_STATE := "" # 'dev', 'alpha', 'beta', 'rc', ''
const IVOYAGER_YMD := 20230925


# simulator state broadcasts
signal extentions_inited() # IVProjectBuilder; nothing else added yet
signal translations_imported() # IVTranslationImporter; useful for boot screen
signal data_tables_imported() # IVTableImporter
signal initializers_inited()
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
signal pause_changed(is_paused)
signal user_pause_changed(is_paused) # ignores pause from sim stop
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
signal move_camera_requested(selection, camera_flags, view_position, view_rotations,
		is_instant_move) # 1st arg can be null; all others optional

# requests for GUI
signal open_main_menu_requested()
signal close_main_menu_requested()
signal confirmation_requested(text, confirm_action, stop_sim, title_txt, ok_txt, cancel_txt)
signal options_requested()
signal hotkeys_requested()
signal credits_requested()
signal help_requested() # hooked up in Planetarium
signal save_dialog_requested()
signal load_dialog_requested()
signal close_all_admin_popups_requested() # main menu, options, etc.
signal rich_text_popup_requested(header_text, text)
signal open_wiki_requested(wiki_title)
signal show_hide_gui_requested(is_toggle, is_show) # 2nd arg ignored if is_toggle


# containers - write authority indicated; safe to localize container reference
var state := {} # IVStateManager & IVSaveManager; is_inited, is_running, etc.
var times: Array[float] = [] # IVTimekeeper [time (s, J2000), engine_time (s), solar_day (d)]
var date: Array[int] = [] # IVTimekeeper; Gregorian [year, month, day]
var clock: Array[int] = [] # IVTimekeeper; UT [hour, minute, second]
var program := {} # IVProjectBuilder instantiated objects (base or override classes)
var procedural_classes := {} # IVProjectBuilder defined script classes (base or override)
var assets := {} # AssetsInitializer loads from dynamic paths specified below
var settings := {} # IVSettingsManager
var themes := {} # IVThemeManager
var fonts := {} # IVFontManager
var bodies := {} # IVBody instances add/remove themselves; indexed by name
var world_targeting := [] # IVWorldControl & others; optimized data for 3D world selection
var top_bodies: Array[Node3D] = [] # IVBody instances add/remove themselves; just STAR_SUN for us
var selections := {} # IVSelectionManager(s)
var blocking_windows: Array[Window] = [] # add Windows that want & test for exclusivity
var project := {} # available for extension "project"
var addons := {} # available for extension "addons"
var extensions: Array[Array] = [] # IVProjectBuilder [[name, version, build, state, ymd], ...]

# project vars - extensions modify via _extension_init(); see IVProjectBuilder
var project_name := ""
var project_version := "" # external project can set for gamesave debuging
var project_build := ""
var project_state := ""
var project_ymd := 0
var verbose := false # prints state broadcast signals and whatever else we add
var is_modded := false # this is aspirational
var enable_save_load := true
var save_file_extension := "IVoyagerSave"
var save_file_extension_name := "I Voyager Save"
var use_threads := true # false helps for debugging
var dynamic_orbits := true # allows use of orbit element rates
var sbg_mag_cutoff_override := INF # overrides small_bodies_group.tsv cutoff if <INF
var skip_splash_screen := true
var pause_only_stops_time := false # if true, Universe & TopGUI are set to process
var disable_pause := false
var disable_exit := false
var disable_quit := false

var enable_wiki := false
var enable_precisions := false
var use_internal_wiki := false # FIXME: WikiManager doesn't do anything yet

var start_time: float = 22.0 * IVUnits.YEAR # from J2000 epoch
var allow_time_setting := false
var allow_time_reversal := false
var popops_can_stop_sim := true # false overrides stop_sim member in all popups
var limit_stops_in_multiplayer := true # overrides most stops
#var multiplayer_disables_pause := false # server can pause if false, no one if true
#var multiplayer_min_speed := 1
var allow_fullscreen_toggle := true
var auto_exposure_enabled := true
var vertecies_per_orbit: int = 500
var vertecies_per_orbit_low_res: int = 100 # for small bodies like asteroids
var max_camera_distance: float = 5e3 * IVUnits.AU
var obliquity_of_the_ecliptic := 23.439 * IVUnits.DEG
var ecliptic_rotation := IVMath.get_x_rotation_matrix(obliquity_of_the_ecliptic)
var cache_dir := "user://cache"

# theses could be modified during gameplay
var home_name := "PLANET_EARTH"
var home_longitude := 0.0
var home_latitude := 0.0


var colors := { # user settable colors in program_refs/settings_manager.gd
	normal = Color.WHITE,
	good = Color.GREEN,
	warning = Color.YELLOW,
	danger = Color(1.0, 0.5, 0.5), # "red" is hard to read
}

var shared_resources := {
	# Values can be resource paths or preloaded resources. IVSharedInitializer
	# loads any paths at project init.
	
	# shaders
	
	
	&"points_id_shader" : preload("res://ivoyager/shaders/points.id.gdshader"),
	&"points_l4l5_id_shader" : preload("res://ivoyager/shaders/points.l4l5.id.gdshader"),
	
	
	&"orbit_id_shader" : preload("res://ivoyager/shaders/orbit.id.gdshader"),
	&"orbits_id_shader" : preload("res://ivoyager/shaders/orbits.id.gdshader"),
	&"rings_shader" : preload("res://ivoyager/shaders/rings.gdshader"),
	# additional items are constructed & added by initializers/shared_initializer.gd
}

var postprocess_tables: Array[String] = [
	"res://ivoyager/data/solar_system/asset_adjustments.tsv",
	"res://ivoyager/data/solar_system/asteroids.tsv",
	"res://ivoyager/data/solar_system/body_classes.tsv",
	"res://ivoyager/data/solar_system/omni_lights.tsv",
	"res://ivoyager/data/solar_system/models.tsv",
	"res://ivoyager/data/solar_system/moons.tsv",
	"res://ivoyager/data/solar_system/planets.tsv",
	"res://ivoyager/data/solar_system/small_bodies_groups.tsv",
	"res://ivoyager/data/solar_system/spacecrafts.tsv",
	"res://ivoyager/data/solar_system/stars.tsv",
	"res://ivoyager/data/solar_system/visual_groups.tsv",
	"res://ivoyager/data/solar_system/wiki_extras.tsv"
]

var table_project_enums := [
	IVEnums.SBGClass,
	IVEnums.Confidence,
	IVEnums.BodyFlags,
]

var wikipedia_locales: Array[String] = ["en"] # add locales present in data tables

var body_tables: Array[String] = ["stars", "planets", "asteroids", "moons", "spacecrafts"] # ordered!

# We search for assets based on "file_prefix" and sometimes other name elements
# like "albedo". To build a model, IVModelManager first looks for an existing
# model in models_search (1st path element to last). Failing that, it will use
# the generic IVSpheroidModel and search for map textures in maps_search. If it
# can't find "<file_prifix>.albedo" in maps_search, it will use fallback_albedo_map.

var asset_replacement_dir := ""  # replaces all "ivoyager_assets" below

var models_search: Array[String] = ["res://ivoyager_assets/models"] # prepend to prioritize
var maps_search: Array[String] = ["res://ivoyager_assets/maps"]
var bodies_2d_search: Array[String] = ["res://ivoyager_assets/bodies_2d"]
var rings_search: Array[String] = ["res://ivoyager_assets/rings"]

var asset_paths := {
	starmap_8k = "res://ivoyager_assets/starmaps/starmap_8k.jpg",
	starmap_16k = "res://ivoyager_assets/starmaps/starmap_16k.jpg",
}
var asset_paths_for_load := { # loaded into "assets" dict by IVAssetInitializer
	primary_font = "res://ivoyager_assets/fonts/Roboto-NotoSansSymbols-merged.ttf",
	fallback_albedo_map = "res://ivoyager_assets/fallbacks/blank_grid.jpg",
	fallback_body_2d = "res://ivoyager_assets/fallbacks/blank_grid_2d_globe.256.png",
#	fallback_model = "res://ivoyager_assets/models/phobos/Phobos.1_1000.glb", # implement in 0.0.14
}
var translations: Array[String] = [
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
var is_html5: bool = OS.has_feature('JavaScript')
var wiki: String # IVWikiInitializer sets; "wiki" (internal), "en.wikipedia", etc.
var debug_log: FileAccess # IVLogInitializer sets if debug build and debug_log_path


func _init() -> void:
	print("I, Voyager %s%s-%s %s - https://www.ivoyager.dev"
			% [IVOYAGER_VERSION, IVOYAGER_BUILD, IVOYAGER_STATE, str(IVOYAGER_YMD)])

