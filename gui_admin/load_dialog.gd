# load_dialog.gd
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
extends FileDialog
class_name LoadDialog
const SCENE := "res://ivoyager/gui_admin/load_dialog.tscn"

# project var
var add_quick_load_button := false

var _state: Dictionary = Global.state
var _main: Main
var _quick_load_button: Button

func project_init():
	if !Global.enable_save_load:
		return
	_main = Global.objects.Main
	var main_menu: MainMenu = Global.objects.MainMenu
	main_menu.make_button("BUTTON_LOAD_FILE", 700, true, true, _main, "load_game", [""])
	if add_quick_load_button:
		_quick_load_button = main_menu.make_button("BUTTON_QUICK_LOAD", 600, false, true, _main, "quick_load")
	add_filter("*." + Global.save_file_extension + ";" + Global.save_file_extension_name)
	Global.connect("load_dialog_requested", self, "_open")
	Global.connect("system_tree_ready", self, "_on_system_tree_ready")
	Global.connect("game_save_finished", self, "_on_game_save")
	connect("file_selected", self, "_load_file")
	connect("popup_hide", self, "_on_hide")

func _ready():
	set_process_unhandled_key_input(false)

func _open() -> void:
	set_process_unhandled_key_input(true)
	_main.require_stop(self)
	popup_centered()
	access = ACCESS_FILESYSTEM
	var save_dir := FileHelper.get_save_dir_path(_main.is_modded, Global.settings.save_dir)
	current_dir = save_dir
	if _state.last_save_path:
		current_path = _state.last_save_path
		deselect_items()

func _load_file(path: String) -> void:
	Global.emit_signal("close_main_menu_requested")
	_main.load_game(path)

func _on_hide() -> void:
	set_process_unhandled_key_input(false)
	_main.allow_run(self)

func _on_system_tree_ready(_is_new_game: bool) -> void:
	if _quick_load_button:
		_quick_load_button.disabled = !_state.last_save_path

func _on_game_save() -> void:
	if _quick_load_button:
		_quick_load_button.disabled = !_state.last_save_path

func _unhandled_key_input(event: InputEventKey) -> void:
	_on_unhandled_key_input(event)

func _on_unhandled_key_input(event: InputEventKey) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		hide()
