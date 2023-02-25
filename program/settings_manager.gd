# settings_manager.gd
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
class_name IVSettingsManager
extends IVCacheManager

# Settings are persisted in <cache_dir>/<cache_file_name> (specified below).
#
# TODO: We could have some settings cached in a user ProjectSettings override
# for restart engine settings (screen size, rendering, etc.).

const BodyFlags: Dictionary = IVEnums.BodyFlags


func _on_init():
	# project vars - modify on signal project_objects_instantiated
	cache_file_name = "settings.vbinary"
	defaults = {
		# save/load
		save_base_name = "I Voyager",
		append_date_to_save = true,
		pause_on_load = false,
	#	autosave = false,
	#	autosave_number = 5,
	#	autosave_minutes = 30,
	
		# camera
		camera_transfer_time = 1.0,
		camera_mouse_in_out_rate = 1.0,
		camera_mouse_move_rate = 1.0,
		camera_mouse_pitch_yaw_rate = 1.0,
		camera_mouse_roll_rate = 1.0,
		camera_key_in_out_rate = 1.0,
		camera_key_move_rate = 1.0,
		camera_key_pitch_yaw_rate = 1.0,
		camera_key_roll_rate = 1.0,

		# UI & HUD display
		gui_size = IVEnums.GUISize.GUI_MEDIUM,
		viewport_names_size = 15,
		viewport_symbols_size = 25,
		point_size = 3,
		hide_hud_when_close = true, # restart or load required
	
		# graphics/performance
		starmap = IVEnums.StarmapSize.STARMAP_16K,
	
		# misc
		mouse_action_releases_gui_focus = true,

		# cached but not in IVOptionsPopup
		save_dir = "",
		pbd_splash_caption_open = false,
		mouse_only_gui_nav = false,
		
		body_orbit_default_color = Color(0.4, 0.4, 0.8),
		body_orbit_colors = {
			# Keys must match single bits in IVBodyHUDsVisibility.visibility_flags
			BodyFlags.IS_STAR : Color(0.4, 0.4, 0.8), # maybe future use
			BodyFlags.IS_TRUE_PLANET :  Color(0.5, 0.5, 0.1),
			BodyFlags.IS_DWARF_PLANET : Color(0.1, 0.8, 0.2),
			BodyFlags.IS_PLANETARY_MASS_MOON : Color(0.3, 0.3, 0.9),
			BodyFlags.IS_NON_PLANETARY_MASS_MOON : Color(0.35, 0.1, 0.35),
			BodyFlags.IS_ASTEROID : Color(0.8, 0.2, 0.2),
			BodyFlags.IS_SPACECRAFT : Color(0.4, 0.4, 0.8),
		},
		small_bodies_points_default_color = Color(0.0, 0.6, 0.0),
		small_bodies_points_colors = {},
		small_bodies_orbits_default_color = Color(0.8, 0.2, 0.2),
		small_bodies_orbits_colors = {},

		}
	
	# read-only
	current = IVGlobal.settings


func _on_change_current(setting: String) -> void:
	IVGlobal.emit_signal("setting_changed", setting, current[setting])
