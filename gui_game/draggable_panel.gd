# draggable_panel.gd
# This file is part of I, Voyager
# https://ivoyager.dev
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
#
# Abstract base class extended by I, Voyager GUI panels.
extends PanelContainer
class_name DraggablePanel

# *************************** SETTINGS ****************************************

const DPRINT := false
const SNAP_DIST := 100.0

# ***************************** VARS ******************************************

# persistence
const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["anchor_left", "anchor_right", "anchor_top", "anchor_bottom"]

enum {LEFT, RIGHT, UP, DOWN}

var _tree: SceneTree = Global.program.tree
var _viewport: Viewport = Global.program.root
var _draggable: bool
var _gui_panels: Array
var _drag_point := Vector2.ZERO
var _inited_for_viewport_size := Vector2()
var _disable_drag := false
var _resolve_overlap_counter := 0

# ************************* PUBLIC FUNCTIONS **********************************

func init(draggable: bool, gui_panels: Array, selection_manager_: SelectionManager) -> void:
	# Argument "selection_manager_" is null if this is loaded game. If panel
	# has its own SelectionManager then panel must persist it. 
	_draggable = draggable
	_gui_panels = gui_panels
	if selection_manager_ and "selection_manager" in self:
		self.selection_manager = selection_manager_

static func is_overlap(pos1: Vector2, size1: Vector2, pos2: Vector2, size2: Vector2) -> bool:
	if pos1.x + size1.x <= pos2.x:
		return false
	if pos1.x >= pos2.x + size2.x:
		return false
	if pos1.y + size1.y <= pos2.y:
		return false
	if pos1.y >= pos2.y + size2.y:
		return false
	return true

func finish_move(snap_and_anchor := true, resolve_overlaps := true) -> void:
	assert(DPRINT and prints(name, "finish_move()") or true)
	_drag_point = Vector2.ZERO
	if snap_and_anchor:
		_snap_and_anchor()
	if resolve_overlaps:
		_resolve_overlaps()

# ****************** VIRTUAL & PRIVATE FUNCTIONS ******************************

func _enter_tree():
	_on_enter_tree()

func _on_enter_tree():
	connect("ready", self, "_on_ready")
	connect("gui_input", self, "_on_gui_input")
	Global.connect("about_to_free_procedural_nodes", self, "_prepare_to_free", [], CONNECT_ONESHOT)
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator", [], CONNECT_ONESHOT)
	Global.connect("gui_refresh_requested", self, "_fit_to_viewport")
	Global.program.root.connect("size_changed", self, "finish_move")
	Global.emit_signal("gui_entered_tree", self)

func _on_ready() -> void:
	Global.call_deferred("emit_signal", "gui_ready", self)

func _prepare_to_free() -> void:
	Global.disconnect("gui_refresh_requested", self, "_fit_to_viewport")
	Global.program.root.disconnect("size_changed", self, "finish_move")

func _on_gui_input(event: InputEvent) -> void:
	if _disable_drag or !_draggable:
		return
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			accept_event()
			if event.pressed:
				_drag_point = get_global_mouse_position() - rect_position
			else:
				finish_move()
	elif event is InputEventMouseMotion and _drag_point:
		accept_event()
		rect_position = get_global_mouse_position() - _drag_point

func _on_about_to_start_simulator(_is_new_game: bool) -> void:
	_reposition_to_anchor()

func _reposition_to_anchor() -> void:
	assert(DPRINT and prints(name, "_reposition_to_anchor()") or true)
	if anchor_left == ANCHOR_BEGIN:
		rect_position.x = 0.0
	elif anchor_left == ANCHOR_END:
		rect_position.x = _viewport.size.x - rect_size.x
	else:
		rect_position.x = anchor_left * _viewport.size.x - rect_size.x / 2.0
	if anchor_top == ANCHOR_BEGIN:
		rect_position.y = 0.0
	elif anchor_top == ANCHOR_END:
		rect_position.y = _viewport.size.y - rect_size.y
	else:
		rect_position.y = anchor_top * _viewport.size.y - rect_size.y / 2.0

func _fit_to_viewport() -> void:
	assert(DPRINT and prints(name, "_fit_to_viewport()") or true)
	# Only one panel positions all so we can control order
	if _inited_for_viewport_size == _viewport.size:
		return
	
	yield(_tree, "idle_frame") # delay in case there is resizing from ui refresh
	var corners := []
	var edges := []
	for gui_panel in _gui_panels:
		if fmod(gui_panel.anchor_left, 1.0) == 0.0 and fmod(gui_panel.anchor_top, 1.0) == 0.0: # corners
			gui_panel.finish_move(true, false)
			corners.append(gui_panel)
			gui_panel._inited_for_viewport_size = _viewport.size
	for gui_panel in _gui_panels:
		if gui_panel._inited_for_viewport_size != _viewport.size and \
				(fmod(gui_panel.anchor_left, 1.0) == 0.0 or fmod(gui_panel.anchor_top, 1.0) == 0.0): # edges
			gui_panel.finish_move(true, false)
			edges.append(gui_panel)
			gui_panel._inited_for_viewport_size = _viewport.size
	for gui_panel in _gui_panels:
		if gui_panel._inited_for_viewport_size != _viewport.size: # all others
			gui_panel.finish_move(true, true)
			gui_panel._inited_for_viewport_size = _viewport.size
	for gui_panel in edges:
		gui_panel.finish_move(false, true)
	for gui_panel in corners:
		gui_panel.finish_move(false, true)

func _snap_and_anchor() -> void:
	assert(DPRINT and prints(name, "_snap_and_anchor()") or true)
	var viewport_size = _viewport.size
	if rect_position.x < SNAP_DIST:
		rect_position.x = 0.0
		anchor_left = ANCHOR_BEGIN
		anchor_right = ANCHOR_BEGIN
	elif rect_position.x > viewport_size.x - rect_size.x - SNAP_DIST:
		rect_position.x = viewport_size.x - rect_size.x
		anchor_left = ANCHOR_END
		anchor_right = ANCHOR_END
	else:
		var lr_anchor = (rect_position.x + rect_size.x / 2.0) / viewport_size.x
		anchor_left = lr_anchor
		anchor_right = lr_anchor
	if rect_position.y < SNAP_DIST:
		rect_position.y = 0.0
		anchor_top = ANCHOR_BEGIN
		anchor_bottom = ANCHOR_BEGIN
	elif rect_position.y > viewport_size.y - rect_size.y - SNAP_DIST:
		rect_position.y = viewport_size.y - rect_size.y
		anchor_top = ANCHOR_END
		anchor_bottom = ANCHOR_END
	else:
		var tb_anchor = (rect_position.y + rect_size.y / 2.0) / viewport_size.y
		anchor_top = tb_anchor
		anchor_bottom = tb_anchor

func _resolve_overlaps() -> void:
	assert(DPRINT and prints(name, "_resolve_overlaps()") or true)
	var resolved := true
	for loop_gui in _gui_panels:
		if loop_gui != self:
			if is_overlap(rect_position, rect_size, loop_gui.rect_position, loop_gui.rect_size):
				resolved = _fix_overlap(loop_gui)
				break # only try to fix one overlap at a time
	if resolved:
		_resolve_overlap_counter = 0
	elif _resolve_overlap_counter > 10:
		_resolve_overlap_counter = 0
		print("Failed to resolve UI panel overlaps!")
	else:
		_resolve_overlap_counter += 1
		assert(DPRINT and prints("recursion:", _resolve_overlap_counter) or true)
		_resolve_overlaps() # keep trying until it's good or we give up

func _fix_overlap(other_gui) -> bool:
	assert(DPRINT and prints(name, "_fix_overlap()") or true)
	# Sort prefered directions based on overlaps & do first valid move (if any)
	var prefered_direction = rect_position + rect_size - other_gui.rect_position - other_gui.rect_size
	prefered_direction.x *= rect_size.y + other_gui.rect_size.y # tall wants to go left/right
	prefered_direction.y *= rect_size.x + other_gui.rect_size.x # wide wants to go up/down
	var moves := _get_moves(prefered_direction)
	for move in moves:
		match move:
			UP:
				var new_y: float = other_gui.rect_position.y - rect_size.y
				if _is_valid_position(Vector2(rect_position.x, new_y)):
					rect_position.y = new_y
					return true
			DOWN:
				var new_y: float = other_gui.rect_position.y + other_gui.rect_size.y
				if _is_valid_position(Vector2(rect_position.x, new_y)):
					rect_position.y = new_y
					return true
			LEFT:
				var new_x: float = other_gui.rect_position.x - rect_size.x
				if _is_valid_position(Vector2(new_x, rect_position.y)):
					rect_position.x = new_x
					return true
			RIGHT:
				var new_x: float = other_gui.rect_position.x + other_gui.rect_size.x
				if _is_valid_position(Vector2(new_x, rect_position.y)):
					rect_position.x = new_x
					return true
	# There is no valid move: move toward screen center and report failure
	prefered_direction = _viewport.size - (2.0 * rect_position + rect_size)
	prefered_direction = prefered_direction.normalized() * 50
	rect_position += prefered_direction
	return false

func _get_moves(prefered_direction) -> Array:
#	assert(DPRINT and prints(name, "_get_moves()") or true)
	var moves: Array
	if prefered_direction.x < 0.0:
		moves = [LEFT, RIGHT] # prioritize left
	else:
		moves = [RIGHT, LEFT]
	if abs(prefered_direction.x) < abs(prefered_direction.y):
		if prefered_direction.y < 0.0:
			moves.push_front(UP) # prioritize up
			moves.append(DOWN)
		else:
			moves.push_front(DOWN)
			moves.append(UP)
	else:
		if prefered_direction.y < 0.0:
			moves.insert(1, UP) # up takes second place
			moves.insert(2, DOWN)
		else:
			moves.insert(1, DOWN)
			moves.insert(2, UP)
	return moves # an ordered array of the 4 directions to try

func _is_valid_position(test_pos) -> bool:
#	assert(DPRINT and prints(name, "_is_valid_position()") or true)
	var viewport_size = _viewport.size
	if test_pos.x < 0.0 or test_pos.x + rect_size.x > viewport_size.x:
		return false
	if test_pos.y < 0.0 or test_pos.y + rect_size.y > viewport_size.y:
		return false
	for loop_gui in _gui_panels:
		if loop_gui != self:
			if is_overlap(test_pos, rect_size, loop_gui.rect_position, loop_gui.rect_size):
				return false
	return true
