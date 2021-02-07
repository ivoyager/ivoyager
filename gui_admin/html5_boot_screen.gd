# html5_boot_screen.gd
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
# This breaks some I, Voyager project conventions so we can display early.

extends HBoxContainer

func _ready():
	var font_data: DynamicFontData = Global.assets.primary_font_data
	var font := DynamicFont.new()
	font.font_data = font_data
	font.size = 26
	var load_message: Label = $VBox/LoadMessage
	load_message.set("custom_fonts/font", font)
	var pbd_caption: Label = $VBox/PBDCaption
	pbd_caption.set("custom_fonts/font", font)
	# Actual Earth pixel sample: c8a0de
	# This one from beam (lightened): ffbdee
	pbd_caption.set("custom_colors/font_color", Color("c8a0de"))
