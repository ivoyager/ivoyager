# point_picker_label.gd
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
extends Label

# Requires IVPointPicker. Add as child to GUI top Control.

var offset := Vector2(0.0, -10.0) # need some negative y offset to not interfere w/ shader id

var _world_targeting: Array = IVGlobal.world_targeting
var _names: Dictionary


func _ready() -> void:
	var point_picker: IVPointPicker = IVGlobal.program.PointPicker
	point_picker.connect("target_point_changed", self, "_on_target_point_changed")
	_names = point_picker.names
	hide()


func _on_target_point_changed(id: int) -> void:
	if id == -1:
		hide()
		return
	show()
	text = _names[id]
	rect_position = _world_targeting[0] + offset + Vector2(-rect_size.x / 2.0, -rect_size.y)
	yield(get_tree(), "idle_frame")
	rect_size.x = 0.0
	rect_position = _world_targeting[0] + offset + Vector2(-rect_size.x / 2.0, -rect_size.y)

