# utils.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2022 Charlie Whitfield
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


# Untyped tree search
static func get_deep(target, path: String): # untyped return
	if !path:
		return target
	var path_stack := Array(path.split("/", false))
	path_stack.invert()
	while path_stack:
		target = target.get(path_stack.pop_back())
		if target == null:
			return null
	return target


const NO_ARGS := []

static func get_path_result(target, path: String, args := NO_ARGS): # untyped return
	# as above but path could include methods
	if !path:
		return target
	var path_stack := Array(path.split("/", false))
	path_stack.invert()
	while path_stack:
		var property_or_method: String = path_stack.pop_back()
		if target is Object and target.has_method(property_or_method):
			target = target.callv(property_or_method, args)
		else:
			target = target.get(property_or_method)
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


static func fill_array(array: Array, fill_value) -> void:
	var size := array.size()
	var i := 0
	while i < size:
		array[i] = fill_value
		i += 1


# patch
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
