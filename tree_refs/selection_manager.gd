# selection_manager.gd
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
# Has currently selected item and keeps selection history. You can have >1 of
# these. GUI widgets search up for the 1st selection_manager in the ancestor
# tree. VygrCameraHandler grabs selection_manager from Global.program.ProjectGUI.

extends Reference
class_name SelectionManager

signal selection_changed()

enum {
	# some implemented but many planned
	SELECTION_UNIVERSE,
	SELECTION_GALAXY,
	SELECTION_STAR_SYSTEM, # use as generic for Solar System (there isn't one!)
	SELECTION_STAR,
	SELECTION_TRUE_PLANET,
	SELECTION_DWARF_PLANET,
	SELECTION_PLANET, # both kinds ;-)
	SELECTION_NAVIGATOR_MOON, # present in navigator GUI
	SELECTION_MOON,
	SELECTION_ASTEROID,
	SELECTION_COMMET,
	SELECTION_SPACECRAFT,
	SELECTION_ALL_ASTEROIDS,
	SELECTION_ASTEROID_GROUP,
	SELECTION_ALL_COMMETS,
	SELECTION_ALL_SPACECRAFTS,
	# useful?
	SELECTION_BARYCENTER,
	SELECTION_LAGRANGE_POINT,
}

const BodyFlags := Enums.BodyFlags
const IS_STAR := BodyFlags.IS_STAR
const IS_TRUE_PLANET := BodyFlags.IS_TRUE_PLANET
const IS_DWARF_PLANET := BodyFlags.IS_DWARF_PLANET
const IS_MOON := BodyFlags.IS_MOON
const IS_NAVIGATOR_MOON := BodyFlags.IS_NAVIGATOR_MOON
const IS_SPACECRAFT := BodyFlags.IS_SPACECRAFT
const IS_PLANET := BodyFlags.IS_TRUE_PLANET | BodyFlags.IS_DWARF_PLANET

# persisted
var selection_item: SelectionItem

const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_OBJ_PROPERTIES := ["selection_item"]

# private
var _root: Viewport = Global.get_tree().get_root()
var _registrar: Registrar = Global.program.Registrar
var _history := [] # contains weakrefs
var _history_index := -1
var _supress_history := false


func select(selection_item_: SelectionItem) -> void:
	if selection_item == selection_item_:
		return
	selection_item = selection_item_
	_add_history()
	emit_signal("selection_changed")

func select_body(body_: Body) -> void:
	var name := body_.name
	var selection_item_: SelectionItem = _registrar.selection_items[name]
	select(selection_item_)

func get_name() -> String:
	if selection_item:
		return selection_item.name
	return ""
	
func get_texture_2d() -> Texture:
	if selection_item:
		return selection_item.texture_2d
	return null

func get_body() -> Body:
	if selection_item:
		return selection_item.body
	return null
	
func is_body() -> bool:
	return selection_item.is_body

func back() -> void:
	if _history_index < 1:
		return
	_history_index -= 1
	var wr: WeakRef = _history[_history_index]
	var new_selection: SelectionItem = wr.get_ref()
	if new_selection:
		_supress_history = true
		select(new_selection)
	else:
		back()
	
func forward() -> void:
	if _history_index > _history.size() - 2:
		return
	_history_index += 1
	var wr: WeakRef = _history[_history_index]
	var new_selection: SelectionItem = wr.get_ref()
	if new_selection:
		_supress_history = true
		select(new_selection)
	else:
		forward()
	
func up() -> void:
	if selection_item.up_selection_name:
		var new_selection: SelectionItem = _registrar.selection_items[selection_item.up_selection_name]
		select(new_selection)

func can_go_back() -> bool:
	return _history_index > 0
	
func can_go_forward() -> bool:
	return _history_index < _history.size() - 1
	
func can_go_up() -> bool:
	return selection_item and selection_item.up_selection_name

func down() -> void:
	var body: Body = selection_item.body
	if body and body.satellites:
		select_body(body.satellites[0])

func next_last(incr: int, selection_type := -1, _alt_selection_type := -1) -> void:
	var current_body := selection_item.body # could be null
	var iteration_array: Array
	var index := -1
	match selection_type:
		-1:
			var up_body := _registrar.get_body_above_selection(selection_item)
			iteration_array = up_body.satellites
			index = iteration_array.find(current_body)
		SELECTION_STAR:
			 # TODO: code for multistar systems
			var sun: Body = _registrar.top_bodies[0]
			select_body(sun)
			return
		SELECTION_PLANET:
			var star := _registrar.get_selection_star(selection_item)
			if !star:
				return
			iteration_array = star.satellites
			var planet := _registrar.get_selection_planet(selection_item)
			if planet:
				index = iteration_array.find(planet)
				if planet != current_body and incr == 1:
					index -= 1
		SELECTION_NAVIGATOR_MOON, SELECTION_MOON:
			var planet := _registrar.get_selection_planet(selection_item)
			if !planet:
				return
			iteration_array = planet.satellites
			var moon := _registrar.get_selection_moon(selection_item)
			if moon:
				index = iteration_array.find(moon)
				if moon != current_body and incr == 1:
					index -= 1
		SELECTION_SPACECRAFT:
			if current_body:
				iteration_array = current_body.satellites
			else:
				var up_body := _registrar.get_body_above_selection(selection_item)
				iteration_array = up_body.satellites
	if !iteration_array:
		return
	var array_size := iteration_array.size()
	var count := 0
	while count < array_size:
		index += incr
		if index < 0:
			index = array_size - 1
		elif index >= array_size:
			index = 0
		var body: Body = iteration_array[index]
		var select := false
		match selection_type:
			-1:
				select = true
			SELECTION_STAR:
				select = bool(body.flags & IS_STAR)
			SELECTION_PLANET:
				select = bool(body.flags & IS_PLANET)
			SELECTION_NAVIGATOR_MOON:
				select = bool(body.flags & IS_NAVIGATOR_MOON)
			SELECTION_MOON:
				select = bool(body.flags & IS_MOON)
			SELECTION_SPACECRAFT:
				select = bool(body.flags & IS_SPACECRAFT)
		if select:
			select_body(body)
			return
		count += 1

func _add_history() -> void:
	if _supress_history:
		_supress_history = false
		return
	if _history_index >= 0:
		var last_wr: WeakRef = _history[_history_index]
		var last_selection_item: SelectionItem = last_wr.get_ref()
		if last_selection_item == selection_item:
			return
	_history_index += 1
	if _history.size() > _history_index:
		_history.resize(_history_index)
	var wr := weakref(selection_item)
	_history.append(wr)
