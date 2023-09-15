# sun_slice_button.gd
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
class_name IVSunSliceButton
extends Button

# GUI widget. An ancestor Control node must have property 'selection_manager'
# set to an IVSelectionManager before signal IVGlobal.system_tree_ready.
#
# To use in conjuction with PlanetMoonButtons, make both SIZE_FILL_EXPAND and
# give strech ratios: 1.0 (this widget) and 10.0 (PlanetMoonButtons or
# container that contains PlanetMoonButtons).
#
# This button is coded to mimic buttons in PlanetMoonButtons (that's why it's
# not a TextureButton).

var body_name := &"STAR_SUN"

var _selection_manager: IVSelectionManager # get from ancestor selection_manager
var _body: IVBody
var _is_built := false
var _has_mouse := false

@onready var _texture_rect: TextureRect = $TextureRect


func _ready():
	IVGlobal.about_to_start_simulator.connect(_build)
	IVGlobal.update_gui_requested.connect(_update_selection)
	IVGlobal.about_to_free_procedural_nodes.connect(_clear)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	set_default_cursor_shape(CURSOR_POINTING_HAND)
	_build()


func _pressed() -> void:
	_selection_manager.select_body(_body)


func _build(_dummy := false) -> void:
	if _is_built:
		return
	if !IVGlobal.state.is_system_built:
		return
	_selection_manager = IVSelectionManager.get_selection_manager(self)
	if !_selection_manager:
		return
	_is_built = true
	_body = IVGlobal.bodies[body_name]
	_selection_manager.selection_changed.connect(_update_selection)
	_selection_manager.selection_reselected.connect(_update_selection)
	flat = true
	tooltip_text = _body.name
	_texture_rect.texture = _body.texture_slice_2d
	_update_selection()


func _clear() -> void:
	_selection_manager = null
	_body = null
	_is_built = false
	_has_mouse = false


func _update_selection(_dummy := false) -> void:
	var is_selected := _selection_manager.get_body() == _body
	button_pressed = is_selected
	flat = !is_selected and !_has_mouse


func _on_mouse_entered() -> void:
	_has_mouse = true
	flat = false


func _on_mouse_exited() -> void:
	_has_mouse = false
	flat = !pressed

