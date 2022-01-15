# rich_text_popup.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2022 Charlie Whitfield
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
class_name IVRichTextPopup
extends PopupPanel
const SCENE := "res://ivoyager/gui_admin/rich_text_popup.tscn"

# Generic PopupPanel with RichTextLabel using BBCode.
# BBCode is really limited, but I think improvements are coming in Godot 3.2.

var stop_sim := true

var _state_manager: IVStateManager

onready var _header: Label = $VBox/Header
onready var _rt_label: RichTextLabel = $VBox/RTLabel


func _project_init() -> void:
	connect("popup_hide", self, "_on_popup_hide")
	IVGlobal.connect("rich_text_popup_requested", self, "_open")
	_state_manager = IVGlobal.program.StateManager


func _ready() -> void:
	theme = IVGlobal.themes.main
	set_process_unhandled_key_input(false)
	$VBox/Close.connect("pressed", self, "hide")


func _unhandled_key_input(event: InputEventKey) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		hide()


func _open(header_text: String, bbcode_text: String) -> void:
	set_process_unhandled_key_input(true)
	if stop_sim:
		_state_manager.require_stop(self)
	_header.text = header_text
	_rt_label.bbcode_text = tr(bbcode_text)
	popup()
	set_anchors_and_margins_preset(PRESET_CENTER, PRESET_MODE_MINSIZE)


func _on_popup_hide() -> void:
	_rt_label.bbcode_text = ""
	set_process_unhandled_key_input(false)
	if stop_sim:
		_state_manager.allow_run(self)
