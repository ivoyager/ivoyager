# lagrange_point.gd
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
class_name IVLagrangePoint
extends Node3D

# Passive Node3D that exists in the RotatingSpace of a Body. Use Body API to
# obtain (Body uses lazy init).


const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL # free & rebuild on load
const PERSIST_PROPERTIES := [&"lp_integer"]


var lp_integer: int # 1, 2, 3, 4, 5


func init(lp_integer_: int) -> void:
	lp_integer = lp_integer_

