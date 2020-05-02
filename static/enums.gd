# enums.gd
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

class_name Enums

enum SelectionTypes {
	SELECTION_UNIVERSE, # I, Voyager doesn't use the first three
	SELECTION_GALAXY,
	SELECTION_STAR_COLLECTION,
	SELECTION_STAR_SYSTEM, # used as generic for Solar System (there isn't one!)
	SELECTION_BARYCENTER,
	SELECTION_LAGRANGE_POINT,
	SELECTION_STAR,
	SELECTION_PLANET,
	SELECTION_DWARF_PLANET,
	SELECTION_MAJOR_MOON, # major/minor for GUI purposes (not official)
	SELECTION_MINOR_MOON,
	SELECTION_ASTEROIDS,
	SELECTION_ASTEROID_GROUP,
	SELECTION_COMMETS,
	SELECTION_SPACECRAFTS,
	SELECTION_ASTEROID,
	SELECTION_COMMET,
	SELECTION_SPACECRAFT
}

enum ViewTypes {
	VIEW_ZOOM,
	VIEW_45,
	VIEW_TOP,
	VIEW_CENTERED, # unspecified view_position
	VIEW_UNCENTERED # unspecified view_position & view_orientation
}

enum GUISizes {
	GUI_SMALL,
	GUI_MEDIUM,
	GUI_LARGE,
}

enum StarmapSizes {
	STARMAP_8K,
	STARMAP_16K,
}
