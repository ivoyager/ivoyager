# view.gd
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

class_name View



var selection_name: String
var track_type: int
var view_position: Vector3 # spherical; relative to orbit or ground ref
var view_rotations: Vector3 # euler; relative to looking_at(-origin, north)

const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := []

