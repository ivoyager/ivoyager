# registrar.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2019 Charlie Whitfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# *****************************************************************************
#
# Holds SelectionItems (so they aren't freed) and indexes Bodies.

extends Node
class_name Registrar

# persisted - read only
var top_body: Body
var selection_items := {} # indexed by name
const PERSIST_AS_PROCEDURAL_OBJECT := false
const PERSIST_OBJ_PROPERTIES := ["top_body", "selection_items"]

# unpersisted - public are read-only!
var bodies: Array = Global.bodies # indexed by body_id
var bodies_by_name: Dictionary = Global.bodies_by_name # indexed by name

var _removed_body_ids := []

func get_selection_for_body(body: Body) -> SelectionItem:
	var name_ := body.name
	return selection_items[name_]

func register_top_body(body: Body) -> void:
	top_body = body

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

func do_selection_counts_after_system_build() -> void:
	for name_ in selection_items:
		var selection_item: SelectionItem = selection_items[name_]
		count_selection(selection_item)

func count_selection(selection_item: SelectionItem) -> void:
	_change_count_recursive(selection_item, selection_item.selection_type, 1)
	
func uncount_selection(selection_item: SelectionItem) -> void:
	_change_count_recursive(selection_item, selection_item.selection_type, -1)


func project_init():
	Global.connect("about_to_free_procedural_nodes", self, "_clear")
	Global.connect("game_load_finished", self, "_index_bodies")

func _clear() -> void:
	top_body = null
	selection_items.clear()
	bodies.clear()
	bodies_by_name.clear()
	_removed_body_ids.clear()

func _index_bodies() -> void:
	_index_body_recursive(top_body)
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

func _change_count_recursive(selection_item: SelectionItem, selection_type: int, amount: int) -> void:
	var up_selection_name := selection_item.up_selection_name
	if up_selection_name:
		var up_selection: SelectionItem = selection_items[up_selection_name]
		up_selection.change_count(selection_type, amount)
		_change_count_recursive(up_selection, selection_type, amount)
		