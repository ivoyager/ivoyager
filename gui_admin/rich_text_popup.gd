# rich_text_popup.gd
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
# Generic PopupPanel with RichTextLabel using BBCode.
# BBCode is really limited, but I think improvements are coming in Godot 3.2.

extends PopupPanel
class_name RichTextPopup
const SCENE := "res://ivoyager/gui_admin/rich_text_popup.tscn"

var _main: Main
onready var _header: Label = $VBox/Header
onready var _rt_label: RichTextLabel = $VBox/RTLabel

func project_init() -> void:
	connect("ready", self, "_on_ready")
	connect("popup_hide", self, "_on_popup_hide")
	Global.connect("rich_text_popup_requested", self, "_open")
	_main = Global.objects.Main

func _on_ready() -> void:
	set_process_unhandled_key_input(false)
	$VBox/Close.connect("pressed", self, "hide")

func _open(header_text: String, bbcode_text: String) -> void:
	set_process_unhandled_key_input(true)
	_main.require_stop(self)
	_header.text = header_text
	_rt_label.bbcode_text = bbcode_text
	popup()
	set_anchors_and_margins_preset(PRESET_CENTER, PRESET_MODE_MINSIZE)

func _on_popup_hide() -> void:
	_rt_label.bbcode_text = ""
	set_process_unhandled_key_input(false)
	_main.allow_run(self)

func _unhandled_key_input(event: InputEventKey) -> void:
	_on_unhandled_key_input(event)
	
func _on_unhandled_key_input(event: InputEventKey) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		hide()

