# mouse_only_gui_nav.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
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
# GUI widget. This exist due to current Godot Engine hard-coding of GUI
# navigation hotkeys, specifically arrow keys (w/out mods). See issue #43663;
# hopefully will be fixed in 4.0. This checkbox widget allows the user to
# prevent GUI from "grabbing" arrow input.
#
# Assumes that focus_mode is initially class-based only (i.e., Button, etc.,
# have focus_mode = FOCUS_ALL).

extends CheckBox

var _settings: Dictionary = Global.settings
onready var _settings_manager: SettingsManager = Global.program.SettingsManager
onready var _project_gui: Control = Global.program.ProjectGUI

var _init_focus_mode_by_class := {} # if not FOCUS_NONE

func _ready():
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator")
	Global.connect("setting_changed", self, "_settings_listener")
	_remember_focus_mode_recursive(_project_gui)
	var mouse_only_gui_nav: bool = _settings.mouse_only_gui_nav
	if pressed == mouse_only_gui_nav:
		_change_focus_mode_recursive(_project_gui, mouse_only_gui_nav)
	else:
		pressed = mouse_only_gui_nav # causes _toggled() call

func _toggled(button_pressed):
	if button_pressed != _settings.mouse_only_gui_nav:
		_settings_manager.change_current("mouse_only_gui_nav", button_pressed)
		_change_focus_mode_recursive(_project_gui, button_pressed)
		print("Toggle change:", button_pressed)

func _on_about_to_start_simulator(_is_new_game: bool) -> void:
	_remember_focus_mode_recursive(_project_gui)
	_change_focus_mode_recursive(_project_gui, pressed)

func _remember_focus_mode_recursive(control: Control) -> void:
	var focus_mode_ := control.get_focus_mode()
	if focus_mode_ != FOCUS_NONE:
		_init_focus_mode_by_class[control.get_class()] = focus_mode_
	for child in control.get_children():
		if child is Control:
			_remember_focus_mode_recursive(child)

func _change_focus_mode_recursive(control: Control, disable: bool) -> void:
#	prints(control.get_focus_mode(), control, control.get_class())
	var control_class: String = control.get_class()
	if _init_focus_mode_by_class.has(control_class):
		if disable:
			control.set_focus_mode(FOCUS_NONE)
		else:
			control.set_focus_mode(_init_focus_mode_by_class[control_class])
	for child in control.get_children():
		if child is Control:
			_change_focus_mode_recursive(child, disable)

func _settings_listener(setting: String, value) -> void:
	match setting:
		"mouse_only_gui_nav":
			if pressed != value:
				pressed = value
				
