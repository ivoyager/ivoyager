# table_utils.gd
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
class_name IVTableUtils
extends Object

# User can supply 'unit_multipliers' and 'unit_lambdas' when calling
# IVTableData.postprocess_tables(), or set directly here before that.
# If not set at or before postprocess_tables(), they will be set to the default
# conversion dictionaries defined in table_unit_defaults.gd.


static var unit_multipliers: Dictionary
static var unit_lambdas: Dictionary


static func convert_quantity(x: float, unit: StringName, to_internal := true,
		handle_unit_prefix := false) -> float:
	# Converts x in specified units to internal representation (to_internal =
	# true) or from internal to specified units (to_internal = false).
	#
	# If handle_unit_prefix == true, we handle simple unit prefixes '10^x ' and
	# '1/'. Valid examples: "1/Cy", "10^24 kg", "1/(10^3 yr)".
	#
	# After prefix handling (if used), 'unit' must be a dictionary key in either
	# 'unit_multipliers' or 'unit_lambdas'.
	
	if handle_unit_prefix:
		if unit.begins_with("1/"):
			var unit_str := unit.trim_prefix("1/")
			if unit_str.begins_with("(") and unit_str.ends_with(")"):
				unit_str = unit_str.trim_prefix("(").trim_suffix(")")
			unit = StringName(unit_str)
			to_internal = !to_internal
		if unit.begins_with("10^"):
			var unit_str := unit.trim_prefix("10^")
			var space_pos := unit_str.find(" ")
			assert(space_pos > 0, "A space must follow '10^xx'")
			var exponent_str := unit_str.substr(0, space_pos)
			assert(exponent_str.is_valid_int())
			var pre_multiplier := 10.0 ** exponent_str.to_int()
			unit_str = unit_str.substr(space_pos + 1, 999)
			unit = StringName(unit_str)
			x *= pre_multiplier
	
	var multiplier: float = unit_multipliers.get(unit, 0.0)
	if multiplier:
		return x * multiplier if to_internal else x / multiplier
	assert(unit_lambdas.has(unit), "Unknown unit symbol '%s'" % unit)
	var lambda: Callable = unit_lambdas[unit]
	return lambda.call(x, to_internal)


static func is_valid_unit(unit: StringName, handle_unit_prefix := false) -> bool:
	# Tests whether 'unit' string is valid for convert_quantity().
	if handle_unit_prefix:
		if unit.begins_with("1/"):
			var unit_str := unit.trim_prefix("1/")
			if unit_str.begins_with("(") and unit_str.ends_with(")"):
				unit_str = unit_str.trim_prefix("(").trim_suffix(")")
			unit = StringName(unit_str)
		if unit.begins_with("10^"):
			var unit_str := unit.trim_prefix("10^")
			var space_pos := unit_str.find(" ")
			if space_pos <= 0:
				return false
			var exponent_str := unit_str.substr(0, space_pos)
			if !exponent_str.is_valid_int():
				return false
			unit_str = unit_str.substr(space_pos + 1, 999)
			unit = StringName(unit_str)
	
	return unit_multipliers.has(unit) or unit_lambdas.has(unit)


static func c_unescape_patch(text: String) -> String:
	# Patch method to read '\u' escape; see open Godot issue #38716.
	# This can read 'small' unicodes up to '\uFFFF'.
	# Godot doesn't seem to support larger '\Uxxxxxxxx' unicodes as of 4.1.1.
	var u_esc := text.find("\\u")
	while u_esc != -1:
		var esc_str := text.substr(u_esc, 6)
		var hex_str := esc_str.replace("\\u", "0x")
		var unicode := hex_str.hex_to_int()
		var unicode_chr := char(unicode)
		text = text.replace(esc_str, unicode_chr)
		u_esc = text.find("\\u")
	return text

