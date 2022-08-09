# body_list.gd
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
class_name IVBodyList

# WIP - not implemented!
# Manages lists of instanced and "virtual" bodies. Virtual bodies are simply
# names that are instanced only if/when individually selected (eg, our 300000+
# Main Belt asteroids).

enum {
	SORT_NO_SORT, # leave as is, eg, from a data table
	SORT_DEFAULT,
	SORT_ASTEROIDS
	}

const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL
const PERSIST_PROPERTIES := [
	"list_name",
	"body_names",
	"_sort_type",
	"bodies_by_name",
	"_instance_builder",
]

# persisted
var list_name: String
var body_names: Array
var bodies_by_name := {}
var _instance_builder: Object
var _sort_type: int
#var _asteroid_integers: Dictionary


#func init_virtual_bodies(list_name_: String, sort_type := SORT_DEFAULT, body_names_ := [],
#		instance_builder: Object = null) -> void:
#	# body_names_ is kept & modified
#	list_name = list_name_
#	_instance_builder = instance_builder
#	_sort_type = sort_type
#	body_names = body_names_
#	match sort_type:
#		SORT_DEFAULT:
#			body_names.sort()
#		SORT_ASTEROIDS:
#			body_names.sort_custom(self, "_sort_asteroids")
#
#
#func init_bodies(list_name_: String, sort_type := SORT_DEFAULT, bodies := [], instance_builder: Object = null) -> void:
#	# bodies is released w/out modification
#	list_name = list_name_
#	_instance_builder = instance_builder
#	_sort_type = sort_type
#	body_names = []
#	for body in bodies:
#		var name: String = body.name
#		assert(!bodies_by_name.has(name))
#		body_names.append(name)
#		bodies_by_name[name] = body
#	match sort_type:
#		SORT_DEFAULT:
#			body_names.sort()
#		SORT_ASTEROIDS:
#			body_names.sort_custom(self, "_sort_asteroids")
#
#
#func add_body(_body: IVBody) -> void:
#	pass
#
#
#func add_virtual_body(_body_name: String) -> void:
#	pass
#
#
#func remove_body(_body: IVBody) -> void:
#	pass
#
#
#func remove_virtual_body(_body_name: String) -> void:
#	pass
#
#
## warning-ignore:unused_argument
#func select(body_name: String, selection_manager: IVSelectionManager) -> void:
## warning-ignore:unused_variable
#	var body: IVBody
#	if bodies_by_name.has(body_name):
#		body = bodies_by_name[body_name]
#	else:
#		prints(body_name, "selected!")
#		return
##		body = _builder.make_body(body_name)
##	selection_manager.select(selection)
#
#
#func _sort_asteroids(a: String, b: String) -> bool:
#	# Sort on id, if this is "id [name]" format, but sort alphabetically if
#	# string is "year letters digits" format.
#	return a < b
