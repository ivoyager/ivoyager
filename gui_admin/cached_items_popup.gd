# cashed_items_popup.gd
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
# Abstract base class for user interface with cached items. I, Voyager
# subclasses: OptionsPopup, HotkeysPopup.

extends PopupPanel
class_name CachedItemsPopup
const SCENE := "res://ivoyager/gui_admin/cached_items_popup.tscn"

var layout: Array # subclass sets in _init()

var _main: Main
var _header: Label
var _aux_button: Button
var _spacer: Control
var _content_container: HBoxContainer
var _cancel: Button
var _confirm_changes: Button
var _restore_defaults: Button


func add_subpanel(subpanel_dict: Dictionary, to_column: int, to_row := 999) -> void:
	# See example subpanel_dict formats in OptionsPopup or HotkeysPopup.
	# Set to_column and/or to_row arbitrarily large to move to end.
	if to_column >= layout.size():
		to_column = layout.size()
		layout.append([])
	var column_array: Array = layout[to_column]
	if to_row >= column_array.size():
		to_row = column_array.size()
	column_array.insert(to_row, subpanel_dict)

func remove_subpanel(header: String) -> Dictionary:
	for column_array in layout:
		var dict_index := 0
		while dict_index < column_array.size():
			var subpanel_dict: Dictionary = column_array[dict_index]
			if subpanel_dict.header == header:
				column_array.remove(dict_index)
				return subpanel_dict
			dict_index += 1
	print("Could not find subpanel with header ", header)
	return {}

func move_subpanel(header: String, to_column: int, to_row: int) -> void:
	# to_column and/or to_row can be arbitrarily big to move to end
	var subpanel_dict := remove_subpanel(header)
	if subpanel_dict:
		add_subpanel(subpanel_dict, to_column, to_row)

func add_item(item: String, setting_label_str: String, header: String, at_index := 999) -> void:
	# use add_subpanel() instead if subpanel doesn't exist already.
	assert(item != "header")
	for column_array in layout:
		var dict_index := 0
		while dict_index < column_array.size():
			var subpanel_dict: Dictionary = column_array[dict_index]
			if subpanel_dict.header == header:
				if at_index >= subpanel_dict.size() - 1:
					subpanel_dict[item] = setting_label_str
					return
				# Dictionaries are ordered but there is no insert!
				var new_subpanel_dict := {}
				var index := 0
				for key in subpanel_dict:
					new_subpanel_dict[key] = subpanel_dict[key] # 1st is header
					if index == at_index:
						new_subpanel_dict[item] = setting_label_str
					index += 1
				column_array[dict_index] = new_subpanel_dict
				return
			dict_index += 1
	print("Could not find Options subpanel with header ", header)

func remove_item(item: String) -> void:
	assert(item != "header")
	for column_array in layout:
		var dict_index := 0
		while dict_index < column_array.size():
			var subpanel_dict: Dictionary = column_array[dict_index]
			subpanel_dict.erase(item)
			if subpanel_dict.size() == 1: # only header remains
				column_array.remove(dict_index)
				dict_index -= 1
			dict_index += 1

func _init():
	_on_init()

func _on_init():
	pass

func project_init() -> void:
	_main = Global.objects.Main
	connect("ready", self, "_on_ready")
	connect("popup_hide", self, "_on_popup_hide")

func _on_ready() -> void:
	set_process_unhandled_key_input(false)
	_header = $VBox/TopHBox/Header
	_aux_button = $VBox/TopHBox/AuxButton
	_spacer = $VBox/TopHBox/Spacer
	_content_container = $VBox/Content
	_cancel = $VBox/BottomHBox/Cancel
	_confirm_changes = $VBox/BottomHBox/ConfirmChanges
	_restore_defaults = $VBox/BottomHBox/RestoreDefaults
	_cancel.connect("pressed", self, "_on_cancel")
	_restore_defaults.connect("pressed", self, "_on_restore_defaults")
	_confirm_changes.connect("pressed", self, "_on_confirm_changes")

func _open() -> void:
	set_process_unhandled_key_input(true)
	_main.require_stop(self)
	_build_content()
	popup()
	set_anchors_and_margins_preset(PRESET_CENTER, PRESET_MODE_MINSIZE)

func _build_content() -> void:
	for child in _content_container.get_children():
		child.free()
	for column_array in layout:
		var column_vbox := VBoxContainer.new()
		_content_container.add_child(column_vbox)
		for subpanel_dict in column_array:
			var subpanel_container := PanelContainer.new()
			column_vbox.add_child(subpanel_container)
			var subpanel_vbox := VBoxContainer.new()
			subpanel_container.add_child(subpanel_vbox)
			var header_label := Label.new()
			subpanel_vbox.add_child(header_label)
			header_label.align = Label.ALIGN_CENTER
			header_label.text = subpanel_dict.header
			for item in subpanel_dict:
				if item != "header":
					var setting_hbox := _build_item(item, subpanel_dict[item])
					subpanel_vbox.add_child(setting_hbox)
	_on_content_built()

func _build_item(_item: String, _item_label_str: String) -> HBoxContainer:
	# subclass must override!
	return HBoxContainer.new()

func _on_content_built() -> void:
	# subclass logic
	pass

func _on_restore_defaults() -> void:
	# subclass logic
	call_deferred("_build_content")

func _on_confirm_changes() -> void:
	# subclass logic
	hide()

func _on_cancel_changes() -> void:
	# subclass logic
	hide()

func _on_cancel() -> void:
	if _confirm_changes.disabled:
		hide()
	else:
		OneUseConfirm.new("LABEL_DISCARD_CHANGES", self, "_on_cancel_changes")

func _on_popup_hide() -> void:
	set_process_unhandled_key_input(false)
	for child in _content_container.get_children():
		child.free()
	_main.allow_run(self)

func _unhandled_key_input(event: InputEventKey) -> void:
	_on_unhandled_key_input(event)
	
func _on_unhandled_key_input(event: InputEventKey) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		_on_cancel()

