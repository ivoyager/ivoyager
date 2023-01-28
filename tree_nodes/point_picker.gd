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

# Decodes shader object points (e.g., asteroids) for selection.

const math := preload("res://ivoyager/static/math.gd")
const CALIBRATION := [0.25, 0.375, 0.5, 0.625, 0.75]
const COLOR_HALF_STEP := Color(1.0/32.0, 1.0/32.0, 1.0/32.0, 0.0)


var point_range := 5


var _world_targeting: Array = IVGlobal.world_targeting
var _node2d := Node2D.new()
var _delta60 := 0.0

var _calibration_size := CALIBRATION.size()
var _cycle_step := 0
var _calibration_colors := []
var _value_colors := []
var _last_id := -1

# TODO: pre-quadratic fit



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
	add_child(_node2d)
	_node2d.connect("draw", self, "_on_node2d_draw")
	VisualServer.connect("frame_post_draw", self, "_on_frame_post_draw")
	_calibration_colors.resize(_calibration_size)
	_value_colors.resize(3)
	
#	# test encode/decode
#	var test := [0, 1000, 12345678, 99999999, 68_719_476_735]
#	for i in test.size():
#		print(decode(encode(test[i])))

#	# test quadratic fit
#	var x := [1.0, 3.0, 5.0, 7.0, 9.0]
#	var y := [32.5, 37.3, 36.4, 32.4, 28.5]
#	print(IVMath.quadratic_fit(x, y)) # [-0.366071, 3.015714, 30.421786]
	
	print(vector2id(id2vector(68_719_476_735)))


func _on_node2d_draw() -> void:
	if _world_targeting[6].x < 0.0:
		return
	_src_rect.position = _world_targeting[6] - _src_offset # mouse_coord
	_node2d.draw_texture_rect_region(_root_texture, _picker_rect, _src_rect)


func _on_frame_post_draw() -> void:
	if _world_targeting[6].x < 0.0:
		return
	var picker_image := _picker_texture.get_data()
	picker_image.lock()
#	picker_image.srgb_to_linear()
	var color := picker_image.get_pixel(point_range, point_range)
	var id := _detect_id_signal(color)
	if id != -1:
		if id >= 0:
#			prints(IVUtils.binary_str(id), id)
			print(id)
		elif id != _last_id:
			print(id)
		_last_id = id
	
	
#	prints(color, id)
	
	_node2d.update()


func _detect_id_signal(color: Color) -> int:
	# -1, we are processing a potential signal; -2, broken signal.
	# Signals start with a monotonic calibration series, followed by 3 id-
	# encoding colors. Black pixel always interupts. Returns an id if cycle
	# completes. Spurious ids should be rare.
	if !color: # black
		_cycle_step = 0
		return -2 # interupt
	
	# start calibration
	if _cycle_step == 0:
		_calibration_colors[0] = color
		_cycle_step = 1
		return -1 # processing
	
	# continue calibration (interupt/restart if nonmonotonic)
	if _cycle_step < _calibration_size:
		var last: Color = _calibration_colors[_cycle_step - 1]
		if last.r < color.r and last.g < color.g and last.b < color.b:
			_calibration_colors[_cycle_step] = color
			_cycle_step += 1
			return -1 # processing
		else:
			_calibration_colors[0] = color
			_cycle_step = 1
			return -2 # interupt
	
	# collect values (interupt/restart if out of calibration range)
	var min_color: Color = _calibration_colors[0] - COLOR_HALF_STEP
	var max_color: Color = _calibration_colors[_calibration_size - 1] + COLOR_HALF_STEP
	if (color.r < min_color.r or color.g < min_color.g or color.b < min_color.b
			or color.r > max_color.r or color.g > max_color.g or color.b > max_color.b):
		_calibration_colors[0] = color
		_cycle_step = 1
		return -2 # interupt
	_value_colors[_cycle_step - _calibration_size] = color
	_cycle_step += 1
	if _cycle_step < _calibration_size + 3:
		return -1 # processing
	
	# end of cycle, calibrate & decode
	_cycle_step = 0
	var data := get_calibrated_data(_calibration_colors, _value_colors)
	var id := decode(data)
	return id if id >= 0 else -2 # spurious negatives are possible


static func encode(id: int) -> Array:
	# Here for reference; this is the id encode logic used by point shaders.
	# We only use 4 bits of info per 8-bit color channel. All colors are
	# generated in the range 0.25-0.75 (losing 1 bit) and we ignore the least
	# significant 3 bits. So we only need detect 1/16 color steps after
	# calibration. Three colors encode id giving range 0 to 2^36-1.
	# TODO: recode using 3 bits x 4 colors (x3) for same id range?
	assert(id >= 0 and id < (1 << 36))
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
	return [r1, g1, b1, r2, g2, b2, r3, g3, b3]


static func decode(array: Array) -> int:
	var c := int(round((array[8] - 0.25) * 32.0))
	c <<= 4
	c |= int(round((array[7] - 0.25) * 32.0))
	c <<= 4
	c |= int(round((array[6] - 0.25) * 32.0))
	c <<= 4
	c |= int(round((array[5] - 0.25) * 32.0))
	c <<= 4
	c |= int(round((array[4] - 0.25) * 32.0))
	c <<= 4
	c |= int(round((array[3] - 0.25) * 32.0))
	c <<= 4
	c |= int(round((array[2] - 0.25) * 32.0))
	c <<= 4
	c |= int(round((array[1] - 0.25) * 32.0))
	c <<= 4
	c |= int(round((array[0] - 0.25) * 32.0))
	return c


func get_calibrated_data(calibration_colors: Array, value_colors: Array) -> Array:
	# generate calibration coefficients
	var n := CALIBRATION.size()
	assert(calibration_colors.size() == n)
	assert(value_colors.size() == 3)
	var calibration_r := []
	var calibration_g := []
	var calibration_b := []
	for i in n:
		var color: Color = calibration_colors[i]
		calibration_r.append(color.r)
		calibration_g.append(color.g)
		calibration_b.append(color.b)
	var r_coeffs := math.quadratic_fit(calibration_r, CALIBRATION)
	var g_coeffs := math.quadratic_fit(calibration_g, CALIBRATION)
	var b_coeffs := math.quadratic_fit(calibration_b, CALIBRATION)
	
	# calibrate values
	var color1: Color = value_colors[0]
	var color2: Color = value_colors[1]
	var color3: Color = value_colors[2]
	var r1 := math.quadratic(color1.r, r_coeffs)
	var r2 := math.quadratic(color2.r, r_coeffs)
	var r3 := math.quadratic(color3.r, r_coeffs)
	var g1 := math.quadratic(color1.g, g_coeffs)
	var g2 := math.quadratic(color2.g, g_coeffs)
	var g3 := math.quadratic(color3.g, g_coeffs)
	var b1 := math.quadratic(color1.b, b_coeffs)
	var b2 := math.quadratic(color2.b, b_coeffs)
	var b3 := math.quadratic(color3.b, b_coeffs)
	
	return [r1, g1, b1, r2, g2, b2, r3, g3, b3]


static func id2vector(id: int) -> Vector3:
	# sutable for GUI shader floats
	assert(id >= 0 and id < (1 << 36)) # up to 68_719_476_735
	var int1 := id & 4095 # 1 << 12 - 1
	id >> 12
	var int2 := id & 4095
	id >> 12
	var int3 := id & 4095
	return Vector3(float(int1), float(int2), float(int3))


static func vector2id(vector: Vector3) -> int:
	# 12 bits per elements, for 36 bits
	var int1 := int(vector.x)
	var int2 := int(vector.y)
	var int3 := int(vector.z)
	assert(int1 >= 0 and int1 < 1 << 12)
	assert(int2 >= 0 and int2 < 1 << 12)
	assert(int3 >= 0 and int3 < 1 << 12)
	return int1 | int2 << 12 | int3 << 24



