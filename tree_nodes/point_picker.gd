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
extends Viewport

var point_range := 5


var _world_targeting: Array = IVGlobal.world_targeting
var _node2d := Node2D.new()
var _delta60 := 0.0
var _picker_image: Image

#onready var _viewport := get_tree().root
onready var _root_texture: ViewportTexture = get_tree().root.get_texture()
onready var _src_offset = Vector2.ONE * point_range
onready var _src_length = point_range * 2.0 + 1.0
onready var _src_rect = Rect2(0.0, 0.0, _src_length, _src_length)
onready var _picker_rect = _src_rect


func _ready() -> void:
	print(self, " ready...")
	
	usage = USAGE_2D
	render_target_update_mode = UPDATE_ALWAYS
	size = _picker_rect.size
	
	
	VisualServer.connect("frame_post_draw", self, "_on_frame_post_draw")
	_node2d.connect("draw", self, "_on_node2d_draw")
	add_child(_node2d)


func _process(delta: float) -> void:
	_delta60 = delta * 60.0
	_node2d.update()
	if !_picker_image:
		return
	
	prints(_picker_image.get_pixel(point_range, point_range), _delta60)
	


func _on_frame_post_draw() -> void:
	if _world_targeting[6].x < 0.0:
		_picker_image = null
		return
	_picker_image = get_texture().get_data()
	_picker_image.lock()
	


func _on_node2d_draw() -> void:
	if _world_targeting[6].x < 0.0:
		_picker_image = null
		return
	_src_rect.position = _world_targeting[6] - _src_offset # mouse_coord
	_node2d.draw_texture_rect_region(_root_texture, _picker_rect, _src_rect)
	



