# lagrange_point.gd
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
# This is a Spatial in case we want to update its translation in future
# implementation for a graphic icon (there is no translation update now). Its
# real purpose is to provide dynamic_elements for use by objects at Lagrange
# Points, e.g., trojans. Note that L-point objects are in orbit around their
# parent Body (e.g., Jupiter Trojans orbit the Sun). A LagrangePoint is itself
# not a Body but provides a common set of orbital elements that each L-point
# object needs to update its own orbital elements.
#
# TODO: Decide whether or not this should be a Body! Code & comments elsewhere
# indicate that this is our intention.

extends Spatial
class_name LagrangePoint

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
	_update_elements()

func _update_elements() -> void:
	var new_dynamic_elements := focal_orbit.get_elements(Global.time_array[0]).duplicate()
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




