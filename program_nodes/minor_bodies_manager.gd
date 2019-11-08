# minor_bodies_manager.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2019 Charlie Whitfield
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
#
# Not much here after some consolidation. Depreciate?

extends Node
class_name MinorBodiesManager


var asteroids := [] # index is asteroid_id (freed are null)

# Public
var group_names := [] # array with group labels
var ids_by_group := {} # dict of ids indexed by group label
var group_refs_by_name := {} # only AsteroidGroups now
var lagrange_points := {} # dict of lagrange_point objects indexed by group name

# persistence
const PERSIST_AS_PROCEDURAL_OBJECT := false
const PERSIST_PROPERTIES := ["group_names", "ids_by_group"]
const PERSIST_OBJ_PROPERTIES := ["asteroids", "group_refs_by_name", "lagrange_points"]


func project_init():
	pass


