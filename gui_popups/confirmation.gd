# confirmation.gd
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
class_name IVConfirmation
extends ConfirmationDialog
const SCENE := "res://ivoyager/gui_popups/confirmation.tscn"

# Call using IVGlobal.confirmation_requested.emit(args).

var _stop_sim: bool
var _confirm_action: Callable


func _ready() -> void:
	IVGlobal.confirmation_requested.connect(_on_confirmation_requested)
	confirmed.connect(_on_confirmed)
	canceled.connect(_on_canceled)
	focus_exited.connect(_keep_focus)
	#popup_hide.connect(_on_popup_hide)
	exclusive = true
	transient = false
	always_on_top = true
#	theme = IVGlobal.themes.main
	get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		set_input_as_handled()


func _on_confirmation_requested(text: String, confirm_action: Callable, stop_sim := true,
		title_txt := "LABEL_PLEASE_CONFIRM", ok_txt := "BUTTON_OK", cancel_txt := "BUTTON_CANCEL"
		) -> void:
	# stop_sim can be overridden by IVGlobal.popops_can_stop_sim == false
	_stop_sim = stop_sim and IVGlobal.popops_can_stop_sim
	_confirm_action = confirm_action
	dialog_text = text
	title = title_txt
	ok_button_text = ok_txt
	cancel_button_text = cancel_txt
	if _stop_sim:
		IVGlobal.sim_stop_required.emit(self)
	popup_centered()
	_keep_focus()


func _on_confirmed() -> void:
	if _stop_sim:
		IVGlobal.sim_run_allowed.emit(self)
	_confirm_action.call()


func _on_canceled() -> void:
	if _stop_sim:
		IVGlobal.sim_run_allowed.emit(self)


func _keep_focus() -> void:
	await get_tree().process_frame
	if !has_focus():
		grab_focus()

