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
const utils := preload("res://ivoyager/static/utils.gd")
const CALIBRATION := [0.25, 0.3125, 0.375, 0.4375, 0.5, 0.5675, 0.625, 0.6875, 0.75]
#const CALIBRATION := [
#	0.25, 0.28125,
#	0.3125, 0.34375,
#	0.375, 0.40625,
#	0.4375, 0.46875,
#	0.5, 0.53125,
#	0.5675, 0.59375,
#	0.625, 0.65625,
#	0.6875, 0.71875,
#	0.75
#	]
const COLOR_HALF_STEP := Color(0.015625, 0.015625, 0.015625, 0.0)

const PERSIST_MODE := IVEnums.PERSIST_PROPERTIES_ONLY
const PERSIST_PROPERTIES := ["ids", "names"]

var ids := {} # 36-bit ints indexed by name string
var names := {} # name strings indexed by 36-bit int



var point_range := 5


var _world_targeting: Array = IVGlobal.world_targeting
var _node2d := Node2D.new()
var _delta60 := 0.0

var _calibration_size := CALIBRATION.size()
var _cycle_step := 0
var _calibration_colors := []
var _calibration_r := []
var _calibration_g := []
var _calibration_b := []
var _value_colors := []
var _adj_values := []
var _last_id := -1

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
	_calibration_r.resize(_calibration_size)
	_calibration_g.resize(_calibration_size)
	_calibration_b.resize(_calibration_size)
	_adj_values.resize(9)
	

#	# test encode/decode
#	var test := [0, 1000, 12345678, 99999999, 68_719_476_735]
#	for i in test.size():
#		print(decode(encode(test[i])))

#	# test quadratic fit
#	var x := [1.0, 3.0, 5.0, 7.0, 9.0]
#	var y := [32.5, 37.3, 36.4, 32.4, 28.5]
#	print(IVMath.quadratic_fit(x, y)) # [-0.366071, 3.015714, 30.421786]
	
#	prints(2, 2 >> 12, utils.id2vec(2))
	
#	print(utils.vec2id(utils.id2vec(1)))
#
#
#	print(utils.vec2id(utils.id2vec(999)))
#	print(utils.vec2id(utils.id2vec(68_719_476_735)))

	
	

#var _id := 0

func get_new_point_id(name_str: String) -> int:
	# Assigns random id from interval 0 to 68_719_476_735 (36 bits).
	# Assumes we won't exceed ~30 billion points.
	if ids.has(name_str):
		print("WARNING! Duplicated point name: ", name_str)
	
	
	var id := (randi() << 4) | (randi() & 15) # randi() is only 32 bits
	while names.has(id):
		id = (randi() << 4) | (randi() & 15)
	
	# debug
#	var id := _id
#	_id += 1
	
	names[id] = name_str
	ids[name_str] = id
	
	return id


func remove_point_id(name_str: String) -> void:
	var id: int = ids[name_str]
	ids.erase(id)
	ids.erase(name_str)


static func encode(id: int) -> Array:
	# Here for reference; this is the id encode logic used by point shaders.
	# We only use 4 bits of info per 8-bit color channel. All colors are
	# generated in the range 0.25-0.75 (losing 1 bit) and we ignore the least
	# significant 3 bits. So we only need detect 1/16 color steps after
	# calibration. Three colors encode id giving range 0 to 2^36-1.
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
	# Reverse encode.
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


static func debug_decode_residuals(array: Array) -> void:
	
	prints(
		(array[0] - 0.25) * 32.0,
		(array[1] - 0.25) * 32.0,
		(array[2] - 0.25) * 32.0,
		(array[3] - 0.25) * 32.0,
		(array[4] - 0.25) * 32.0,
		(array[5] - 0.25) * 32.0,
		(array[6] - 0.25) * 32.0,
		(array[7] - 0.25) * 32.0,
		(array[8] - 0.25) * 32.0
	)


# private

func _on_node2d_draw() -> void:
	# copy a small rect of root viewport texture to this viewport
	if _world_targeting[6].x < 0.0: # mouse_coord
		return
	_src_rect.position = _world_targeting[6] - _src_offset
	_node2d.draw_texture_rect_region(_root_texture, _picker_rect, _src_rect)


func _on_frame_post_draw() -> void:
	# grab (tiny) image from this viewport, look for point shader signalling id
	if _world_targeting[6].x < 0.0:
		return
	var picker_image := _picker_texture.get_data()
	picker_image.lock()
#	picker_image.srgb_to_linear()
	var color := picker_image.get_pixel(point_range, point_range)
	var id := _detect_id_signal(color)
	if id != -1:
		if id >= 0:
			print(names[id])
		elif id != _last_id:
			print(id)
		_last_id = id
	_node2d.update() # force a draw signal


func _detect_id_signal(color: Color) -> int:
	# Returns -1 if we are processing a potential signal; -2 for broken signal;
	# or id if signal cycle completes with a valid id.
	# Signals start with a monotonic calibration series, followed by 3 id-
	# encoding colors. Black pixel always interupts (common in open space).
	
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
	if color.r < min_color.r or color.g < min_color.g or color.b < min_color.b:
		_calibration_colors[0] = color
		_cycle_step = 1
		return -2 # interupt
	var max_color: Color = _calibration_colors[_calibration_size - 1] + COLOR_HALF_STEP
	if color.r > max_color.r or color.g > max_color.g or color.b > max_color.b:
		_calibration_colors[0] = color
		_cycle_step = 1
		return -2 # interupt
	_value_colors[_cycle_step - _calibration_size] = color
	_cycle_step += 1
	if _cycle_step < _calibration_size + 3:
		return -1 # processing
	
	# complete signal cycle!
	_cycle_step = 0
	
	# calibrate
	for i in _calibration_size:
		var calibration_color: Color = _calibration_colors[i]
		_calibration_r[i] = calibration_color.r
		_calibration_g[i] = calibration_color.g
		_calibration_b[i] = calibration_color.b
	for i in 3:
		var value_color: Color = _value_colors[i]
		var r := value_color.r
		var g := value_color.g
		var b := value_color.b
		
		var index := _calibration_r.bsearch(r) - 1
		if index == -1:
			index = 0
		elif index == _calibration_size - 1:
			index = _calibration_size - 2
		var weight := inverse_lerp(_calibration_r[index], _calibration_r[index + 1], r)
		_adj_values[i * 3] = lerp(CALIBRATION[index], CALIBRATION[index + 1], weight)
		
		index = _calibration_g.bsearch(g) - 1
		if index == -1:
			index = 0
		elif index == _calibration_size - 1:
			index = _calibration_size - 2
		weight = inverse_lerp(_calibration_g[index], _calibration_g[index + 1], g)
		_adj_values[i * 3 + 1] = lerp(CALIBRATION[index], CALIBRATION[index + 1], weight)
		
		index = _calibration_b.bsearch(b) - 1
		if index == -1:
			index = 0
		elif index == _calibration_size - 1:
			index = _calibration_size - 2
		weight = inverse_lerp(_calibration_b[index], _calibration_b[index + 1], b)
		_adj_values[i * 3 + 2] = lerp(CALIBRATION[index], CALIBRATION[index + 1], weight)
	
	var id := decode(_adj_values)

#	prints(id, "  ", names.get(id, "-"))
	
	return id if names.has(id) else -2 # filter spurious ids


#func _get_calibrated_floats(calibration_colors: Array, value_colors: Array) -> Array:
#	# generate calibration coefficients
#
#
#	var r_coeffs := math.quadratic_fit(_calibration_r, CALIBRATION)
#	var g_coeffs := math.quadratic_fit(_calibration_g, CALIBRATION)
#	var b_coeffs := math.quadratic_fit(_calibration_b, CALIBRATION)
#
#	# calibrate values
#	var color1: Color = value_colors[0]
#	var color2: Color = value_colors[1]
#	var color3: Color = value_colors[2]
#	var r1 := math.quadratic(color1.r, r_coeffs)
#	var r2 := math.quadratic(color2.r, r_coeffs)
#	var r3 := math.quadratic(color3.r, r_coeffs)
#	var g1 := math.quadratic(color1.g, g_coeffs)
#	var g2 := math.quadratic(color2.g, g_coeffs)
#	var g3 := math.quadratic(color3.g, g_coeffs)
#	var b1 := math.quadratic(color1.b, b_coeffs)
#	var b2 := math.quadratic(color2.b, b_coeffs)
#	var b3 := math.quadratic(color3.b, b_coeffs)
#
#	return [r1, g1, b1, r2, g2, b2, r3, g3, b3]


