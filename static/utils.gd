# utils.gd
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
class_name IVUtils
extends Object

# Miscellaneous utility static functions. There are no references to 'ivoyager'
# classes here.
# Usage note: issue #37529 prevents localization of global class_name to const.
# For now, use:
# const utils := preload("res://ivoyager/static/utils.gd")


# Tree utilities

static func free_procedural_nodes(node: Node) -> void:
	if node.PERSIST_MODE == IVEnums.PERSIST_PROCEDURAL:
		node.queue_free() # children will also be freed!
		return
	for child in node.get_children():
		if "PERSIST_MODE" in child:
			if child.PERSIST_MODE != IVEnums.NO_PERSIST:
				free_procedural_nodes(child)


static func get_deep(target, path: String): # untyped return
	# searches property/element path starting from target
	if !path:
		return target
	var path_stack := Array(path.split("/", false))
	path_stack.invert()
	while path_stack:
		var item_name: String = path_stack.pop_back()
		target = target.get(item_name)
		if target == null:
			return null
	return target


static func get_path_result(target, path: String, args := []): # untyped return
	# as above but path could include methods
	if !path:
		return target
	var path_stack := Array(path.split("/", false))
	path_stack.invert()
	while path_stack:
		var item_name: String = path_stack.pop_back()
		if target is Object and target.has_method(item_name):
			target = target.callv(item_name, args)
		else:
			target = target.get(item_name)
		if target == null:
			return null
	return target


# Arrays

static func init_array(size: int, init_value = null) -> Array:
	var array := []
	array.resize(size)
	if init_value == null:
		return array
	var i := 0
	while i < size:
		array[i] = init_value
		i += 1
	return array


# Conversions

static func id2vec(id: int) -> Vector3:
	# converts 36 bit integer to Vector3 (12 bit / element)
	assert(id >= 0 and id < (1 << 36)) # up to 68_719_476_735
	var int1 := id & 4095 # (1 << 12) - 1
	id >>= 12
	var int2 := id & 4095
	id >>= 12
	var int3 := id & 4095
	return Vector3(float(int1), float(int2), float(int3))


static func vec2id(vector: Vector3) -> int:
	# converts Vector3 (12 bit / element) to 36 bit integer 
	var int1 := int(vector.x)
	var int2 := int(vector.y)
	var int3 := int(vector.z)
	assert(int1 >= 0 and int1 < 4096) # 1 << 12
	assert(int2 >= 0 and int2 < 4096)
	assert(int3 >= 0 and int3 < 4096)
	return int1 | int2 << 12 | int3 << 24


static func srgb2linear(color: Color) -> Color:
	if color.r <= 0.04045:
		color.r /= 12.92
	else:
		color.r = pow((color.r + 0.055) / 1.055, 2.4)
	if color.g <= 0.04045:
		color.g /= 12.92
	else:
		color.g = pow((color.g + 0.055) / 1.055, 2.4)
	if color.b <= 0.04045:
		color.b /= 12.92
	else:
		color.b = pow((color.b + 0.055) / 1.055, 2.4)
	return color


static func linear2srgb(x: float) -> float:
	if x <= 0.0031308:
		return x * 12.92
	else:
		return pow(x, 1.0 / 2.4) * 1.055 - 0.055


# Number strings

static func binary_str(flags: int) -> String:
	# returns 64 bit string
	var result := ""
	var index := 0
	while index < 64:
		if index % 8 == 0 and index != 0:
			result = "_" + result
		result = "1" + result if flags & 1 else "0" + result
		flags >>= 1
		index += 1
	return result


static func get_real_str_precision(real_str: String) -> int:
	# See table REAL format rules in solar_system/planets.tsv.
	# IVTableImporter has stripped leading "_" and converted "E" to "e".
	# We ignore leading zeroes before the decimal place.
	# We count trailing zeroes IF there is a decimal place.
	if real_str == "?":
		return -1
	if real_str.begins_with("~"):
		return 0
	var length := real_str.length()
	var n_digits := 0
	var started := false
	var n_unsig_zeros := 0
	var deduct_zeroes := true
	var i := 0
	while i < length:
		var chr: String = real_str[i]
		if chr == ".":
			started = true
			deduct_zeroes = false
		elif chr == "e":
			break
		elif chr == "0":
			if started:
				n_digits += 1
				if deduct_zeroes:
					n_unsig_zeros += 1
		elif chr != "-":
			assert(chr.is_valid_integer(), "Unknown REAL character: " + chr)
			started = true
			n_digits += 1
			n_unsig_zeros = 0
		i += 1
	if deduct_zeroes:
		n_digits -= n_unsig_zeros
	return n_digits


# Misc



# Patches

static func c_unescape_patch(text: String) -> String:
	# Use as patch until c_unescape() is fixed (Godot issue #38716).
	# Implement escapes as needed here. It appears that large unicodes are not
	# supported (?), so we can't do anything with "\U".
	var u_esc := text.find("\\u")
	while u_esc != -1:
		var esc_str := text.substr(u_esc, 6)
		var hex_str := esc_str.replace("\\u", "0x")
		var unicode := hex_str.hex_to_int()
		var unicode_chr := char(unicode)
		text = text.replace(esc_str, unicode_chr)
		u_esc = text.find("\\u")
	return text
