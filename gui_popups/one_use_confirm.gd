# one_use_confirm.gd
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
class_name IVOneUseConfirm
extends ConfirmationDialog

var _stop_sim: bool


func _init(text: String, on_confirm_object: Object, on_confirm_method: String,
		args := [], stop_sim := true, window_txt := "", ok_txt := "", cancel_txt := ""):
	connect("confirmed", Callable(on_confirm_object, on_confirm_method).bind(args), CONNECT_ONE_SHOT)
	connect("popup_hide", Callable(self, "_on_hide"))
	dialog_text = text
	exclusive = true
	process_mode = PROCESS_MODE_ALWAYS
	_stop_sim = stop_sim
	if _stop_sim:
		IVGlobal.emit_signal("sim_stop_required", self)
	IVGlobal.program.Universe.add_child(self)
	theme = IVGlobal.themes.main
	if window_txt:
		window_title = window_txt
	if ok_txt:
		var ok_button := get_ok_button()
		ok_button.text = ok_txt
	if cancel_txt:
		var cancel_button := get_cancel_button()
		cancel_button.text = cancel_txt
	var label := get_label()
	label.align = Label.ALIGNMENT_CENTER
	popup_centered()


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled() # eat all keys
		hide()


func _on_hide() -> void:
	if _stop_sim:
		IVGlobal.emit_signal("sim_run_allowed", self)
	queue_free()
