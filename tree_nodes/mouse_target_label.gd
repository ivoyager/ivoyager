# mouse_target_label.gd
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
class_name IVMouseTargetLabel
extends Label

# Uses IVWorldController and (if present) IVFragmentIdentifier.

var offset := Vector2(0.0, -7.0) # offset to not interfere w/ FragmentIdentifier

var _world_targeting: Array = IVGlobal.world_targeting
var _fragment_data: Dictionary

var _object_text := ""
var _fragment_text := ""

var _is_object := false
var _fragment_id := -1


func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS
	var world_controller: IVWorldController = IVGlobal.program.WorldController
	world_controller.connect("mouse_target_changed", self, "_on_mouse_target_changed")
	var fragment_identifier: IVFragmentIdentifier = IVGlobal.program.get("FragmentIdentifier")
	if fragment_identifier:
		fragment_identifier.connect("fragment_changed", self, "_on_fragment_changed")
		_fragment_data = fragment_identifier.fragment_data
	set("custom_fonts/font", IVGlobal.fonts.hud_names)
	align = ALIGN_CENTER
	grow_horizontal = GROW_DIRECTION_BOTH
	size_flags_horizontal = SIZE_SHRINK_CENTER
	hide()


func _process(_delta: float) -> void:
	if _world_targeting[7] == CURSOR_MOVE:
		hide()
		return
	if _object_text: # has priority over fragment
		text = _object_text
	elif _fragment_text:
		text = _fragment_text
	else:
		hide()
		return
	show()
	rect_position = _world_targeting[0] + offset + Vector2(-rect_size.x / 2.0, -rect_size.y)


func _on_mouse_target_changed(object: Object) -> void:
	if !object:
		_object_text = ""
		return
	_object_text = object.name # any valid target will have 'name'


func _on_fragment_changed(id: int) -> void:
	if id == -1:
		_fragment_text = ""
		return
	var data: Array = _fragment_data[id]
	var instance_id: int = data[0]
	var target_object := instance_from_id(instance_id)
	_fragment_text = target_object.get_fragment_text(data)

