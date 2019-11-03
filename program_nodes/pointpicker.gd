# pointpicker.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2019 Charlie Whitfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# *****************************************************************************
#
# WIP
# This is all moot if we can somehow get vertex translations out of GPU. Can we
# get data as a texture???
# The PointPicker class lets us select a screen object based on an id hidden in
# its color low bits. This is necessary in particular for asteroids where
# current locations (of up to 600,000+) are known only by their vertex shaders.
# We get 2^24 = 16777216 possible ids by encoding id in the lowest 2 bits of
# each color in 4 adjacent pixels. The 4 pixels are enumerated based on odd/
# eveness of their x & y postion. We only examine "primary" color pixels
# (defined in function below) surrounded by non-primary colors. Two partially
# overlapping points will be rejected (return null) due to color inconsistancy.
# This works only if point sizes are at least 2 pixels. 

extends Node

var _VPTexture
var _point_size
var _lookup_array

func _init(Viewport_, point_size):
	_VPTexture = Viewport_.get_texture().get_data()
	_VPTexture.lock()
	_point_size = point_size
	
func find_object(position, pixel_range, lookup_array):
	# Spiral-out search
	_lookup_array = lookup_array
	var x = 0
	var y = 0
	var d = _point_size
	var m = _point_size
	while m <= pixel_range:
		while 2 * x * d < m:
			var Result = _get_object(position.x + x, position.y + y)
			if Result != null:
				return Result
			x += d
		while 2 * y * d < m:
			var Result = _get_object(position.x + x, position.y + y)
			if Result != null:
				return Result
			y += d
		d = -d
		m += _point_size
	return null

func _get_object(x, y):
	var center_color = _VPTexture.get_pixel(x, y)
	if not is_primary_srgb_color(center_color):
		return null
	var color_grid = _get_color_grid(x, y)
	if color_grid != null:
		return null
	var hidden_code = 0
	for i in range(4):
		var color = color_grid[i]
		# Colors grabbed from viewport texture have been converted from
		# linear to sRGB. To match exactly the color set in in the shader
		# fragment ALBEDO, they need to be converted back to linear and
		# then incremented by 1 (the latter was empirically observed).
		var linear_argb32 = Math.srgb2linear(color).to_argb32()
		var rgb24 = linear_argb32 & 0xFFFFFF
		rgb24 += 0x010101 # increment +1 to get back shader ALBEDO
		var low_bits = rgb24 & 0x030303
		hidden_code += low_bits * pow(2, i * 4) # CHECK THIS !!!
	if hidden_code >= _lookup_array.size():
		return null
	return _lookup_array[hidden_code]

func _get_color_grid(start_x, start_y):
	# Test for consistancy of primary color by even/odd x/y's
	var color_grid = [null, null, null, null] # even/even, even/odd, odd/even, odd/odd
	for x in range(-_point_size, _point_size):
		for y in range(-_point_size, _point_size):
			var color = _VPTexture.get_pixel(start_x + x, start_y + y)
			if is_primary_srgb_color(color):
				var index = (x % 2) * 2 + (y % 2) * 4
				if color_grid[index] == null:
					color_grid[index] = color
				elif color_grid[index] != color:
					return null
	for i in range(4):
		if color_grid[i] == null:
			return null
	return color_grid

static func is_primary_srgb_color(color):
	# same cuttoffs in linear color would be 0.9 & 0.1
	var low_count = 0
	var high_count = 0
	if color.r < 0.3492:
		low_count += 1
	elif color.r > 0.9547:
		high_count += 1
	if color.g < 0.3492:
		low_count += 1
	elif color.g > 0.9547:
		high_count += 1
	if color.b < 0.3492:
		low_count += 1
	elif color.b > 0.9547:
		high_count += 1
	return low_count != 3 and high_count != 3 and high_count + low_count == 3
