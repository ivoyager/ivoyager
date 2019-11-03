# l_point_builder.gd
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

extends Reference
class_name LPointBuilder

var _LagrangePoint_: Script

func project_init() -> void:
	_LagrangePoint_ = Global.script_classes._LagrangePoint_

func get_or_make_lagrange_point(body: Body, l_point: int) -> LagrangePoint:
	# Any Body can have Lagrange Points: L1, L2, L3, L4 or L5. Since most
	# will never be used, we create them only as needed. The L-point is orbiting
	# this object's parent Body, but will define its orbital elements
	# in reference to this object.
	var lagrange_point: LagrangePoint
	if body.lagrange_points:
		lagrange_point = body.lagrange_points[l_point - 1]
	else:
		body.lagrange_points.resize(5)
	if !lagrange_point:
		lagrange_point = FileHelper.make_object_or_scene(_LagrangePoint_)
		lagrange_point.init(body.orbit, l_point)
		body.get_parent().add_child(lagrange_point)
		body.lagrange_points[l_point - 1] = lagrange_point
	return lagrange_point
	
	