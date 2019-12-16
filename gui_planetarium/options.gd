# options.gd
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

onready var _tree_manager: TreeManager = Global.objects.TreeManager
onready var _points_manager: PointsManager = Global.objects.PointsManager
onready var _hypertext: RichTextLabel = $Hypertext
onready var _asteroids_checkbox: CheckBox = $Asteroids/CheckBox
onready var _orbits_checkbox: CheckBox = $Orbits/CheckBox
onready var _labels_checkbox: CheckBox = $Labels/CheckBox
onready var _icons_checkbox: CheckBox = $Icons/CheckBox
onready var _viewport := get_viewport()
var _is_mouse_button_pressed := false
var _tr_help := tr("LABEL_HELP")
var _tr_options := tr("LABEL_OPTIONS")
var _tr_hotkeys := tr("LABEL_HOTKEYS")
var _tr_credits := tr("LABEL_CREDITS")

func _ready() -> void:
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator")
	_hypertext.connect("meta_clicked", self, "_on_meta_clicked")
	_asteroids_checkbox.connect("toggled", self, "_toggle_asteroids")
	_orbits_checkbox.connect("toggled", _tree_manager, "set_show_orbits")
	_labels_checkbox.connect("toggled", _tree_manager, "set_show_labels")
	_icons_checkbox.connect("toggled", _tree_manager, "set_show_icons")
	_tree_manager.connect("show_orbits_changed", self, "_update_show_orbits")
	_tree_manager.connect("show_labels_changed", self, "_update_show_labels")
	_tree_manager.connect("show_icons_changed", self, "_update_show_icons")
#	set_anchors_and_margins_preset(PRESET_BOTTOM_RIGHT, PRESET_MODE_MINSIZE)
	_hypertext.bbcode_text = "[url]%s[/url]\n[url]%s[/url]\n[url]%s[/url]\n[url]%s[/url]" \
			% [_tr_help, _tr_options, _tr_hotkeys, _tr_credits]
	hide()

func _on_about_to_start_simulator(_is_new_game: bool) -> void:
	get_parent().register_mouse_trigger_guis(self, [self])
	show()

func _on_meta_clicked(meta: String) -> void:
	match meta:
		_tr_help:
			var bbcode_text = "\n[b]Mouse[/b]\n[indent]Left-button drag to move around the target object.\n"
			bbcode_text += "Right-button* drag near center to pan left, right, up or down.\n"
			bbcode_text += "Right-button* drag near edge to rotate.\n"
			bbcode_text += "(*Cntr + mouse button on Mac.)\n[/indent]"
			bbcode_text += "\n[b]Controls & Links[/b]\n"
			bbcode_text += "[indent]Navigator - lower left\n"
			bbcode_text += "Settings - lower right\n"
			bbcode_text += "Time Control - upper left\n"
			bbcode_text += "Selection Options - upper middle\n"
			bbcode_text += "Homepage - upper right\n[/indent]"
			Global.emit_signal("rich_text_popup_requested", "LABEL_HELP", bbcode_text)
		_tr_options:
			Global.emit_signal("options_requested")
		_tr_hotkeys:
			Global.emit_signal("hotkeys_requested")
		_tr_credits:
			Global.emit_signal("credits_requested")

func _toggle_asteroids(pressed: bool) -> void:
	_points_manager.show_points("all_asteroids", pressed)

func _update_show_orbits(is_show: bool) -> void:
	_orbits_checkbox.pressed = is_show

func _update_show_labels(is_show: bool) -> void:
	_labels_checkbox.pressed = is_show

func _update_show_icons(is_show: bool) -> void:
	_icons_checkbox.pressed = is_show
