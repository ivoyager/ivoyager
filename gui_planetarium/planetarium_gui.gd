# planetarium_gui.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
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
var _is_mouse_button_pressed := false
var _homepage_link := RichTextLabel.new()

func project_init() -> void:
	Global.connect("system_tree_built_or_loaded", self,
			"_on_system_tree_built_or_loaded", [], CONNECT_ONESHOT)

func _ready() -> void:
	_homepage_link.bbcode_enabled = true
	_homepage_link.bbcode_text = "[url]I, Voyager[/url]"
	_homepage_link.meta_underlined = true
	_homepage_link.scroll_active = false
	_homepage_link.rect_min_size = Vector2(100.0, 35.0)
	_homepage_link.connect("meta_clicked", self, "_on_homepage_clicked")
	var main_menu: MainMenu = Global.program.MainMenu
	main_menu.add_child(_homepage_link)
	main_menu.set_anchors_and_margins_preset(Control.PRESET_TOP_RIGHT,
			Control.PRESET_MODE_MINSIZE, 16)

func _on_system_tree_built_or_loaded(_is_new_game: bool) -> void:
	selection_manager = _SelectionManager_.new()
	var registrar: Registrar = Global.program.Registrar
	var start_selection: SelectionItem = registrar.selection_items[Global.start_body_name]
	selection_manager.select(start_selection)
	# reparent MainMenu here for visibility control
	var main_menu: MainMenu = Global.program.MainMenu
	main_menu.get_parent().remove_child(main_menu)
	add_child(main_menu)

	

func _input(event: InputEvent) -> void:
	# By default, all children of this node are shown/hidden by mouse position.
	# For fine control, use members mouse_trigger & mouse_visible
	if event is InputEventMouseMotion:
		if _is_mouse_button_pressed or !visible:
			return
		var mouse_pos: Vector2 = event.position
		for child in get_children():
			if not "mouse_trigger" in child:
				var is_visible := _is_visible(child, mouse_pos)
				if is_visible == child.visible:
					continue
				child.visible = is_visible
				child.mouse_filter = MOUSE_FILTER_PASS if is_visible else MOUSE_FILTER_IGNORE
			else:
				var mouse_visible: Array = child.mouse_visible
				if !mouse_visible:
					continue
				var mouse_trigger: Control = child.mouse_trigger
				var is_visible := _is_visible(mouse_trigger, mouse_pos)
				if is_visible == mouse_visible[0].visible:
					continue
				for gui in mouse_visible:
					gui.visible = is_visible
					gui.mouse_filter = MOUSE_FILTER_PASS if is_visible else MOUSE_FILTER_IGNORE
	elif event is InputEventMouseButton:
		_is_mouse_button_pressed = event.pressed # don't show/hide GUIs during mouse drag

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
