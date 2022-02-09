# body_registry.gd
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
class_name IVBodyRegistry
extends Node

# Indexes IVBody and IVSelection instances. Also holds IVSelectionItems so
# they aren't freed (they are References that need at least one reference).

const BodyFlags := IVEnums.BodyFlags
const IS_STAR := BodyFlags.IS_STAR
const IS_MOON := BodyFlags.IS_MOON
const IS_PLANET := BodyFlags.IS_TRUE_PLANET | BodyFlags.IS_DWARF_PLANET

# persisted - read only
var top_bodies := []
const PERSIST_AS_PROCEDURAL_OBJECT := false
const PERSIST_PROPERTIES := ["top_bodies"]

# private
var _selection_builder: IVSelectionBuilder = IVGlobal.program.SelectionBuilder
var _selections := {} # indexed by IVBody.name (e.g., "MOON_EUROPA")
var _bodies: Array = IVGlobal.bodies # indexed by body_id
var _bodies_by_name: Dictionary = IVGlobal.bodies_by_name # indexed by name
var _removed_body_ids := []


func _ready():
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_clear")
	IVGlobal.connect("game_load_finished", self, "_index_bodies")


func _clear() -> void:
	top_bodies.clear()
	_selections.clear()
	_bodies.clear()
	_bodies_by_name.clear()
	_removed_body_ids.clear()


func get_selection(selection_name: String) -> IVSelection:
	var selection: IVSelection = _selections.get(selection_name)
	if !selection:
		var body: IVBody = _bodies_by_name.get(selection_name)
		if !body:
			return null
		selection = _selection_builder.build_body_selection(body)
		if selection:
			_selections[selection_name] = selection
	return selection


func get_body_selection(body: IVBody) -> IVSelection:
	return get_selection(body.name)


func get_body_above_selection(selection: IVSelection) -> IVBody:
	while selection.up_selection_name:
		selection = get_selection(selection.up_selection_name)
		if selection.body:
			return selection.body
	return top_bodies[0]


func get_selection_star(selection: IVSelection) -> IVBody:
	if selection.get_flags() & IS_STAR:
		return selection.body
	while selection.up_selection_name:
		selection = get_selection(selection.up_selection_name)
		if selection.get_flags() & IS_STAR:
			return selection.body
	return top_bodies[0] # in case selection is Solar System; needs fix for multistar


func get_selection_planet(selection: IVSelection) -> IVBody:
	if selection.get_flags() & IS_PLANET:
		return selection.body
	while selection.up_selection_name:
		selection = get_selection(selection.up_selection_name)
		if !selection:
			return null
		if selection.get_flags() & IS_PLANET:
			return selection.body
	return null


func get_selection_moon(selection: IVSelection) -> IVBody:
	if selection.get_flags() & IS_MOON:
		return selection.body
	while selection.up_selection_name:
		selection = get_selection(selection.up_selection_name)
		if !selection:
			return null
		if selection.get_flags() & IS_MOON:
			return selection.body
	return null


func register_top_body(body: IVBody) -> void:
	top_bodies.append(body)


func register_body(body: IVBody) -> void:
	var name_ := body.name
	assert(!_bodies_by_name.has(name_))
	assert(body.body_id == -1)
	var body_id: int
	if _removed_body_ids:
		body_id = _removed_body_ids.pop_back()
		body.body_id = body_id
		_bodies[body_id] = body
	else:
		body_id = _bodies.size()
		body.body_id = body_id
		_bodies.append(body)
	_bodies_by_name[name_] = body


func remove_body(body: IVBody) -> void:
	var name_ := body.name
	assert(_bodies_by_name.has(name_))
	_bodies_by_name.erase(name_)
	var body_id: int = body.body_id
	_bodies[body_id] = null
	_removed_body_ids.append(body_id)


func register_selection(selection: IVSelection) -> void:
	var name_ := selection.name
	assert(!_selections.has(name_))
	_selections[name_] = selection


func remove_selection(selection: IVSelection) -> void:
	var name_ := selection.name
	assert(_selections.has(name_))
	_selections.erase(name_)


func _index_bodies() -> void:
	for body in top_bodies:
		_index_body_recursive(body)
	var n_bodies := _bodies.size()
	var index := 0
	while index < n_bodies:
		var body: IVBody = _bodies[index]
		if !body:
			_removed_body_ids.append(index)
		index += 1


func _index_body_recursive(body: IVBody) -> void:
	var body_id := body.body_id
	if _bodies.size() <= body_id + 1:
		_bodies.resize(body_id + 1)
	_bodies[body_id] = body
	_bodies_by_name[body.name] = body
	for child in body.get_children():
		if child is IVBody:
			_index_body_recursive(child)
