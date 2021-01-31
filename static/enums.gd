# enums.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# "I, Voyager" is a registered trademark of Charlie Whitfield
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

class_name Enums

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

enum ConfidenceType {
	NO,
	DOUBTFUL,
	UNKNOWN,
	PROBABLY,
	YES,
}

enum BodyFlags {
	# identity (2 bytes reserved)
	IS_BARYCENTER = 0b1,
	IS_STAR = 0b10,
	IS_TRUE_PLANET = 0b100,
	IS_DWARF_PLANET = 0b1000,
	IS_MOON = 0b10000,
	IS_ASTEROID = 0b100000,
	IS_COMET = 0b1000000,
	IS_SPACECRAFT = 0b10000000,
	# properties (3 bytes reserved)
	FORCE_PROCESS = 0b1 * 0x10000, # Not implemented!: this body & all above it always process
	IS_TOP = 0b10 * 0x10000, # is in Registar.top_bodies
	PROXY_STAR_SYSTEM = 0b100 * 0x10000, # top star or barycenter of system
	IS_PRIMARY_STAR = 0b1000 * 0x10000,
	IS_STAR_ORBITING = 0b10000 * 0x10000,
	IS_TIDALLY_LOCKED = 0b100000 * 0x10000,
	IS_NAVIGATOR_MOON = 0b1000000 * 0x10000, # show in system navigator
	LIKELY_HYDROSTATIC_EQUILIBRIUM = 0b10000000 * 0x10000, # for moon orbit color
	DISPLAY_M_RADIUS = 0b1 * 0x1000000,
	HAS_ATMOSPHERE = 0b10 * 0x1000000,
#	APPROX_RADIUS = 0b10 * 0x1000000, # e.g., display as "~1 km" (TODO)
#	APPROX_GM = 0b100 * 0x1000000,
	# First 5 bytes reserved: 0b1 to 0b10000000 * 0x100000000
	# It's *probably* safe for extension to use bytes 6 to 8:
	#     0b1 * 0x10000000000 to 0b10000000 * 0x100000000000000
	# But more safe to extend Body and add your own flags_ext property!
}

# We can reference Godot classes here so TableReader has access to their enums
# e.g.,
# const GeometryInstance := GeometryInstance
# This should work but isn't tested yet...

static func get_reverse_enum(enum_name: String, value: int) -> String:
	# This is not fast! It's intended mostly for GUI.
	var dict: Dictionary = Global.enums[enum_name]
	for key in dict:
		if dict[key] == value:
			return key
	return ""
