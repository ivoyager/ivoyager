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

# Decodes ids from shader points (e.g., asteroids) for selection. This viewport
# is tiny so the texture.get_data() read from GPU is as cheap as possible.

signal target_point_changed(id) # -1 if target lost; use 'names' dict for name


const math := preload("res://ivoyager/static/math.gd")
const utils := preload("res://ivoyager/static/utils.gd")

const CALIBRATION := [0.25, 0.3125, 0.375, 0.4375, 0.5, 0.5675, 0.625, 0.6875, 0.75]
const COLOR_HALF_STEP := Color(0.015625, 0.015625, 0.015625, 0.0)


const PERSIST_MODE := IVEnums.PERSIST_PROPERTIES_ONLY
const PERSIST_PROPERTIES := ["ids", "names"]


# persisted; read-only!
var ids := {} # 36-bit id integers indexed by name string
var names := {} # name strings indexed by 36-bit id integer

# project vars - these tune the pointy finger dropout
var drop_frames := 60
var drop_mouse_movement := 20.0

# pixel read pattern - change will need a shaders rewrite!
var point_range := 6
var pxlx := [0, -3, 0, 3, 0, -3, 3, -3, 3, -6, 0, 6, 0, -6, -6, -3, 3, 6, 6, -3, 3, -6, 6, -6, 6]
var pxly := [0, 0, 3, 0, -3, 3, -3, -3, 3, 0, 6, 0, -6, -3, 3, 6, 6, -3, 3, -6, -6, 6, -6, -6, 6]

# private
var _world_targeting: Array = IVGlobal.world_targeting
var _node2d := Node2D.new()
var _n_calibration_steps := CALIBRATION.size()
var _picker_image: Image
var _current_id := -1
var _drop_frame_counter := 0
var _drop_mouse_coord := Vector2.ZERO
# per pixel arrays
var _cycle_steps := []
var _calibration_colors := [] # array of arrays
var _value_colors := [] # array of arrays
var _current_ids := [] # ordered by mouse proximity
# common buffers
var _calibration_r := []
var _calibration_g := []
var _calibration_b := []
var _adj_values := []

onready var _n_pxls := pxlx.size()
onready var _root_texture: ViewportTexture = get_tree().root.get_texture()
onready var _src_offset = Vector2.ONE * point_range
onready var _src_length = point_range * 2.0 + 1.0
onready var _src_rect = Rect2(0.0, 0.0, _src_length, _src_length)
onready var _picker_texture: ViewportTexture = get_texture()
onready var _picker_rect = _src_rect



func _ready() -> void:
	assert(pxlx.size() == pxly.size())
	usage = USAGE_2D
	render_target_update_mode = UPDATE_ALWAYS
	size = _picker_rect.size
	add_child(_node2d)
	_node2d.connect("draw", self, "_on_node2d_draw")
	VisualServer.connect("frame_post_draw", self, "_on_frame_post_draw")
	_cycle_steps.resize(_n_pxls)
	_cycle_steps.fill(0)
	_calibration_colors.resize(_n_pxls)
	_value_colors.resize(_n_pxls)
	for pxl in _n_pxls:
		_calibration_colors[pxl] = []
		_calibration_colors[pxl].resize(_n_calibration_steps)
		_value_colors[pxl] = []
		_value_colors[pxl].resize(3)
	_current_ids.resize(_n_pxls)
	_calibration_r.resize(_n_calibration_steps)
	_calibration_g.resize(_n_calibration_steps)
	_calibration_b.resize(_n_calibration_steps)
	_adj_values.resize(9)


func get_new_point_id(name_str: String) -> int:
	# Assigns random id from interval 0 to 68_719_476_735 (36 bits).
	# We assume that there will be less than billions of points, so spurious
	# ids from _process_pixel() will almost always be filtered.
	if ids.has(name_str):
		print("WARNING! Duplicated point name: ", name_str)
	var id := (randi() << 4) | (randi() & 15) # randi() is only 32 bits
	while names.has(id):
		id = (randi() << 4) | (randi() & 15)
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
	# significant 3 bits. So we read 1/16 color steps from the midrange after
	# calibration. Three colors encode giving valid ids from 0 to 2^36-1.
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
	# Should print nearly whole number values
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
	# Copy a small rect of root viewport texture to this viewport.
	if _world_targeting[6].x < 0.0: # mouse_coord
		return
	_src_rect.position = _world_targeting[6] - _src_offset
	_node2d.draw_texture_rect_region(_root_texture, _picker_rect, _src_rect)


func _on_frame_post_draw() -> void:
	# Grab image from this viewport; scan pixels for shaders signaling id.
	if _world_targeting[6].x < 0.0:
		return
	_picker_image = _picker_texture.get_data() # expensive!
	_picker_image.lock()
	_node2d.update() # force a draw signal
	var id := -1
	for pxl in _n_pxls:
		_process_pixel(pxl) # process all, don't break!
		if id == -1: # keep 1st
			id = _current_ids[pxl]
	var is_object_mouse_target: bool = _world_targeting[4] != null # give this priority
	if is_object_mouse_target:
		id = -1
	if id != -1:
		if _current_id != id: # gained or changed valid id
			_current_id = id
			emit_signal("target_point_changed", id)
		_drop_frame_counter = 0
		_drop_mouse_coord = _world_targeting[6]
	elif _current_id != -1:
		if (!is_object_mouse_target and _drop_frame_counter < drop_frames
				and _drop_mouse_coord.distance_to(_world_targeting[6]) < drop_mouse_movement):
			# We've lost id signal, but don't reset _current_id yet
			_drop_frame_counter += 1
		else:
			_current_id = -1
			emit_signal("target_point_changed", -1)



func _process_pixel(pxl: int):
	# We're looking for a point shader (e.g., asteroid) signalling its id.
	# Signals start with a monotonic calibration series, followed by 3 colors
	# that encode id. If a valid id is read at end of cycle, it is registered
	# in _current_ids array. Broken signals are reset to -1.
	
	var color := _picker_image.get_pixel(point_range + pxlx[pxl], point_range + pxly[pxl])
	
	 # black pixel always interupts (common in open space)
	if !color:
		_cycle_steps[pxl] = 0
		_current_ids[pxl] = -1 # reset
		return # interupt
	
	var cycle_step: int = _cycle_steps[pxl]
	
	# start calibration
	if cycle_step == 0:
		_calibration_colors[pxl][0] = color
		_cycle_steps[pxl] = 1
		return # processing
	
	# continue calibration (interupt/restart if nonmonotonic)
	if cycle_step < _n_calibration_steps:
		var last: Color = _calibration_colors[pxl][cycle_step - 1]
		if last.r < color.r and last.g < color.g and last.b < color.b:
			_calibration_colors[pxl][cycle_step] = color
			_cycle_steps[pxl] += 1
			return # processing
		else:
			_calibration_colors[pxl][0] = color
			_cycle_steps[pxl] = 1
			_current_ids[pxl] = -1 # reset
			return # interupt
	
	# collect values (interupt/restart if >1/2 step out of calibration range)
	var min_color: Color = _calibration_colors[pxl][0] - COLOR_HALF_STEP
	if color.r < min_color.r or color.g < min_color.g or color.b < min_color.b:
		_calibration_colors[pxl][0] = color
		_cycle_steps[pxl] = 1
		_current_ids[pxl] = -1 # reset
		return # interupt
	var max_color: Color = _calibration_colors[pxl][_n_calibration_steps - 1] + COLOR_HALF_STEP
	if color.r > max_color.r or color.g > max_color.g or color.b > max_color.b:
		_calibration_colors[pxl][0] = color
		_cycle_steps[pxl] = 1
		_current_ids[pxl] = -1 # reset
		return # interupt
	_value_colors[pxl][cycle_step - _n_calibration_steps] = color
	if cycle_step < _n_calibration_steps + 2:
		_cycle_steps[pxl] += 1
		return # processing
	
	# This pixel completed the signal cycle!
	
	# calibrate
	for i in _n_calibration_steps:
		var calibration_color: Color = _calibration_colors[pxl][i]
		_calibration_r[i] = calibration_color.r
		_calibration_g[i] = calibration_color.g
		_calibration_b[i] = calibration_color.b
	for i in 3:
		var value_color: Color = _value_colors[pxl][i]
		var r := value_color.r
		var g := value_color.g
		var b := value_color.b
		
		var interval := _calibration_r.bsearch(r) - 1 # always ordered
		if interval == -1:
			interval = 0
		elif interval == _n_calibration_steps - 1:
			interval = _n_calibration_steps - 2
		var scaler := inverse_lerp(_calibration_r[interval], _calibration_r[interval + 1], r)
		_adj_values[i * 3] = lerp(CALIBRATION[interval], CALIBRATION[interval + 1], scaler)
		
		interval = _calibration_g.bsearch(g) - 1
		if interval == -1:
			interval = 0
		elif interval == _n_calibration_steps - 1:
			interval = _n_calibration_steps - 2
		scaler = inverse_lerp(_calibration_g[interval], _calibration_g[interval + 1], g)
		_adj_values[i * 3 + 1] = lerp(CALIBRATION[interval], CALIBRATION[interval + 1], scaler)
		
		interval = _calibration_b.bsearch(b) - 1
		if interval == -1:
			interval = 0
		elif interval == _n_calibration_steps - 1:
			interval = _n_calibration_steps - 2
		scaler = inverse_lerp(_calibration_b[interval], _calibration_b[interval + 1], b)
		_adj_values[i * 3 + 2] = lerp(CALIBRATION[interval], CALIBRATION[interval + 1], scaler)
	
	# decode (interupt/restart if spurious id)
	var id := decode(_adj_values)
	if !names.has(id):
		_calibration_colors[pxl][0] = color
		_cycle_steps[pxl] = 1
		_current_ids[pxl] = -1 # reset
		return # interupt
	
	# success!
	_cycle_steps[pxl] = 0
	_current_ids[pxl] = id


