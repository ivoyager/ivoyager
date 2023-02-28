# view_saver.gd
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
class_name IVViewSaver
extends HBoxContainer

# GUI widget that saves current view. This widget is contained in
# IVViewSavePopup and works in conjunction with IVViewCollection (which shows
# the resultant saved view buttons).


signal view_saved(view_name)


var default_view_name := "LABEL_CUSTOM_1" # will increment if taken
var set_name := "view_saver"
var is_cached := true
var view_flags := IVViewManager.ALL_VIEW_STATE

onready var _view_manager: IVViewManager = IVGlobal.program.ViewManager
onready var _line_edit: LineEdit = $LineEdit

func _ready() -> void:
	_line_edit.text = tr(default_view_name)
	connect("visibility_changed", self, "_on_visibility_changed")
	$SaveButton.connect("pressed", self, "_on_save")
	_line_edit.connect("text_entered", self, "_on_save")


func init(default_view_name_ := "LABEL_CUSTOM_1", set_name_ := "view_saver", is_cached_ := true,
		view_flags_ := IVViewManager.ALL_VIEW_STATE) -> void:
	default_view_name = default_view_name_
	set_name = set_name_
	is_cached = is_cached_
	view_flags = view_flags_
	_line_edit.text = tr(default_view_name)
	_increment_name_as_needed()
	_hide_unused_states()


func _hide_unused_states() -> void:
	$CameraCkbx.visible = bool(view_flags & IVViewManager.CAMERA_STATE)
	$VisibilitiesCkbx.visible = bool(view_flags & IVViewManager.HUDS_VISIBILITY_STATE)
	$ColorsCkbx.visible = bool(view_flags & IVViewManager.HUDS_COLOR_STATE)
	$TimeCkbx.visible = bool(view_flags & IVViewManager.TIME_STATE)


func _on_visibility_changed():
	if is_visible_in_tree():
		_increment_name_as_needed()


func _on_save(_dummy := "") -> void:
	_increment_name_as_needed()
	var flags := _get_view_flags()
	_view_manager.save_view(_line_edit.text, set_name, is_cached, flags)
	emit_signal("view_saved", _line_edit.text)


func _increment_name_as_needed() -> void:
	if !_line_edit.text:
		_line_edit.text = "1"
	if !_view_manager.has_view(_line_edit.text, set_name, is_cached):
		return
	if !_line_edit.text[-1].is_valid_integer():
		_line_edit.text += "2"
	elif _line_edit.text[-1] == "9":
		_line_edit.text[-1] = "1"
		_line_edit.text += "0"
	else:
		_line_edit.text[-1] = str(int(_line_edit.text[-1]) + 1)
	_increment_name_as_needed()


func _get_view_flags() -> int:
	var flags := 0
	if $CameraCkbx.pressed and $CameraCkbx.visible:
		flags |= IVViewManager.CAMERA_STATE
	if $VisibilitiesCkbx.pressed and $VisibilitiesCkbx.visible:
		flags |= IVViewManager.HUDS_VISIBILITY_STATE
	if $ColorsCkbx.pressed and $ColorsCkbx.visible:
		flags |= IVViewManager.HUDS_COLOR_STATE
	if $TimeCkbx.pressed and $TimeCkbx.visible:
		flags |= IVViewManager.TIME_STATE
	return flags

