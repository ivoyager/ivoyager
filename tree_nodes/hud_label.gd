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

# Visual text name or symbol for a Body.

var _body_huds_visibility: IVBodyHUDsVisibility = IVGlobal.program.BodyHUDsVisibility
var _body: IVBody
var _body_flags: int
var _body_name: String
var _body_symbol: String
var _name_font: Font
var _symbol_font: Font
var _names_visible := false
var _symbols_visible := false
var _body_huds_visible := false # too close / too far


func _init(body: IVBody) -> void:
	_body = body
	_body_flags = body.flags
	_body_name = body.get_hud_name()
	_body_symbol = body.get_symbol()
	_name_font = IVGlobal.fonts.hud_names
	_symbol_font = IVGlobal.fonts.hud_symbols


func _ready() -> void:
	_body_huds_visibility.connect("visibility_changed", self, "_on_global_huds_changed")
	_body.connect("huds_visibility_changed", self, "_on_body_huds_changed")
	horizontal_alignment = ALIGN_CENTER
	vertical_alignment = VALIGN_CENTER
	billboard = SpatialMaterial.BILLBOARD_ENABLED
	
	fixed_size = true
	pixel_size = 0.0006 # FIXME: Check this!
	
	_body_huds_visible = _body.huds_visible
	_on_global_huds_changed()


func _on_global_huds_changed() -> void:
	_names_visible = _body_huds_visibility.is_name_visible(_body_flags)
	_symbols_visible = !_names_visible and _body_huds_visibility.is_symbol_visible(_body_flags)
	_set_visual_state()


func _on_body_huds_changed(is_visible: bool) -> void:
	_body_huds_visible = is_visible
	_set_visual_state()


func _set_visual_state() -> void:
	if !_body_huds_visible:
		visible = false
		return
	if _names_visible:
		text = _body_name
		font = _name_font
		visible = true
	elif _symbols_visible:
		text = _body_symbol
		font = _symbol_font
		visible = true
	else:
		visible = false

