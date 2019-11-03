# one_use_confirm.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2019 Charlie Whitfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
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
