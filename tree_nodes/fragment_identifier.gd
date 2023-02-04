# fragment_identifier.gd
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
class_name IVFragmentIdentifier
extends Viewport

# TODO: orbit lines.
#
# Remove from ProjectBuilder.gui_nodes if not used.
#
# Decodes id from shader fragment displayed on the root viewport (e.g.,
# asteroid points). We capture a tiny square around the mouse so the
# texture.get_data() read from GPU is as cheap as possible.
#
# Shader fragments broadcast (and this node reads) every 3rd pixel in a grid
# pattern bounded by fragment_range. This works with minimum point_size = 3.
#
# This system is moot if we could send id from GPU shaders to CPU in a more
# sensible way. Godot 4.0 will allow custom GLSL "compute" shaders that could
# do that. However, we need ids from vertex shaders. We'll see if that can be
# done. In any case, this works...

signal fragment_changed(id) # -1 on target loss; get name from 'infos'


const COLOR_HALF_STEP := Color(0.015625, 0.015625, 0.015625, 0.0)

const PERSIST_MODE := IVEnums.PERSIST_PROPERTIES_ONLY
const PERSIST_PROPERTIES := [
	"ids",
	"infos",
]


# persisted; read-only!
var ids := {} # 36-bit id integers indexed by name string
var infos := {} # info arrays indexed by 36-bit id integer; [0] always name


# project vars
var drop_id_frames := 40 # tunes the loss of 'current' id by time
var drop_id_mouse_movement := 20.0 # tunes the loss of 'current' id by mouse movement
var fragment_range := 9 # multiple of 3! Going big is expensive!


# private
var _node2d := Node2D.new()
var _world_targeting: Array = IVGlobal.world_targeting
var _calibration := IVGlobal.fragment_calibration
var _n_calibration_steps := _calibration.size()
var _n_pxls: int
var _picker_rect: Rect2
var _src_rect: Rect2 # will follow mouse
var _src_offset: Vector2
var _picker_image: Image
var _current_id := -1
var _drop_frame_counter := 0
var _drop_mouse_coord := Vector2.ZERO
var _has_drawn := false
# per pixel arrays
var _pxl_x_offsets := []
var _pxl_y_offsets := []
var _cycle_steps := []
var _calibration_colors := [] # array of calibration color arrays
var _value_colors := [] # array of value color arrays
var _current_ids := [] # -1 or valid id
# common buffers
var _calibration_r := []
var _calibration_g := []
var _calibration_b := []
var _adj_values := []

onready var _root_texture: ViewportTexture = get_tree().root.get_texture()
onready var _picker_texture: ViewportTexture = get_texture()



func _ready() -> void:
	assert(fragment_range % 3 == 0)
	_init_rects_and_arrays()
	_world_targeting[7] = fragment_range # set in shaders (but as float)
	usage = USAGE_2D
	render_target_update_mode = UPDATE_ALWAYS
	size = _picker_rect.size
	add_child(_node2d)
	_node2d.connect("draw", self, "_on_node2d_draw")
	VisualServer.connect("frame_post_draw", self, "_on_frame_post_draw")


# public

func get_new_id(info: Array) -> int:
	# info[0] always name_str, which must be globally unique.
	# Assigns random id from interval 0 to 68_719_476_735 (36 bits).
	var name_str: String = info[0]
	assert(!ids.has(name_str), "Duplicated small body name: " + name_str)
	var id := (randi() << 4) | (randi() & 15) # randi() is only 32 bits
	while infos.has(id):
		id = (randi() << 4) | (randi() & 15)
	infos[id] = info
	ids[name_str] = id
	return id


func get_new_id_as_vec3(info: Array) -> Vector3:
	var id := get_new_id(info)
	return encode_vec3(id)


func remove_id(id: int) -> void:
	var name_str: String = infos[id][0]
	infos.erase(id)
	ids.erase(name_str)


static func encode_color_channels(id: int) -> Array:
	# Here for reference; part of color encode logic used by shaders.
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


static func decode_color_channels(array: Array) -> int:
	# Reverses encode_color_channels(id).
	var id := int(round((array[8] - 0.25) * 32.0))
	id <<= 4
	id |= int(round((array[7] - 0.25) * 32.0))
	id <<= 4
	id |= int(round((array[6] - 0.25) * 32.0))
	id <<= 4
	id |= int(round((array[5] - 0.25) * 32.0))
	id <<= 4
	id |= int(round((array[4] - 0.25) * 32.0))
	id <<= 4
	id |= int(round((array[3] - 0.25) * 32.0))
	id <<= 4
	id |= int(round((array[2] - 0.25) * 32.0))
	id <<= 4
	id |= int(round((array[1] - 0.25) * 32.0))
	id <<= 4
	id |= int(round((array[0] - 0.25) * 32.0))
	return id


static func decode_vec3(vector: Vector3) -> int:
	# Here for reference; part of color encode logic used by shaders.
	# Converts Vector3 (12 bit / element) to 36 bit integer.
	var int1 := int(vector.x)
	var int2 := int(vector.y)
	var int3 := int(vector.z)
	assert(int1 >= 0 and int1 < 4096) # 1 << 12
	assert(int2 >= 0 and int2 < 4096)
	assert(int3 >= 0 and int3 < 4096)
	return int1 | int2 << 12 | int3 << 24


static func encode_vec3(id: int) -> Vector3:
	# Converts 36 bit integer to Vector3 (12 bit / element), used in shader
	# construction.
	assert(id >= 0 and id < (1 << 36)) # up to 68_719_476_735
	var int1 := id & 4095 # (1 << 12) - 1
	id >>= 12
	var int2 := id & 4095
	id >>= 12
	var int3 := id & 4095
	return Vector3(float(int1), float(int2), float(int3))


# private

func _init_rects_and_arrays() -> void:
	var side_length := fragment_range * 2 + 1
	_picker_rect = Rect2(0.0, 0.0, side_length, side_length) # sets THIS viewport size
	_src_rect = _picker_rect # will follow mouse
	_src_offset = Vector2.ONE * fragment_range
	var pxl_center_offsets := range(-fragment_range, fragment_range + 1, 3)
	var pxl_center_xy_offsets := []
	for x in pxl_center_offsets:
		for y in pxl_center_offsets:
			pxl_center_xy_offsets.append([x, y])
	pxl_center_xy_offsets.sort_custom(self, "_sort_pxl_offsets") # prioritize center
	_n_pxls = pxl_center_xy_offsets.size()
	_pxl_x_offsets.resize(_n_pxls)
	_pxl_y_offsets.resize(_n_pxls)
	for pxl in _n_pxls:
		_pxl_x_offsets[pxl] = fragment_range + pxl_center_xy_offsets[pxl][0]
		_pxl_y_offsets[pxl] = fragment_range + pxl_center_xy_offsets[pxl][1]
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
	_current_ids.fill(-1)
	_calibration_r.resize(_n_calibration_steps)
	_calibration_g.resize(_n_calibration_steps)
	_calibration_b.resize(_n_calibration_steps)
	_adj_values.resize(9)


func _sort_pxl_offsets(a: Array, b: Array) -> bool:
	return a[0] * a[0] + a[1] * a[1] < b[0] * b[0] + b[1] * b[1]


func _on_node2d_draw() -> void:
	# Copy a small rect of root viewport texture to this viewport.
	_src_rect.position = _world_targeting[6] - _src_offset
	_node2d.draw_texture_rect_region(_root_texture, _picker_rect, _src_rect)
	_has_drawn = true


func _on_frame_post_draw() -> void:
	# Grab image from this viewport; scan pixels for shaders signaling id.
	if _world_targeting[6].x < 0.0: # ie, WorldController.NULL_MOUSE_COORD
		_has_drawn = false
		if _current_id != -1:
			_current_id = -1
			emit_signal("fragment_changed", -1)
		return
	_node2d.update() # force a draw signal
	if !_has_drawn:
		return
	_has_drawn = false
	_picker_image = _picker_texture.get_data() # expensive!
	_picker_image.lock()
	var id := -1
	for pxl in _n_pxls:
		_process_pixel(pxl) # process all, don't break!
		if id == -1 and _current_ids[pxl] != -1: # keep first valid id, if there is one
			id = _current_ids[pxl]
	if id != -1:
		if _current_id != id: # gained or changed valid id
			_current_id = id
			emit_signal("fragment_changed", id)
		_drop_frame_counter = 0
		_drop_mouse_coord = _world_targeting[6]
		return
	if _current_id == -1:
		return
	if (_drop_frame_counter > drop_id_frames or
			_drop_mouse_coord.distance_to(_world_targeting[6]) > drop_id_mouse_movement):
		_current_id = -1
		emit_signal("fragment_changed", -1)
		return
	# We've lost id signal, but don't reset _current_id yet
	_drop_frame_counter += 1


func _process_pixel(pxl: int):
	# We're looking for a point shader (e.g., asteroid) signalling its id.
	# Signals start with a monotonic calibration series, followed by 3 colors
	# that encode id. If a valid id is read at cycle end, it is registered in
	# _current_ids array. Interupted signals are reset to -1.
	
	var color := _picker_image.get_pixel(_pxl_x_offsets[pxl], _pxl_y_offsets[pxl])
	
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
			# The vast majority of non-black pixels interupt here. This could
			# be the start of a new calibration signal so we keep the color and
			# restart cycle at step 1.
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
		
		var interval := _calibration_r.bsearch(r) - 1 # calibration arrays always ordered
		if interval == -1:
			interval = 0
		elif interval == _n_calibration_steps - 1:
			interval = _n_calibration_steps - 2
		var scaler := inverse_lerp(_calibration_r[interval], _calibration_r[interval + 1], r)
		_adj_values[i * 3] = lerp(_calibration[interval], _calibration[interval + 1], scaler)
		
		interval = _calibration_g.bsearch(g) - 1
		if interval == -1:
			interval = 0
		elif interval == _n_calibration_steps - 1:
			interval = _n_calibration_steps - 2
		scaler = inverse_lerp(_calibration_g[interval], _calibration_g[interval + 1], g)
		_adj_values[i * 3 + 1] = lerp(_calibration[interval], _calibration[interval + 1], scaler)
		
		interval = _calibration_b.bsearch(b) - 1
		if interval == -1:
			interval = 0
		elif interval == _n_calibration_steps - 1:
			interval = _n_calibration_steps - 2
		scaler = inverse_lerp(_calibration_b[interval], _calibration_b[interval + 1], b)
		_adj_values[i * 3 + 2] = lerp(_calibration[interval], _calibration[interval + 1], scaler)
	
	# decode (interupt/restart if spurious id)
	var id := decode_color_channels(_adj_values)
	if !infos.has(id):
		_calibration_colors[pxl][0] = color
		_cycle_steps[pxl] = 1
		_current_ids[pxl] = -1 # reset
		return # interupt
	
	# success!
	_cycle_steps[pxl] = 0
	_current_ids[pxl] = id


func _debug_residuals(print_all := false) -> float:
	# Debug method to analyze _adj_values residuals.
	if print_all:
		# Should print nearly whole number values.
		prints(
			(_adj_values[0] - 0.25) * 32.0,
			(_adj_values[1] - 0.25) * 32.0,
			(_adj_values[2] - 0.25) * 32.0,
			(_adj_values[3] - 0.25) * 32.0,
			(_adj_values[4] - 0.25) * 32.0,
			(_adj_values[5] - 0.25) * 32.0,
			(_adj_values[6] - 0.25) * 32.0,
			(_adj_values[7] - 0.25) * 32.0,
			(_adj_values[8] - 0.25) * 32.0
		)
	var max_resid := 0.0
	for i in 9:
		var value: float = (_adj_values[i] - 0.25) * 32.0
		var resid := abs(value - round(value))
		if max_resid < resid:
			max_resid = resid
	return max_resid

