# hud_label.gd
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
extends Label3D
class_name IVHUDLabel

# IVBody sets its own IVHUDLabel visibility during _process().

var _body_name: String
var _body_symbol: String
var _name_font: Font
var _symbol_font: Font
var _is_symbol_mode: bool


func _init(body_name: String, body_symbol: String, is_symbol_mode := false) -> void:
	_body_name = body_name
	_body_symbol = body_symbol
	_is_symbol_mode = is_symbol_mode
	_name_font = IVGlobal.fonts.hud_names
	_symbol_font = IVGlobal.fonts.hud_symbols


func _ready() -> void:
	horizontal_alignment = ALIGN_CENTER
	vertical_alignment = VALIGN_CENTER
	billboard = SpatialMaterial.BILLBOARD_ENABLED
	fixed_size = true
	pixel_size = 0.0006
	if _is_symbol_mode:
		text = _body_symbol
		font = _symbol_font
	else:
		text = _body_name
		font = _name_font
	hide()


func set_symbol_mode(is_symbol_visible: bool) -> void:
	if _is_symbol_mode == is_symbol_visible:
		return
	_is_symbol_mode = is_symbol_visible
	if is_symbol_visible:
		text = _body_symbol
		font = _symbol_font
	else:
		text = _body_name
		font = _name_font

