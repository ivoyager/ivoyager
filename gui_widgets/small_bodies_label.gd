# small_bodies_label.gd
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
class_name IVSmallBodiesLabel
extends Label

# Requires IVPointPicker and IVSmallBodiesManager. Operates in screen position
# so add as child to Universe or a full screen Control.


var offset := Vector2(0.0, -7.0) # negative y offset to not interfere w/ PointPicker

var _world_targeting: Array = IVGlobal.world_targeting
var _small_bodies_infos: Dictionary


func _ready() -> void:
	var point_picker: IVPointPicker = IVGlobal.program.PointPicker
	point_picker.connect("target_point_changed", self, "_on_target_point_changed")
	var small_bodies_manager: IVSmallBodiesManager = IVGlobal.program.SmallBodiesManager
	_small_bodies_infos = small_bodies_manager.infos
	hide()


func _on_target_point_changed(id: int) -> void:
	if id == -1:
		hide()
		return
	show()
	text = _small_bodies_infos[id][0]
	rect_position = _world_targeting[0] + offset + Vector2(-rect_size.x / 2.0, -rect_size.y)
	yield(get_tree(), "idle_frame")
	rect_size.x = 0.0
	rect_position = _world_targeting[0] + offset + Vector2(-rect_size.x / 2.0, -rect_size.y)
