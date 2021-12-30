# minor_bodies_manager.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2022 Charlie Whitfield
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
# Not much here after consolidation. Depreciate?

extends Node
class_name MinorBodiesManager


# Public
var group_names := []
var ids_by_group := {} # arrays of ids indexed by group name
var group_refs_by_name := {} # AsteroidGroups now
var lagrange_points := {} # dict of lagrange_point objects indexed by group name

# persistence
const PERSIST_AS_PROCEDURAL_OBJECT := false
const PERSIST_PROPERTIES := ["group_names", "ids_by_group", "group_refs_by_name", "lagrange_points"]


func _ready():
	Global.connect("about_to_free_procedural_nodes", self, "_restore_init_state")

func _restore_init_state() -> void:
	group_names.clear()
	ids_by_group.clear()
	group_refs_by_name.clear()
	lagrange_points.clear()
