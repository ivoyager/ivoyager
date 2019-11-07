# settings_manager.gd
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
# Settings are persisted in <cache_dir>/<cache_file_name> (specified below).
#
# TODO: We could have some settings cached in a user ProjectSettings override
# for restart engine settings (screen size, rendering, etc.).

extends CachedItemsManager
class_name SettingsManager

enum GUISizes {
	GUI_SMALL,
	GUI_MEDIUM,
	GUI_LARGE,
	}

func _on_init():
	# project vars - modify on ProjectBuilder signal "project_objects_instantiated"
	cache_file_name = "settings.vbinary"
	defaults = {
		# save/load
		save_base_name = "I Voyager",
		append_date_to_save = true,
		loaded_game_is_paused = false,
	#	autosave = false,
	#	autosave_number = 5,
	#	autosave_minutes = 30,
	
		# camera
		camera_move_seconds = 1.0,
		
		# UI & HUD display
		gui_size = GUISizes.GUI_MEDIUM,
		viewport_label_size = 12,
		viewport_icon_size = 100,
		hide_hud_when_close = true, # restart or load required
	
		# graphics
		planet_orbit_color = Color(0.3, 0.4, 0.1), # Color(0.5,0.7,0.4) # dark green w/ yellow
		dwarf_planet_orbit_color = Color(0.0, 0.4, 0.2), # Color(0.5,0.7,0.4) # dark green
		moon_orbit_color = Color(0.2, 0.2, 0.8), # Color(0.4,0.4,0.8) # dark blue
		minor_moon_orbit_color = Color(0.2, 0.05, 0.2), # Color(0.4,0.4,0.8) # dark purple
		default_orbit_color = Color(0.25, 0.25, 0.25), # Color(0.4,0.4,0.8) # grey
		asteroid_point_color = Color("008800"),
	
		# misc
		toggle_real_time_not_pause = false,
		mouse_action_releases_gui_focus = true,

		# cached but not in base OptionsPopup
		save_dir = "",
		pbd_splash_caption_open = false,
		
		# TODO:
#		planet_icon_color = Color(0.5, 0.7, 0.4), # green w/ yellow
#		moon_icon_color = Color(0.5, 0.7, 0.4), # green w/ yellow
#		minor_orbit_color = Color(0.8, 0.0, 0.0),
		}
	
	# read-only
	current = Global.settings

func _on_change_current(setting: String) -> void:
	Global.emit_signal("setting_changed", setting, current[setting])
