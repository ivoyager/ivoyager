# input_handler.gd
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
class_name IVInputHandler
extends Node

# Handles input for classes that don't handle their own. This is mainly for
# Windows (Popups & Dialogs) that don't recieve input passed in the root
# Window.


func _unhandled_key_input(event: InputEvent) -> void:
	
	if event.is_action_pressed(&"ui_cancel"):
		IVGlobal.open_main_menu_requested.emit()
	elif event.is_action_pressed(&"toggle_options"):
		IVGlobal.options_requested.emit()
	elif event.is_action_pressed(&"toggle_hotkeys"):
		IVGlobal.hotkeys_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()

