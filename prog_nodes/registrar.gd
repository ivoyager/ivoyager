# registrar.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# "I, Voyager" is a registered trademark of Charlie Whitfield
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
# Holds SelectionItems (so they aren't freed) and indexes Bodies.

extends Node
class_name Registrar

const BodyFlags := Enums.BodyFlags
const IS_STAR := BodyFlags.IS_STAR
const IS_MOON := BodyFlags.IS_MOON
const IS_PLANET := BodyFlags.IS_TRUE_PLANET | BodyFlags.IS_DWARF_PLANET

# persisted - read only
var top_bodies := []
var selection_items := {} # indexed by name
const PERSIST_AS_PROCEDURAL_OBJECT := false
const PERSIST_OBJ_PROPERTIES := ["top_bodies", "selection_items"]

# unpersisted - public are read-only!
var bodies: Array = Global.bodies # indexed by body_id
var bodies_by_name: Dictionary = Global.bodies_by_name # indexed by name
var _removed_body_ids := []

func get_body_above_selection(selection_item: SelectionItem) -> Body:
	while selection_item.up_selection_name:
		selection_item = selection_items[selection_item.up_selection_name]
		if selection_item.body:
			return selection_item.body
	return top_bodies[0]

func get_selection_star(selection_item: SelectionItem) -> Body:
	if selection_item.get_flags() & IS_STAR:
		return selection_item.body
	while selection_item.up_selection_name:
		selection_item = selection_items[selection_item.up_selection_name]
		if selection_item.get_flags() & IS_STAR:
			return selection_item.body
	return top_bodies[0] # in case selection is Solar System; needs fix for multistar

func get_selection_planet(selection_item: SelectionItem) -> Body:
	if selection_item.get_flags() & IS_PLANET:
		return selection_item.body
	while selection_item.up_selection_name:
		selection_item = selection_items[selection_item.up_selection_name]
		if selection_item.get_flags() & IS_PLANET:
			return selection_item.body
	return null

func get_selection_moon(selection_item: SelectionItem) -> Body:
	if selection_item.get_flags() & IS_MOON:
		return selection_item.body
	while selection_item.up_selection_name:
		selection_item = selection_items[selection_item.up_selection_name]
		if selection_item.get_flags() & IS_MOON:
			return selection_item.body
	return null

func get_selection_for_body(body: Body) -> SelectionItem:
	var name_ := body.name
	return selection_items[name_]

func register_top_body(body: Body) -> void:
	top_bodies.append(body)

func register_body(body: Body) -> void:
	var name_ := body.name
	assert(!bodies_by_name.has(name_))
	assert(body.body_id == -1)
	var body_id: int
	if _removed_body_ids:
		body_id = _removed_body_ids.pop_back()
		body.body_id = body_id
		bodies[body_id] = body
	else:
		body_id = bodies.size()
		body.body_id = body_id
		bodies.append(body)
	bodies_by_name[name_] = body

func remove_body(body: Body) -> void:
	var name_ := body.name
	assert(bodies_by_name.has(name_))
	bodies_by_name.erase(name_)
	var body_id: int = body.body_id
	bodies[body_id] = null
	_removed_body_ids.append(body_id)

func register_selection_item(selection_item: SelectionItem) -> void:
	var name_ := selection_item.name
	assert(!selection_items.has(name_))
	selection_items[name_] = selection_item

func remove_selection_item(selection_item: SelectionItem) -> void:
	var name_ := selection_item.name
	assert(selection_items.has(name_))
	selection_items.erase(name_)

func project_init():
	Global.connect("about_to_free_procedural_nodes", self, "_clear")
	Global.connect("game_load_finished", self, "_index_bodies")

func _clear() -> void:
	top_bodies.clear()
	selection_items.clear()
	bodies.clear()
	bodies_by_name.clear()
	_removed_body_ids.clear()

func _index_bodies() -> void:
	for body in top_bodies:
		_index_body_recursive(body)
	var n_bodies := bodies.size()
	var index := 0
	while index < n_bodies:
		var body: Body = bodies[index]
		if !body:
			_removed_body_ids.append(index)
		index += 1

func _index_body_recursive(body: Body) -> void:
	var body_id := body.body_id
	if bodies.size() <= body_id + 1:
		bodies.resize(body_id + 1)
	bodies[body_id] = body
	bodies_by_name[body.name] = body
	for child in body.get_children():
		if child is Body:
			_index_body_recursive(child)
