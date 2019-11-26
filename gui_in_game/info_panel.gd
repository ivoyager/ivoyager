# info_panel.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2019 Charlie Whitfield
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

extends DraggablePanel
class_name InfoPanel
const SCENE := "res://ivoyager/gui_in_game/info_panel.tscn"

signal selection_connected(selection_manager)

const REFRESH_SECONDS := 2
const SUBPANEL_SIZE := Vector2(550 - 13, 340 - 64)

# ***************************** PERSISTED *************************************

var selection_manager: SelectionManager
var subpanel_index := -1
var subpanels_persist := []

# persistence
const PERSIST_PROPERTIES_2 := ["subpanel_index", "subpanels_persist"]
const PERSIST_OBJ_PROPERTIES_2 := ["selection_manager"]

# ***************************** UNPERSISTED ***********************************

# project var - modify on "gui_entered_tree" signal
var subpanel_classes := [
	InfoSubpanelWiki,
]

var _subpanels := [] # scripts initially; nodes if/when accessed
var _subpanel_buttons := []
var _subpanel_container: Container


func update_selection() -> void:
	_toggle_subpanels(subpanel_index != -1, subpanel_index)
	
func grab_subpanel_persist_data() -> void:
	for i in range(_subpanels.size()):
		if _subpanels[i] is Node:
			_subpanels[i].prepare_persist_data()
			subpanels_persist[i] = _subpanels[i].subpanel_persist.duplicate()

# ******************** VIRTUAL & PRIVATE FUNCTIONS ****************************

func _on_ready() -> void:
	._on_ready()
	_subpanel_container = $VBox/Subpanel
	Global.connect("about_to_start_simulator", self, "_start_sim")
	Global.connect("game_save_started", self, "grab_subpanel_persist_data")
	_subpanels = subpanel_classes.duplicate()
	for i in range(_subpanels.size()):
		var subpanel_button := Button.new()
		_subpanel_buttons.append(subpanel_button)
		subpanel_button.text = _subpanels[i].BUTTON_TEXT
		subpanel_button.toggle_mode = true
		subpanel_button.connect("toggled", self, "_toggle_subpanels", [i])
		$VBox/BCButtons.add_child(subpanel_button)
		subpanels_persist.append([])
	$VBox/BCButtons.columns = _subpanels.size()
	if Global.state.is_running:
		_toggle_subpanels(subpanel_index != -1, subpanel_index)
	selection_manager.connect("selection_changed", self, "update_selection")
	for i in range(_subpanels.size()):
		if _subpanels[i] is Node and subpanels_persist[i]: # subpanel active & we have some data
			_subpanels[i].subpanel_persist = subpanels_persist[i].duplicate()
			_subpanels[i].load_persist_data()

func _prepare_for_deletion() -> void:
	._prepare_for_deletion()
	Global.disconnect("about_to_start_simulator", self, "_start_sim")
	Global.disconnect("game_save_started", self, "grab_subpanel_persist_data")
	_subpanels.clear()
	_subpanel_buttons.clear()

func _start_sim(_is_new_game: bool) -> void:
	_toggle_subpanels(subpanel_index != -1, subpanel_index)

func _toggle_subpanels(button_pressed, index) -> void:
	var header_text := ""
	var minimize := true
	var bottom_edge := rect_position.y + rect_size.y
	if !button_pressed:
		index = -1
		subpanel_index = -1
	for i in range(_subpanels.size()):
		var hide_subpanel := true
		var availability: int = _subpanels[i].get_availability(selection_manager)
		if availability == InfoSubpanel.HIDDEN:
			_subpanel_buttons[i].hide()
		elif availability == InfoSubpanel.DISABLED:
			_subpanel_buttons[i].show()
			_subpanel_buttons[i].disabled = true
			_subpanel_buttons[i].pressed = (i == index)
		elif i != index: # enabled but not selected
			_subpanel_buttons[i].show()
			_subpanel_buttons[i].disabled = false
			_subpanel_buttons[i].pressed = false
		else: # enabled & selected
			_subpanel_buttons[i].show()
			_subpanel_buttons[i].disabled = false
			_subpanel_buttons[i].pressed = true
			if not _subpanels[i] is Node: # instance this subpanel
				_subpanels[i] = SaverLoader.make_object_or_scene(subpanel_classes[i])
				_subpanels[i].rect_min_size = SUBPANEL_SIZE
				_subpanel_container.add_child(_subpanels[i])
				_subpanels[i].owner = self
			_subpanels[i].init_selection()
			header_text = _subpanels[i].header_text
			_subpanels[i].show()
			hide_subpanel = false
			subpanel_index = i
			minimize = false
		if hide_subpanel and _subpanels[i] is Node:
			_subpanels[i].hide()
	if minimize:
		_subpanel_container.rect_min_size = Vector2.ZERO
		_subpanel_container.hide()
		_subpanel_container.rect_size = Vector2.ZERO
		$VBox/SelectedBox.hide()
		rect_size = Vector2.ZERO # causes immediate size update
		rect_position.y = bottom_edge - rect_size.y
	else:
		_subpanel_container.rect_min_size = SUBPANEL_SIZE
		_subpanel_container.show()
		$VBox/SelectedBox.show()
		finish_move()
	if header_text:
		$VBox/SelectedBox/Selected.text = header_text
	else:
		$VBox/SelectedBox/Selected.text = selection_manager.get_name()

