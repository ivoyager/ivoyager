# point_picker.gd
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
class_name IVPointPicker
extends BackBufferCopy

var range_vector := Vector2(50.0, 50.0)

var _world_targeting: Array = IVGlobal.world_targeting


func _ready() -> void:
	print(self, " ready...")
	copy_mode = COPY_MODE_RECT


func _process(_delta: float) -> void:
	var mouse_coord: Vector2 = _world_targeting[6]
	rect = Rect2(mouse_coord - range_vector, range_vector * 2.0)
	
	print(get_canvas_item())


