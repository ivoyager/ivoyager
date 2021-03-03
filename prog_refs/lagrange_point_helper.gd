# lagramge_point_helper.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield
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

extends Reference
class_name LPointBuilder

var _LPoint_: Script

func _project_init() -> void:
	_LPoint_ = Global.script_classes._LPoint_

func get_or_make_lagrange_point(body: Body, l_point: int) -> LPoint:
	# Any Body can have Lagrange Points: L1, L2, L3, L4 or L5. Since most
	# will never be used, we create them only as needed. The L-point is orbiting
	# this object's parent Body, but will define its orbital elements
	# in reference to this object.
	var lagrange_point: LPoint
	if body.lagrange_points:
		lagrange_point = body.lagrange_points[l_point - 1]
	else:
		body.lagrange_points.resize(5)
	if !lagrange_point:
		lagrange_point = _LPoint_.new()
		lagrange_point.init(body.orbit, l_point)
		body.get_parent().add_child(lagrange_point)
		body.lagrange_points[l_point - 1] = lagrange_point
	return lagrange_point
	
	
