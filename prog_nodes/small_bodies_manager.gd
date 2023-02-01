# small_bodies_manager.gd
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
class_name IVSmallBodiesManager
extends Node

# Registers asteroids, comets or other sets of large-number items that we don't
# want instantiated (in full) as Nodes. Also manages IVSmallBodiesGroup and
# IVHUDPoints instances, which contain these small bodies or their shader
# representations.
#
# Small body ids are randomly generated from the range 0 to 68_719_476_735
# (36 bits). This helps IVPointPicker to not generate spurious ids. We assume
# that there will be less than billions of small bodies.

signal visibility_changed()


const PERSIST_MODE := IVEnums.PERSIST_PROPERTIES_ONLY
const PERSIST_PROPERTIES := [
	"ids",
	"infos",
	"groups_by_name",
	"lagrange_points",
]


# persisted; read-only!
var ids := {} # 36-bit id integers indexed by name string
var infos := {} # info arrays indexed by 36-bit id integer; [0] always name
var groups_by_name := {}
var lagrange_points := {} # indexed by group name


#func _ready():
#	IVGlobal.connect("about_to_free_procedural_nodes", self, "_clear")


func get_new_id(info: Array) -> int:
	# info[0] must be name string, which must be globally unique.
	# Assigns random id from interval 0 to 68_719_476_735 (36 bits).
	var name_str: String = info[0]
	assert(!ids.has(name_str), "Duplicated small body name: " + name_str)
	var id := (randi() << 4) | (randi() & 15) # randi() is only 32 bits
	while infos.has(id):
		id = (randi() << 4) | (randi() & 15)
	infos[id] = info
	ids[name_str] = id
	return id


func remove_id(id: int) -> void:
	var name_str: String = infos[id][0]
	infos.erase(id)
	ids.erase(name_str)


