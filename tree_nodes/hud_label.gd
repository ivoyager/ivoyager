# hud_label.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield
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
# Body sets its own HUDLabel visibility during _process().

extends Label
class_name HUDLabel

var _body_name: String
var _body_symbol: String
var _name_font: Font
var _symbol_font: Font
onready var _huds_manager: HUDsManager = Global.program.HUDsManager

func set_body_name(body_name: String) -> void:
	_body_name = body_name

func set_body_symbol(body_symbol: String) -> void:
	_body_symbol = body_symbol

func _ready() -> void:
	_huds_manager.connect("show_huds_changed", self, "_on_show_huds_changed")
	_name_font = Global.fonts.hud_names
	_symbol_font = Global.fonts.hud_symbols
	align = ALIGN_CENTER
	valign = VALIGN_CENTER

func _on_show_huds_changed() -> void:
	if _huds_manager.show_names:
		text = _body_name
		set("custom_fonts/font", _name_font)
	elif _huds_manager.show_symbols:
		text = _body_symbol
		set("custom_fonts/font", _symbol_font)
