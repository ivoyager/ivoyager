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
extends VBoxContainer

# GUI widget that saves current view. This widget is contained in
# IVViewSavePopup and works in conjunction with IVViewSaveFlow (which shows
# the resultant saved view buttons).

signal view_saved(view_name)


var default_view_name := "LABEL_CUSTOM1" # will increment if taken
var set_name := ""
var is_cached := true
var show_flags := IVView.ALL
var reserved_names := []

@onready var _view_manager: IVViewManager = IVGlobal.program.ViewManager
@onready var _selection_ckbx: CheckBox = $"%SelectionCkbx"
@onready var _longitude_ckbx: CheckBox = $"%LongitudeCkbx"
@onready var _orientation_ckbx: CheckBox = $"%OrientationCkbx"
@onready var _visibilities_ckbx: CheckBox = $"%VisibilitiesCkbx"
@onready var _colors_ckbx: CheckBox = $"%ColorsCkbx"
@onready var _time_ckbx: CheckBox = $"%TimeCkbx"
@onready var _now_ckbx: CheckBox = $"%NowCkbx" # exclusive w/ _time_ckbx
@onready var _line_edit: LineEdit = $"%LineEdit"


func _ready() -> void:
	_line_edit.text = tr(default_view_name)
	connect("visibility_changed", Callable(self, "_on_visibility_changed"))
	$"%SaveButton".connect("pressed", Callable(self, "_on_save"))
	_line_edit.connect("text_submitted", Callable(self, "_on_save"))
	if !IVGlobal.allow_time_setting:
		_time_ckbx.text = "CKBX_GAME_SPEED" # this is the only 'time' element that can be modified


func init(default_view_name_ := "LABEL_CUSTOM1", set_name_ := "", is_cached_ := true,
		show_flags_ := IVView.ALL, init_flags := IVView.ALL, reserved_names_ := []) -> void:
	# Called by IVViewSaveButton in standard setup.
	# Make 'set_name_' unique to not share views with other GUI instances. 
	default_view_name = default_view_name_
	set_name = set_name_
	is_cached = is_cached_
	show_flags = show_flags_
	reserved_names = reserved_names_
	_line_edit.text = tr(default_view_name)
	_increment_name_as_needed()
	
	# init checkboxes
	if init_flags & IVView.TIME_STATE:
		init_flags &= ~IVView.IS_NOW # exclusive
	
	_selection_ckbx.visible = bool(show_flags & IVView.CAMERA_SELECTION)
	_longitude_ckbx.visible = bool(show_flags & IVView.CAMERA_LONGITUDE)
	_orientation_ckbx.visible = bool(show_flags & IVView.CAMERA_ORIENTATION)
	_visibilities_ckbx.visible = bool(show_flags & IVView.HUDS_VISIBILITY)
	_colors_ckbx.visible = bool(show_flags & IVView.HUDS_COLOR)
	_time_ckbx.visible = bool(show_flags & IVView.TIME_STATE)
	_now_ckbx.visible = bool(show_flags & IVView.IS_NOW) and IVGlobal.allow_time_setting
	
	if _time_ckbx.visible and _now_ckbx.visible:
		_time_ckbx.connect("toggled", Callable(self, "_unset_exclusive").bind(_now_ckbx))
		_now_ckbx.connect("toggled", Callable(self, "_unset_exclusive").bind(_time_ckbx))
	
	_selection_ckbx.set_pressed_no_signal(bool(show_flags & init_flags & IVView.CAMERA_SELECTION))
	_longitude_ckbx.set_pressed_no_signal(bool(show_flags & init_flags & IVView.CAMERA_LONGITUDE))
	_orientation_ckbx.set_pressed_no_signal(bool(show_flags & init_flags & IVView.CAMERA_ORIENTATION))
	_visibilities_ckbx.set_pressed_no_signal(bool(show_flags & init_flags & IVView.HUDS_VISIBILITY))
	_colors_ckbx.set_pressed_no_signal(bool(show_flags & init_flags & IVView.HUDS_COLOR))
	_time_ckbx.set_pressed_no_signal(bool(show_flags & init_flags & IVView.TIME_STATE))
	_now_ckbx.set_pressed_no_signal(bool(show_flags & init_flags & IVView.IS_NOW)
			and IVGlobal.allow_time_setting)


func _unset_exclusive(is_pressed: bool, exclusive_button: CheckBox) -> void:
	if is_pressed:
		exclusive_button.button_pressed = false


func _on_visibility_changed():
	if is_visible_in_tree():
		_increment_name_as_needed()
		_line_edit.select_all()
		_line_edit.set_caret_column(100)
		_line_edit.call_deferred("grab_focus")


func _on_save(_dummy := "") -> void:
	_increment_name_as_needed()
	var flags := _get_view_flags()
	_view_manager.save_view(_line_edit.text, set_name, is_cached, flags)
	emit_signal("view_saved", _line_edit.text)


func _increment_name_as_needed() -> void:
	if !_line_edit.text:
		_line_edit.text = "1"
	var text := _line_edit.text
	if !_view_manager.has_view(text, set_name, is_cached) and !reserved_names.has(text):
		return
	if !text[-1].is_valid_int():
		_line_edit.text += "2"
	elif text[-1] == "9":
		_line_edit.text[-1] = "1"
		_line_edit.text += "0"
	else:
		_line_edit.text[-1] = str(int(text[-1]) + 1)
	_increment_name_as_needed()


func _get_view_flags() -> int:
	var flags := 0
	if _selection_ckbx.pressed:
		flags |= IVView.CAMERA_SELECTION
	if _longitude_ckbx.pressed:
		flags |= IVView.CAMERA_LONGITUDE
	if _orientation_ckbx.pressed:
		flags |= IVView.CAMERA_ORIENTATION
	if _visibilities_ckbx.pressed:
		flags |= IVView.HUDS_VISIBILITY
	if _colors_ckbx.pressed:
		flags |= IVView.HUDS_COLOR
	if _time_ckbx.pressed:
		flags |= IVView.TIME_STATE
	if _now_ckbx.pressed:
		flags |= IVView.IS_NOW
	return flags

