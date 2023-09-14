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
	if node.get("PERSIST_MODE") == IVEnums.PERSIST_PROCEDURAL:
		node.queue_free() # children will also be freed!
		return
	for child in node.get_children():
		if "PERSIST_MODE" in child:
			if child.get("PERSIST_MODE") != IVEnums.NO_PERSIST:
				free_procedural_nodes(child)


static func get_ancestor_spatial(spatial1: Node3D, spatial2: Node3D) -> Node3D:
	# Returns parent spatial or common spatial ancestor. Assumes no non-Spatial
	# nodes in the ancestor tree.
	while spatial1:
		var loop_spatial2 := spatial2
		while loop_spatial2:
			if spatial1 == loop_spatial2:
				return loop_spatial2
			loop_spatial2 = loop_spatial2.get_parent_node_3d()
		spatial1 = spatial1.get_parent_node_3d()
	return null


static func get_deep(target, path: String): # untyped return
	# searches property/element path starting from target
	if !path:
		return target
	var path_stack := Array(path.split("/", false))
	path_stack.reverse()
	while path_stack:
		var item_name: String = path_stack.pop_back()
		@warning_ignore("unsafe_method_access")
		target = target.get(item_name)
		if target == null:
			return null
	return target


static func get_path_result(target: Variant, path: String, args := []): # untyped return
	# as above but path could include methods
	if !path:
		return target
	var path_stack := Array(path.split("/", false))
	path_stack.reverse()
	while path_stack:
		var item_name: String = path_stack.pop_back()
		if target is Object:
			@warning_ignore("unsafe_cast")
			var object := target as Object
			if object.has_method(item_name):
				target = object.callv(item_name, args)
			else:
				target = object.get(item_name)
		else:
			@warning_ignore("unsafe_method_access")
			target = target.get(item_name)
		if target == null:
			return null
	return target


# Arrays

static func init_array(size: int, fill_value: Variant = null) -> Array:
	var array := []
	array.resize(size)
	if fill_value == null:
		return array
	var i := 0
	while i < size:
		array[i] = fill_value
		i += 1
	return array


static func init_typed_array(size: int, type: int, class_name_ := &"", script: Variant = null,
		fill_value: Variant = null) -> Array:
	# Will cause error if fill_value is wrong type; leave null to not fill.
	var array := Array([], type, class_name_, script)
	array.resize(size)
	if fill_value == null:
		return array
	var i := 0
	while i < size:
		array[i] = fill_value
		i += 1
	return array


# Conversions

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


static func get_float_str_precision(real_str: String) -> int:
	# See table FLOAT format rules in solar_system/planets.tsv.
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
			assert(chr.is_valid_int(), "Unknown FLOAT character: " + chr)
			started = true
			n_digits += 1
			n_unsig_zeros = 0
		i += 1
	if deduct_zeroes:
		n_digits -= n_unsig_zeros
	return n_digits


# Misc

# DEPRECIATE
static func get_visual_radius_compensated_dist(from_dist: float, from_radius: float,
		to_radius: float, exponent := 0.9) -> float:
	# Use to get distance that is visually compensated (but not fully) for
	# target size:
	#  exponent = 0.0, no compensation (result = old_dist)
	#  exponent = 1.0; full compensation so target appears same size
	return from_dist * pow(to_radius / from_radius, exponent)




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
