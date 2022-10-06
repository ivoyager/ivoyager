# navigation_button.gd
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
class_name IVNavigationButton

# This widget must be instantiated and added by code.

signal selected()

var _selection_manager: IVSelectionManager
var _body: IVBody # this button
var _has_mouse := false


func _init(body: IVBody, image_size: float, selection_manager: IVSelectionManager) -> void:
	assert(body and selection_manager)
	_body = body
	_selection_manager = selection_manager
	hint_tooltip = body.name
	set("custom_fonts/font", IVGlobal.fonts.two_pt) # hack to allow smaller button height
	rect_min_size = Vector2(image_size, image_size)
	var texture_box := TextureRect.new()
	texture_box.set_anchors_and_margins_preset(PRESET_WIDE, PRESET_MODE_KEEP_SIZE, 0)
	texture_box.expand = true
	texture_box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_box.texture = body.texture_2d
	texture_box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(texture_box)
	connect("mouse_entered", self, "_on_mouse_entered")
	connect("mouse_exited", self, "_on_mouse_exited")


func _ready():
	IVGlobal.connect("update_gui_requested", self, "_update_selection")
	_selection_manager.connect("selection_changed", self, "_update_selection")
	_selection_manager.connect("selection_reselected", self, "_update_selection")
	set_default_cursor_shape(CURSOR_POINTING_HAND)


func _pressed() -> void:
	_selection_manager.select_body(_body)


func _update_selection() -> void:
	var is_selected := _selection_manager.get_body() == _body
	pressed = is_selected
	if is_selected:
		emit_signal("selected")
	flat = !is_selected and !_has_mouse


func _on_mouse_entered() -> void:
	_has_mouse = true
	flat = false


func _on_mouse_exited() -> void:
	_has_mouse = false
	flat = !pressed

