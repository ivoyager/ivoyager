# main_menu_manager.gd
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
# Admin GUI's should call make_button() in their project_init().
#
# Note: as of Godot 3.2.3, passing a Reference (rather than a Node) to
# make_button() causes "ObjectDB leaked at exit" errors on quit. This should
# probably be opened as a Godot issue if we can narrow the probelm to a minimal
# project.

extends Reference
class_name MainMenuManager

signal buttons_changed()
signal button_state_changed()

enum {ACTIVE, DISABLED, HIDDEN} # button_state

var button_infos := [] # read-only

func make_button(text: String, priority: int, is_splash_button: bool, is_running_button: bool,
		target_object: Object, target_method: String, target_args := [],
		button_state := ACTIVE) -> void:
	# Highest priority will be top menu item; target_object cannot be a
	# procedural object! See Note above - until this is resolved, it is best
	# to pass Node rather than Reference.
	button_infos.append([text, priority, is_splash_button, is_running_button,
			target_object, target_method, target_args, button_state])
	button_infos.sort_custom(self, "_sort_button_infos")
	emit_signal("buttons_changed")

func remove_button(text: String) -> void:
	var i := 0
	while i < button_infos.size():
		if button_infos[i][0] == text:
			button_infos.remove(i)
			emit_signal("buttons_changed")
			return
		i += 1

func change_button_state(text: String, button_state: int) -> void:
	for button_info in button_infos:
		if text == button_info[0]:
			button_info[7] = button_state
			break
	emit_signal("button_state_changed")

func project_init():
	var state_manager: StateManager = Global.program.StateManager
	var system_builder: SystemBuilder = Global.program.SystemBuilder
	if !Global.skip_splash_screen:
		make_button("BUTTON_START", 1000, true, false, system_builder, "build_system_tree")
		make_button("BUTTON_EXIT", 300, false, true, state_manager, "exit", [false])
	if !Global.disable_quit:
		make_button("BUTTON_QUIT", 200, true, true, state_manager, "quit", [false])

func _sort_button_infos(a: Array, b: Array) -> bool:
	return a[1] > b[1] # priority
