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


const CALIBRATION := [0.25, 0.375, 0.5, 0.625, 0.75]

var point_range := 5


var _world_targeting: Array = IVGlobal.world_targeting
#var _back_buffer_copy := BackBufferCopy.new()
var _node2d := Node2D.new()
var _delta60 := 0.0

#onready var _viewport := get_tree().root
onready var _root_texture: ViewportTexture = get_tree().root.get_texture()
onready var _src_offset = Vector2.ONE * point_range
onready var _src_length = point_range * 2.0 + 1.0
onready var _src_rect = Rect2(0.0, 0.0, _src_length, _src_length)
onready var _picker_texture: ViewportTexture = get_texture()
onready var _picker_rect = _src_rect



func _ready() -> void:
	usage = USAGE_2D
	render_target_update_mode = UPDATE_ALWAYS
	size = _picker_rect.size
	VisualServer.connect("frame_post_draw", self, "_on_frame_post_draw")
	_node2d.connect("draw", self, "_on_node2d_draw")
	add_child(_node2d)


static func encode(id: int) -> Array:
	assert(id >= 0 and id < 1 << 36) # encodes up to 2^36-1
	var r1 := (id & 15) / 32.0 + 0.25
	id >>= 4
	var g1 := (id & 15) / 32.0 + 0.25
	id >>= 4
	var b1 := (id & 15) / 32.0 + 0.25
	id >>= 4
	var r2 := (id & 15) / 32.0 + 0.25
	id >>= 4
	var g2 := (id & 15) / 32.0 + 0.25
	id >>= 4
	var b2 := (id & 15) / 32.0 + 0.25
	id >>= 4
	var r3 := (id & 15) / 32.0 + 0.25
	id >>= 4
	var g3 := (id & 15) / 32.0 + 0.25
	id >>= 4
	var b3 := (id & 15) / 32.0 + 0.25
	return [Vector3(r1, g1, b1), Vector3(r2, g2, b2), Vector3(r3, g3, b3)]


static func decode(array: Array) -> int:
	var v1: Vector3 = array[0]
	var v2: Vector3 = array[1]
	var v3: Vector3 = array[2]
	var c := int(round((v3[2] - 0.25) * 32.0))
	c <<= 4
	c |= int(round((v3[1] - 0.25) * 32.0))
	c <<= 4
	c |= int(round((v3[0] - 0.25) * 32.0))
	c <<= 4
	c |= int(round((v2[2] - 0.25) * 32.0))
	c <<= 4
	c |= int(round((v2[1] - 0.25) * 32.0))
	c <<= 4
	c |= int(round((v2[0] - 0.25) * 32.0))
	c <<= 4
	c |= int(round((v1[2] - 0.25) * 32.0))
	c <<= 4
	c |= int(round((v1[1] - 0.25) * 32.0))
	c <<= 4
	c |= int(round((v1[0] - 0.25) * 32.0))
	return c



func _on_frame_post_draw() -> void:
	if _world_targeting[6].x < 0.0:
		return
	var picker_image := _picker_texture.get_data()
	picker_image.lock()
#	picker_image.srgb_to_linear()
	var color := picker_image.get_pixel(point_range, point_range)
	_world_targeting[7] = Vector3(color.r, color.g, color.b)
	prints(color)
	_node2d.update()


func _on_node2d_draw() -> void:
	if _world_targeting[6].x < 0.0:
		return
	_src_rect.position = _world_targeting[6] - _src_offset # mouse_coord
	_node2d.draw_texture_rect_region(_root_texture, _picker_rect, _src_rect)
	



