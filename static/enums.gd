# enums.gd
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
class_name IVEnums

# We keep enums here that are broadly needed by the program.
#
# You can extend this class and assign your extended class to IVGlobal.enums.
# This is used by program systems that need to interpret enums without specific
# knowledge of their context. E.g.:
#  - IVTableImporter for interpretting enum names in external *.tsv files
#  - GUI widget selection_data.gd for object info display 

enum { # duplicated from IVSaveBuilder so we can remove the gamesave system
	NO_PERSIST,
	PERSIST_PROPERTIES_ONLY,
	PERSIST_PROCEDURAL,
}


enum NetworkState {
	NO_NETWORK,
	IS_SERVER,
	IS_CLIENT,
}

enum NetworkStopSync {
	BUILD_SYSTEM,
	SAVE,
	LOAD,
	NEW_PLAYER, # needs save to enter in-progress game
	EXIT,
	QUIT,
	DONT_SYNC,
}

enum ViewType {
	VIEW_ZOOM,
	VIEW_45,
	VIEW_TOP,
	VIEW_OUTWARD,
	VIEW_BUMPED, # unspecified view_position
	VIEW_BUMPED_ROTATED # unspecified view_position & view_rotations
}

enum CameraTrackType {
	TRACK_NONE,
	TRACK_ORBIT,
	TRACK_GROUND,
}

enum GUISize {
	GUI_SMALL,
	GUI_MEDIUM,
	GUI_LARGE,
}

enum StarmapSize {
	STARMAP_8K,
	STARMAP_16K,
}

enum Confidence {
	CONFIDENCE_NO,
	CONFIDENCE_DOUBTFUL,
	CONFIDENCE_UNKNOWN,
	CONFIDENCE_PROBABLY,
	CONFIDENCE_YES,
}

enum BodyFlags {
	
	# reserved 1 << 0,
	IS_BARYCENTER = 1 << 1, # not implemented yet
	IS_STAR = 1 << 2,
	IS_TRUE_PLANET = 1 << 3,
	IS_DWARF_PLANET = 1 << 4,
	IS_MOON = 1 << 5,
	IS_ASTEROID = 1 << 6,
	IS_COMET = 1 << 7,
	IS_SPACECRAFT = 1 << 8,
	
	# combos
	IS_PLANET = 1 << 3 | 1 << 4, # 'true' or dwarf planet
	IS_PLANET_OR_MOON = 1 << 3 | 1 << 4 | 1 << 5,

	# reserved 1 << 9,
	# reserved 1 << 10,
	
	NEVER_SLEEP = 1 << 11, # won't work correctly if ancestor node sleeps
	IS_TOP = 1 << 12, # is in Registar.top_bodies
	PROXY_STAR_SYSTEM = 1 << 13, # top star or barycenter of system
	IS_PRIMARY_STAR = 1 << 14,
	IS_STAR_ORBITING = 1 << 15,
	IS_TIDALLY_LOCKED = 1 << 16,
	IS_AXIS_LOCKED = 1 << 17,
	TUMBLES_CHAOTICALLY = 1 << 18,
	
	IS_NAVIGATOR_MOON = 1 << 20, # show in system navigator
	LIKELY_HYDROSTATIC_EQUILIBRIUM = 1 << 21, # for moon orbit color
	DISPLAY_M_RADIUS = 1 << 22,
	HAS_ATMOSPHERE = 1 << 23,
#	APPROX_RADIUS = 1 << 24, # e.g., display as "~1 km" (TODO)
#	APPROX_GM = 1 << 25,
#
#   reserved to 1 << 39,
#
#	Higher bits safe for extension project.
#	Max bit shift is 1 << 63.
}


