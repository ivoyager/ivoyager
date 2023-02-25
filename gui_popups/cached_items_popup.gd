# cashed_items_popup.gd
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
class_name IVCachedItemsPopup
extends PopupPanel
const SCENE := "res://ivoyager/gui_popups/cached_items_popup.tscn"

# Abstract base class for user interface with cached items. I, Voyager
# subclasses: IVOptionsPopup, IVHotkeysPopup.

var stop_sim := true
var layout: Array # subclass sets in _init()

var _header_left: MarginContainer
var _header_label: Label
var _header_right: MarginContainer
var _content_container: HBoxContainer
var _cancel: Button
var _confirm_changes: Button
var _restore_defaults: Button
var _blocking_popups: Array = IVGlobal.blocking_popups

onready var _state_manager: IVStateManager = IVGlobal.program.StateManager


# virtual & overridable virtual functions

func _init():
	_on_init()


func _on_init():
	pass


func _project_init() -> void:
	pass


func _ready():
	_on_ready()


func _on_ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS
	connect("popup_hide", self, "_on_popup_hide")
	IVGlobal.connect("close_all_admin_popups_requested", self, "hide")
	theme = IVGlobal.themes.main
	_header_left = $VBox/TopHBox/HeaderLeft
	_header_label = $VBox/TopHBox/HeaderLabel
	_header_right = $VBox/TopHBox/HeaderRight
	_content_container = $VBox/Content
	_cancel = $VBox/BottomHBox/Cancel
	_confirm_changes = $VBox/BottomHBox/ConfirmChanges
	_restore_defaults = $VBox/BottomHBox/RestoreDefaults
	_cancel.connect("pressed", self, "_on_cancel")
	_restore_defaults.connect("pressed", self, "_on_restore_defaults")
	_confirm_changes.connect("pressed", self, "_on_confirm_changes")
	_blocking_popups.append(self)


func _unhandled_key_input(event: InputEventKey) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		_on_cancel()


# public

func add_subpanel(subpanel_dict: Dictionary, to_column: int, to_row := 999) -> void:
	# See example subpanel_dict formats in IVOptionsPopup or IVHotkeysPopup.
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


# private

func _open() -> void:
	if _is_blocking_popup():
		return
	if stop_sim:
		_state_manager.require_stop(self)
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
		IVOneUseConfirm.new("LABEL_DISCARD_CHANGES", self, "_on_cancel_changes")


func _on_popup_hide() -> void:
	for child in _content_container.get_children():
		child.free()
	if stop_sim:
		_state_manager.allow_run(self)


func _is_blocking_popup() -> bool:
	for popup in _blocking_popups:
		if popup.visible:
			return true
	return false
