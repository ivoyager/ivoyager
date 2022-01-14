# sun_slice_button.gd
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
extends Button

# GUI widget.
#
# To use in conjuction with PlanetMoonButtons, make both SIZE_FILL_EXPAND and
# give strech ratios: 1.0 (this widget) and 10.0 (PlanetMoonButtons or
# container that contains PlanetMoonButtons).
#
# This button is coded to mimic buttons in PlanetMoonButtons (that's why it's
# not a TextureButton).

var _has_mouse := false
var _selection_manager: IVSelectionManager # get from ancestor selection_manager
var _selection_item: IVSelectionItem

onready var _texture_rect: TextureRect = $TextureRect
onready var _body_registry: IVBodyRegistry = IVGlobal.program.BodyRegistry


func _ready():
	IVGlobal.connect("about_to_start_simulator", self, "_build")
	IVGlobal.connect("update_gui_needed", self, "_update_selection")
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_clear")
	connect("mouse_entered", self, "_on_mouse_entered")
	connect("mouse_exited", self, "_on_mouse_exited")
	set_default_cursor_shape(CURSOR_POINTING_HAND)


func _build(_is_new_game: bool) -> void:
	_clear()
	_selection_manager = IVGUIUtils.get_selection_manager(self)
	assert(_selection_manager)
	var sun: IVBody = _body_registry.top_bodies[0]
	_selection_item = _body_registry.get_selection_for_body(sun)
	_selection_manager.connect("selection_changed", self, "_update_selection")
	flat = true
	hint_tooltip = _selection_item.name
	_texture_rect.texture = _selection_item.texture_slice_2d


func _pressed() -> void:
	_selection_manager.select(_selection_item)


func _clear() -> void:
	_selection_manager = null
	_selection_item = null
	_has_mouse = false


func _update_selection() -> void:
	var is_selected := _selection_manager.selection_item == _selection_item
	pressed = is_selected
	flat = !is_selected and !_has_mouse


func _on_mouse_entered() -> void:
	_has_mouse = true
	flat = false


func _on_mouse_exited() -> void:
	_has_mouse = false
	flat = !pressed
