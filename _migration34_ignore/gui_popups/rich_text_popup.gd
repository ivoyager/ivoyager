# rich_text_popup.gd
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
class_name IVRichTextPopup
extends PopupPanel
const SCENE := "res://ivoyager/gui_popups/rich_text_popup.tscn"

# Generic PopupPanel with RichTextLabel using BBCode.
# BBCode is really limited, but I think improvements are coming in Godot 3.2.

var stop_sim := true

var _blocking_popups: Array = IVGlobal.blocking_popups
var _state_manager: IVStateManager

@onready var _header: Label = $VBox/Header
@onready var _rt_label: RichTextLabel = $VBox/RTLabel


func _project_init() -> void:
	connect("popup_hide", Callable(self, "_on_popup_hide"))
	IVGlobal.connect("rich_text_popup_requested", Callable(self, "_open"))
	_state_manager = IVGlobal.program.StateManager


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	theme = IVGlobal.themes.main
	$VBox/Close.connect("pressed", Callable(self, "hide"))
	_blocking_popups.append(self)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()


func _open(header_text: String, text: String) -> void:
	if _is_blocking_popup():
		return
	if stop_sim:
		_state_manager.require_stop(self)
	_header.text = header_text
	_rt_label.text = tr(text)
	popup()
	set_anchors_and_offsets_preset(PRESET_CENTER, PRESET_MODE_MINSIZE)


func _on_popup_hide() -> void:
	_rt_label.text = ""
	if stop_sim:
		_state_manager.allow_run(self)


func _is_blocking_popup() -> bool:
	for popup in _blocking_popups:
		if popup.visible:
			return true
	return false
