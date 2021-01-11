# properties.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
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
# For floats: INF means unknown, -INF means not applicable. All physical bodies
# have mass & m_radius (although possibly unknown). Other properties may apply
# by body type.

class_name Properties

var mass := INF
var m_radius := INF
var gm := -INF
var surface_gravity := -INF
var esc_vel := -INF
var e_radius := -INF
var p_radius := -INF
var hydrostatic_equilibrium := -1 # Enums.KnowTypes
var mean_density := INF
var albedo := -INF
var surf_pres := -INF
var surf_t := -INF # NA for gas giants
var min_t := -INF
var max_t := -INF
var one_bar_t := -INF # venus, gas giants
var half_bar_t := -INF # earth, venus, gas giants
var tenth_bar_t := -INF # gas giants

const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["mass", "m_radius",
	"gm", "surface_gravity", "esc_vel", "e_radius", "p_radius",
	"hydrostatic_equilibrium", "mean_density", "albedo", "surf_pres",
	"surf_t", "min_t", "max_t", "one_bar_t", "half_bar_t", "tenth_bar_t"]

