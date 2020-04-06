# planetarium_gui.gd
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
# Constructor and parent for Planetarium-style GUIs.

extends Control
class_name PlanetariumGUI
const SCENE := "res://ivoyager/gui_planetarium/planetarium_gui.tscn"

var selection_manager: SelectionManager

onready var _SelectionManager_: Script = Global.script_classes._SelectionManager_
onready var _viewport := get_viewport()
var _mouse_trigger_guis := []
var _is_mouse_button_pressed := false
var _homepage_link := RichTextLabel.new()

func project_init() -> void:
	Global.connect("system_tree_built_or_loaded", self, "_on_system_tree_built_or_loaded", [], CONNECT_ONESHOT)

func register_mouse_trigger_guis(mouse_trigger: Control, guis: Array) -> void:
	_mouse_trigger_guis.append([mouse_trigger, guis])

func _ready() -> void:
	_homepage_link.bbcode_enabled = true
	_homepage_link.bbcode_text = "[url]I, Voyager[/url]"
	_homepage_link.meta_underlined = true
	_homepage_link.scroll_active = false
	_homepage_link.rect_min_size = Vector2(100.0, 35.0)
	_homepage_link.connect("meta_clicked", self, "_on_homepage_clicked")
	var main_menu: MainMenu = Global.program.MainMenu
	main_menu.add_child(_homepage_link)
	main_menu.margin_top = 7.0
	main_menu.margin_left = 14.0
	register_mouse_trigger_guis(main_menu, [main_menu])

func _on_system_tree_built_or_loaded(_is_new_game: bool) -> void:
	selection_manager = _SelectionManager_.new()
	selection_manager.init_as_camera_selection()
	var registrar: Registrar = Global.program.Registrar
	var start_selection: SelectionItem = registrar.selection_items[Global.start_body_name]
	selection_manager.select(start_selection)

func _input(event: InputEvent) -> void:
	if event.is_action_type():
		if event.is_pressed():
			if event.is_action_pressed("toggle_full_screen"):
				if visible:
					hide()
					for mouse_trigger_gui in _mouse_trigger_guis:
						var guis: Array = mouse_trigger_gui[1]
						for gui in guis:
							gui.hide()
				else:
					show()
			elif event.is_action_pressed("ui_cancel"):
				show()
	elif event is InputEventMouseMotion:
		if _is_mouse_button_pressed or !visible:
			return
		var mouse_pos := _viewport.get_mouse_position()
		for mouse_trigger_gui in _mouse_trigger_guis:
			var mouse_trigger: Control = mouse_trigger_gui[0]
			var guis: Array = mouse_trigger_gui[1]
			var is_visible := _is_visible(mouse_trigger, mouse_pos)
			if is_visible != guis[0].visible:
				for gui in guis:
					gui.visible = is_visible
					gui.mouse_filter = MOUSE_FILTER_PASS if is_visible else MOUSE_FILTER_IGNORE
	elif event is InputEventMouseButton:
		_is_mouse_button_pressed = event.pressed

func _is_visible(trigger: Control, pos: Vector2) -> bool:
	var rect := trigger.get_global_rect()
	if trigger.anchor_left != ANCHOR_BEGIN and pos.x < rect.position.x:
		return false
	if trigger.anchor_right != ANCHOR_END and pos.x > rect.end.x:
		return false
	if trigger.anchor_top != ANCHOR_BEGIN and pos.y < rect.position.y:
		return false
	if trigger.anchor_bottom != ANCHOR_END and pos.y > rect.end.y:
		return false
	return true

func _on_homepage_clicked(_meta: String) -> void:
	OS.shell_open("https://ivoyager.dev")
