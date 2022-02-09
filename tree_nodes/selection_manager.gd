# selection_manager.gd
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
class_name IVSelectionManager
extends Node

# Has currently selected item and keeps selection history. You can have >1 of
# these. GUI widgets search up their ancestor tree and grab an IVSelectionManager
# from the first control with a child named "SelectionManager".

signal selection_changed()
signal selection_reselected()

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

const BodyFlags := IVEnums.BodyFlags
const IS_STAR := BodyFlags.IS_STAR
const IS_TRUE_PLANET := BodyFlags.IS_TRUE_PLANET
const IS_DWARF_PLANET := BodyFlags.IS_DWARF_PLANET
const IS_MOON := BodyFlags.IS_MOON
const IS_NAVIGATOR_MOON := BodyFlags.IS_NAVIGATOR_MOON
const IS_SPACECRAFT := BodyFlags.IS_SPACECRAFT
const IS_PLANET := BodyFlags.IS_TRUE_PLANET | BodyFlags.IS_DWARF_PLANET

# persisted
var is_action_listener := true
var selection: IVSelection
const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["is_action_listener", "selection"]

# private
var _root: Viewport = IVGlobal.get_tree().get_root()
var _body_registry: IVBodyRegistry = IVGlobal.program.BodyRegistry
var _history := [] # contains weakrefs
var _history_index := -1
var _supress_history := false

onready var _tree: SceneTree = get_tree()


func _init() -> void:
	name = "SelectionManager"
	

func _ready() -> void:
	IVGlobal.connect("system_tree_ready", self, "_on_system_tree_ready")
	set_process_unhandled_key_input(is_action_listener)
	print(self, " ready...")


func _on_system_tree_ready(is_new_game: bool) -> void:
	if is_new_game:
		var start_body_name: String = IVGlobal.start_body_name
		var selection_: IVSelection = _body_registry.get_selection(start_body_name)
		select(selection_)
	else:
		_add_history()


func _unhandled_key_input(event: InputEventKey) -> void:
	if !event.is_action_type() or !event.is_pressed():
		return
	if event.is_action_pressed("select_forward"):
		forward()
	elif event.is_action_pressed("select_back"):
		back()
	elif event.is_action_pressed("select_left"):
		next_last(-1)
	elif event.is_action_pressed("select_right"):
		next_last(1)
	elif event.is_action_pressed("select_up"):
		up()
	elif event.is_action_pressed("select_down"):
		down()
	elif event.is_action_pressed("next_star"):
		next_last(1, SELECTION_STAR)
	elif event.is_action_pressed("previous_planet"):
		next_last(-1, SELECTION_PLANET)
	elif event.is_action_pressed("next_planet"):
		next_last(1, SELECTION_PLANET)
	elif event.is_action_pressed("previous_nav_moon"):
		next_last(-1, SELECTION_NAVIGATOR_MOON)
	elif event.is_action_pressed("next_nav_moon"):
		next_last(1, SELECTION_NAVIGATOR_MOON)
	elif event.is_action_pressed("previous_moon"):
		next_last(-1, SELECTION_MOON)
	elif event.is_action_pressed("next_moon"):
		next_last(1, SELECTION_MOON)
	elif event.is_action_pressed("previous_spacecraft"):
		next_last(-1, SELECTION_SPACECRAFT)
	elif event.is_action_pressed("next_spacecraft"):
		next_last(1, SELECTION_SPACECRAFT)
	else:
		return # input NOT handled!
	_tree.set_input_as_handled()


func has_selection() -> bool:
	return selection != null


func get_item() -> IVSelection:
	return selection


func select(selection_: IVSelection) -> void:
	if selection == selection_:
		emit_signal("selection_reselected")
		return
	selection = selection_
	_add_history()
	emit_signal("selection_changed")


func select_body(body_: IVBody) -> void:
	var selection_: IVSelection = _body_registry.get_body_selection(body_)
	if selection_:
		select(selection_)


func select_by_name(selection_name: String) -> void:
	var selection_: IVSelection = _body_registry.get_selection(selection_name)
	if selection_:
		select(selection_)


func get_name() -> String:
	if selection:
		return selection.name
	return ""


func get_texture_2d() -> Texture:
	if selection:
		return selection.texture_2d
	return null


func get_body() -> IVBody:
	if selection:
		return selection.body
	return null


func is_body() -> bool:
	return selection.is_body


func back() -> void:
	if _history_index < 1:
		return
	_history_index -= 1
	var wr: WeakRef = _history[_history_index]
	var new_selection: IVSelection = wr.get_ref()
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
	var new_selection: IVSelection = wr.get_ref()
	if new_selection:
		_supress_history = true
		select(new_selection)
	else:
		forward()


func up() -> void:
	var up_name := selection.up_selection_name
	if up_name:
		var new_selection: IVSelection = _body_registry.get_selection(up_name)
		select(new_selection)


func can_go_back() -> bool:
	return _history_index > 0


func can_go_forward() -> bool:
	return _history_index < _history.size() - 1


func can_go_up() -> bool:
	return selection and selection.up_selection_name


func down() -> void:
	var body: IVBody = selection.body
	if body and body.satellites:
		select_body(body.satellites[0])


func next_last(incr: int, selection_type := -1, _alt_selection_type := -1) -> void:
	var current_body := selection.body # could be null
	var iteration_array: Array
	var index := -1
	match selection_type:
		-1:
			var up_body := _body_registry.get_body_above_selection(selection)
			iteration_array = up_body.satellites
			index = iteration_array.find(current_body)
		SELECTION_STAR:
			 # TODO: code for multistar systems
			var sun: IVBody = _body_registry.top_bodies[0]
			select_body(sun)
			return
		SELECTION_PLANET:
			var star := _body_registry.get_selection_star(selection)
			if !star:
				return
			iteration_array = star.satellites
			var planet := _body_registry.get_selection_planet(selection)
			if planet:
				index = iteration_array.find(planet)
				if planet != current_body and incr == 1:
					index -= 1
		SELECTION_NAVIGATOR_MOON, SELECTION_MOON:
			var planet := _body_registry.get_selection_planet(selection)
			if !planet:
				return
			iteration_array = planet.satellites
			var moon := _body_registry.get_selection_moon(selection)
			if moon:
				index = iteration_array.find(moon)
				if moon != current_body and incr == 1:
					index -= 1
		SELECTION_SPACECRAFT:
			if current_body:
				iteration_array = current_body.satellites
			else:
				var up_body := _body_registry.get_body_above_selection(selection)
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
		var body: IVBody = iteration_array[index]
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


func erase_history() -> void:
	_history.clear()
	_history_index = -1


func get_selection_and_history() -> Array:
	return [selection, _history.duplicate(), _history_index]


func set_selection_and_history(array: Array) -> void:
	selection = array[0]
	_history = array[1]
	_history_index = array[2]


func _add_history() -> void:
	if _supress_history:
		_supress_history = false
		return
	if _history_index >= 0:
		var last_wr: WeakRef = _history[_history_index]
		var last_selection: IVSelection = last_wr.get_ref()
		if last_selection == selection:
			return
	_history_index += 1
	if _history.size() > _history_index:
		_history.resize(_history_index)
	var wr := weakref(selection)
	_history.append(wr)
