# selection_manager.gd
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
class_name IVSelectionManager
extends Node

# Has currently selected item and keeps selection history. In many applications
# you only need one SelectionManager, but any number are possible. GUI widgets
# search up their ancestor tree and obtain from the first Control node with
# non-null member 'selection_manager'.

signal selection_changed(suppress_camera_move)
signal selection_reselected(suppress_camera_move)

enum {
	# not all of these are implemented yet...
	SELECTION_UNIVERSE,
	SELECTION_GALAXY,
	SELECTION_STAR_SYSTEM,
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

const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL
const PERSIST_PROPERTIES := [
	"is_action_listener",
	"selection",
]

# persisted
var is_action_listener := true
var selection: IVSelection

# private
var _root: SubViewport = IVGlobal.get_tree().get_root()
var _selection_builder: IVSelectionBuilder = IVGlobal.program.SelectionBuilder
var _selections: Dictionary = IVGlobal.selections
var _history := [] # contains weakrefs
var _history_index := -1
var _supress_history := false

@onready var _tree: SceneTree = get_tree()


func _init() -> void:
	name = "SelectionManager"
	

func _ready() -> void:
	IVGlobal.connect("system_tree_ready", Callable(self, "_on_system_tree_ready"))
	IVGlobal.connect("about_to_free_procedural_nodes", Callable(self, "_clear_selections"))
	set_process_unhandled_key_input(is_action_listener)


func _on_system_tree_ready(is_new_game: bool) -> void:
	if is_new_game:
		var selection_ := get_or_make_selection(IVGlobal.home_name)
		select(selection_, true)
	else:
		_add_history()


func _unhandled_key_input(event: InputEvent) -> void:
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


static func get_or_make_selection(selection_name: String) -> IVSelection:
	# I, Voyager supports IVBody selection only! Override for others.
	var selection_: IVSelection = IVGlobal.selections.get(selection_name)
	if selection_:
		return selection_
	if IVGlobal.bodies.has(selection_name):
		return make_selection_for_body(selection_name)
	assert(false, "Unsupported selection type")
	return null


static func make_selection_for_body(body_name: String) -> IVSelection:
	assert(!IVGlobal.selections.has(body_name))
	var body: IVBody = IVGlobal.bodies[body_name] # must exist
	var selection_builder: IVSelectionBuilder = IVGlobal.program.SelectionBuilder
	var selection_ := selection_builder.build_body_selection(body)
	if selection_:
		IVGlobal.selections[body_name] = selection_
	return selection_


static func get_body_above_selection(selection_: IVSelection) -> IVBody:
	while selection_.up_selection_name:
		selection_ = get_or_make_selection(selection_.up_selection_name)
		if selection_.body:
			return selection_.body
	return IVGlobal.top_bodies[0]


static func get_body_at_above_selection_w_flags(selection_: IVSelection, flags: int) -> IVBody:
	if selection_.get_flags() & flags:
		return selection_.body
	while selection_.up_selection_name:
		selection_ = get_or_make_selection(selection_.up_selection_name)
		if selection_.get_flags() & flags:
			return selection_.body
	return null


# Non-static methods for this manager's selection or history


func select(selection_: IVSelection, suppress_camera_move := false) -> void:
	if selection == selection_:
		emit_signal("selection_reselected", suppress_camera_move)
		return
	selection = selection_
	_add_history()
	emit_signal("selection_changed", suppress_camera_move)


func select_body(body: IVBody, suppress_camera_move := false) -> void:
	var selection_ := get_or_make_selection(body.name)
	if selection_:
		select(selection_, suppress_camera_move)


func select_by_name(selection_name: String, suppress_camera_move := false) -> void:
	var selection_ := get_or_make_selection(selection_name)
	if selection_:
		select(selection_, suppress_camera_move)


func has_selection() -> bool:
	return selection != null


func get_selection() -> IVSelection:
	return selection


func get_name() -> String:
	return selection.get_name() if selection else ""


func get_gui_name() -> String:
	# return is already translated
	return selection.get_gui_name() if selection else ""


func get_body_name() -> String:
	return selection.get_body_name() if selection else ""
	

func get_texture_2d() -> Texture2D:
	return selection.texture_2d if selection else null


func get_body() -> IVBody:
	return selection.body if selection else null


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
		var new_selection := get_or_make_selection(up_name)
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
			var up_body := get_body_above_selection(selection)
			iteration_array = up_body.satellites
			index = iteration_array.find(current_body)
		SELECTION_STAR:
			 # TODO: code for multistar systems
			var sun: IVBody = IVGlobal.top_bodies[0]
			select_body(sun)
			return
		SELECTION_PLANET:
			var star := get_body_at_above_selection_w_flags(selection, BodyFlags.IS_STAR)
			if !star:
				return
			iteration_array = star.satellites
			var planet := get_body_at_above_selection_w_flags(selection, BodyFlags.IS_PLANET)
			if planet:
				index = iteration_array.find(planet)
				if planet != current_body and incr == 1:
					index -= 1
		SELECTION_NAVIGATOR_MOON, SELECTION_MOON:
			var planet := get_body_at_above_selection_w_flags(selection, BodyFlags.IS_PLANET)
			if !planet:
				return
			iteration_array = planet.satellites
			var moon := get_body_at_above_selection_w_flags(selection, BodyFlags.IS_MOON)
			if moon:
				index = iteration_array.find(moon)
				if moon != current_body and incr == 1:
					index -= 1
		SELECTION_SPACECRAFT:
			if current_body:
				iteration_array = current_body.satellites
			else:
				var up_body := get_body_above_selection(selection)
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
				select = bool(body.flags & BodyFlags.IS_STAR)
			SELECTION_PLANET:
				select = bool(body.flags & BodyFlags.IS_PLANET)
			SELECTION_NAVIGATOR_MOON:
				select = bool(body.flags & BodyFlags.IS_NAVIGATOR_MOON)
			SELECTION_MOON:
				select = bool(body.flags & BodyFlags.IS_MOON)
			SELECTION_SPACECRAFT:
				select = bool(body.flags & BodyFlags.IS_SPACECRAFT)
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


func _clear_selections() -> void:
	_selections.clear() # may be >1 SelectionManager clearing but that's ok

