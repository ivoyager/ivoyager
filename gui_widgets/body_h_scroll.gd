# body_h_scroll.gd
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
class_name IVBodyHScroll
extends ScrollContainer

# GUI widget. An ancestor Control node must have property 'selection_manager'
# set to an IVSelectionManager before signal IVGlobal.system_tree_ready.
#
# Parent GUI should add bodies by calling add methods.

const SHOW_IN_NAV_PANEL := IVEnums.BodyFlags.SHOW_IN_NAV_PANEL

var _selection_manager: IVSelectionManager
var _currently_selected: Button
var _body_tables: Array[String] = []
var _button_size := 0.0 # scales with widget height

@onready var _mouse_only_gui_nav: bool = IVGlobal.settings.mouse_only_gui_nav
@onready var _hbox: HBoxContainer = $HBox


func _ready() -> void:
	IVGlobal.system_tree_ready.connect(_on_system_tree_ready)
	IVGlobal.about_to_free_procedural_nodes.connect(_clear)
	resized.connect(_on_resized)
	if IVGlobal.state.is_system_ready:
		_on_system_tree_ready()


func _on_system_tree_ready(_dummy := false) -> void:
	_selection_manager = IVWidgets.get_selection_manager(self)
	for table_name in _body_tables:
		_add_bodies_from_table(table_name)


func add_bodies_from_table(table_name: String) -> void:
	# e.g., 'spacecrafts'
	if IVGlobal.state.is_system_ready:
		_add_bodies_from_table(table_name)
	else:
		_body_tables.append(table_name)


func add_body(body: IVBody) -> void:
	var button := IVNavigationButton.new(body, 10.0, _selection_manager)
	button.selected.connect(_on_nav_button_selected.bind(button))
	button.size_flags_vertical = SIZE_FILL
	button.custom_minimum_size.x = _button_size # button image grows to fit min x
	_hbox.add_child(button)


func _clear() -> void:
	for child in _hbox.get_children():
		child.queue_free()


func _add_bodies_from_table(table_name: String) -> void:
	var table: Dictionary = IVGlobal.tables[table_name]
	var body_names: Array = table.name
	for i in body_names.size():
		var body_name: String = body_names[i]
		var body: IVBody = IVGlobal.bodies.get(body_name)
		if body and body.flags & SHOW_IN_NAV_PANEL:
			add_body(body)


func _on_nav_button_selected(selected: Button) -> void:
	_currently_selected = selected
	if !_mouse_only_gui_nav and !get_viewport().gui_get_focus_owner():
		if selected.focus_mode != FOCUS_NONE:
			selected.grab_focus()


func _on_resized() -> void:
	var button_size := size.y # * 0.7 # 0.7 gives room for scroll bar
	if _button_size == button_size:
		return
	_button_size = button_size
	for child in _hbox.get_children():
		(child as IVNavigationButton).custom_minimum_size.x = button_size

