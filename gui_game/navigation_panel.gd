# navigation_panel.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2020 Charlie Whitfield
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

extends DraggablePanel
class_name NavigationPanel
const SCENE := "res://ivoyager/gui_game/navigation_panel.tscn"

func _on_ready() -> void:
	._on_ready()
	if Global.objects.has("MainMenu"):
		$BottomVBox/BottomHBox/MainMenu.connect("pressed", Global, "emit_signal", ["open_main_menu_requested"])
	else:
		$BottomVBox/BottomHBox/MainMenu.hide()
	if Global.objects.has("HotkeysPopup"):
		$BottomVBox/BottomHBox/Hotkeys.connect("pressed", Global, "emit_signal", ["hotkeys_requested"])
	else:
		$BottomVBox/BottomHBox/Hotkeys.hide()
