# small_bodies_group_indexing.gd
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
class_name IVSmallBodiesGroupIndexing
extends Node

# Indexes and persists IVSmallBodiesGroup instances (which are Reference
# class). Instances must access this node and manage 'group_ids' and 'groups'
# themselves.


const PERSIST_MODE := IVEnums.PERSIST_PROPERTIES_ONLY
const PERSIST_PROPERTIES := [
	"group_ids",
	"groups",
]


# persisted; read-only!
var group_ids := {} # indexed by group name; groups add themselves
var groups := [] # indexed by group_id; groups add themselves


func _ready():
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_clear")


func _clear() -> void: # just objects
	groups.clear()


