# one_use_confirm.gd
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
#

extends ConfirmationDialog
class_name OneUseConfirm

var _stop_sim: bool

func _init(text: String, on_confirm_object: Object, on_confirm_method: String,
		args := [], stop_sim := true):
	connect("confirmed", on_confirm_object, on_confirm_method, args, CONNECT_ONESHOT)
	connect("popup_hide", self, "_on_hide")
	dialog_text = text
	popup_exclusive = true
	_stop_sim = stop_sim
	if _stop_sim:
		Global.emit_signal("require_stop_requested", self)
	Global.objects.GUITop.add_child(self)
	popup_centered()

func _on_hide() -> void:
	if _stop_sim:
		Global.emit_signal("allow_run_requested", self)
	queue_free()

func _unhandled_key_input(event: InputEventKey) -> void:
	get_tree().set_input_as_handled() # eat all keys
	if event.is_action_pressed("ui_cancel"):
		hide()
