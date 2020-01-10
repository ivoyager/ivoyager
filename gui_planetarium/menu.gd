# menu.gd
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

extends VBoxContainer

func _ready() -> void:
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator", [], CONNECT_ONESHOT)
	$Homepage.connect("meta_clicked", self, "_on_homepage_clicked")
	$Help.connect("pressed", Global, "emit_signal", ["rich_text_popup_requested", "LABEL_HELP", "TXT_PLANETARIUM_HELP"])
	$Hotkeys.connect("pressed", Global, "emit_signal", ["hotkeys_requested"])
	$Options.connect("pressed", Global, "emit_signal", ["options_requested"])
	$Credits.connect("pressed", Global, "emit_signal", ["credits_requested"])
	if Global.disable_quit:
		$Quit.hide()
	get_parent().register_mouse_trigger_guis(self, [self])
	set_anchors_and_margins_preset(PRESET_TOP_LEFT, PRESET_MODE_MINSIZE)
	rect_position.x += 15
	rect_position.y += 7

func _on_about_to_start_simulator(_is_new_game: bool) -> void:
	if !Global.disable_quit:
		var main: Main = Global.objects.Main
		$Quit.connect("pressed", main, "quit", [true])

func _on_homepage_clicked(_meta: String) -> void:
	OS.shell_open("https://ivoyager.dev")

