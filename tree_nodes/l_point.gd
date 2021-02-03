# l_point.gd
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
# This is a Spatial in case we want to update its translation in future
# implementation for a graphic symbol (there is no translation update now). Its
# real purpose is to provide dynamic_elements for use by objects at Lagrange
# Points, e.g., trojans. Note that L-point objects are in orbit around their
# parent Body (e.g., Jupiter Trojans orbit the Sun). A LPoint is itself
# not a Body but provides a common set of orbital elements that each L-point
# object needs to update its own orbital elements.
#
# TODO: Decide whether or not this should be a Body! Code & comments elsewhere
# indicate that this is our intention.

extends Spatial
class_name LPoint

# persisted
var l_point: int # 1, 2, 3, 4, 5
var dynamic_elements: Array
var elements_at_epoch: Array
var focal_orbit: Orbit
const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["l_point", "dynamic_elements", "elements_at_epoch"]
const PERSIST_OBJ_PROPERTIES := ["focal_orbit"]

func init(focal_orbit_: Orbit, l_point_: int) -> void:
	focal_orbit = focal_orbit_
	l_point = l_point_
	focal_orbit.connect("changed", self, "_update_elements")
	_update_elements(false)

func _update_elements(_dummy: bool) -> void:
	var new_dynamic_elements := focal_orbit.get_elements(Global.times[0]).duplicate()
	var new_elements_at_epoch := focal_orbit.elements_at_epoch.duplicate()
	_offset_l_point(new_dynamic_elements)
	_offset_l_point(new_elements_at_epoch)
	dynamic_elements = new_dynamic_elements
	elements_at_epoch = new_elements_at_epoch

func _offset_l_point(elements: Array) -> void:
	match l_point:
		4: # shift M0 forward 60 degrees
			elements[5] += PI / 3.0
			elements[5] = fposmod(elements[5], TAU)
		5: # shift M0 back 60 degrees
			elements[5] -= PI / 3.0
			elements[5] = fposmod(elements[5], TAU)




