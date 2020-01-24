# string_maker.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2020 Charlie Whitfield
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
#

extends Reference
class_name StringMaker

enum {
	DISPLAY_NUMBER,
	DISPLAY_NAMED_NUMBER,
	DISPLAY_SCIENTIFIC,
	DISPLAY_MASS,
	DISPLAY_LENGTH,
	DISPLAY_VELOCITY,
	DISPLAY_AREA,
	DISPLAY_CURRENCY,
	}
const LOG_OF_10 := log(10)

# DEPRECIATE
const USE_LARGE_NAMES := false


# project vars
var use_tonnes := false

var large_si_symbol := ["k", "M", "G", "T", "P", "E", "Z", "Y", "B", "Gp"] # 10^3
var large_si_prefix := ["kilo", "Mega", "Giga", "Tera", "Peta", "Exa", "Zetta",
	"Yotta", "Bronto", "Geop"]
var max_si_index := 9
var large_numbers := ["million", "billion", "trillion", "quadrillion",
	"quintillion", "sextillion", "septillion", "octillion", "nonillion",
	"decillion"]
var max_large_num_index := 9

func get_str(x: float, display_enum: int, short := true) -> String:
	match display_enum:
		DISPLAY_NUMBER:
			return scientific(x)
		DISPLAY_NAMED_NUMBER:
			return named_number(x)
		DISPLAY_SCIENTIFIC:
			return scientific(x)
		DISPLAY_CURRENCY:
			return currency(x, short)
		DISPLAY_MASS:
			return mass(x, short)
		DISPLAY_LENGTH:
			return distance(x, short)
		DISPLAY_AREA:
			return area(x, short)
		DISPLAY_VELOCITY:
			return velocity_per_second(x, short)
		_:
			assert(false)
	return ""


func named_number(x: float) -> String:
	if x <= 0:
		return scientific(x)

	var lg_num_index = floor(log(x) / LOG_OF_10 / 3.0) - 2
	if lg_num_index < 0:
		return "%.f" % x
	if lg_num_index <= max_large_num_index:
		x = x / pow(10, 3 * (lg_num_index + 2))
		return String(x) + " " + large_numbers[lg_num_index]
	else:
		x = x / pow(10, 3 * (max_large_num_index + 1))
		return scientific(x) + " " + large_numbers[max_large_num_index]

func scientific(x: float) -> String:
	if x == 0.0:
		return "0"
	var exponent = floor(log(abs(x)) / LOG_OF_10)
	if exponent > 4 or exponent < 0:
		var power := pow(10, exponent)
		x = x / power if power != 0.0 else 1.0
		return "%.2fe%s" % [x, exponent]
	elif exponent == 0:
		return "%.2f" % x
	elif exponent == 1:
		return "%.1f" % x
	else:
		return "%.f" % x


func get_num_and_prefix_string(x: float, short: bool) -> String:
	var si_index = floor(log(x) / LOG_OF_10 / 3.0) - 1
	if si_index < 0:
		return String(x) + " "
	var prefix_table = large_si_symbol if short else large_si_prefix

	if si_index <= max_si_index:
		x = x / pow(10, 3 * (si_index + 1))
		return String(x) + " " + prefix_table[si_index]
	else:
		x = x / pow(10, 3 * (max_si_index + 1))
		return scientific(x) + " " + prefix_table[max_si_index]

func get_num_and_prefix_table(x: float, short: bool) -> Array:
	var si_index = floor(log(x) / LOG_OF_10 / 3.0) - 1
	if si_index < 0:
		return [x, ""]
	var prefix_table = large_si_symbol if short else large_si_prefix
	if si_index > max_si_index:
		si_index = max_si_index
	x = x / pow(10, 3 * (si_index + 1))
	return [x, prefix_table[si_index]]

func currency(x: float, _short: bool) -> String: # 1 = 1 M$
	if USE_LARGE_NAMES:
		x *= 1e6
		return get_num_and_prefix_string(x, true) + "$"
	else:
		return scientific(x) + " M$"

func mass(x: float, short: bool) -> String:
	if use_tonnes:
		x /= 1000.0
		var unit = "t" if short else "tonnes"
		if USE_LARGE_NAMES:
			return get_num_and_prefix_string(x, short) + unit
		else:
			return scientific(x) + " " + unit
	elif USE_LARGE_NAMES:
		x *= 1000.0
		var unit = "g" if short else "grams"
		return get_num_and_prefix_string(x, short) + unit
	else:
		return scientific(x) + " kg"

func distance(x: float, short: bool) -> String:
	if USE_LARGE_NAMES:
		x *= 1000.0 / Global.scale
		var unit = "m" if short else "meters"
		return get_num_and_prefix_string(x, short) + unit
	else:
		return scientific(x / Global.scale) + " km"

func area(x: float, short: bool) -> String:
	if USE_LARGE_NAMES:
		x = sqrt(x) * 1000.0 / Global.scale
		var result = get_num_and_prefix_table(x, short)
		x = result[0] * result[0]
		var unit_sq = " sq " + result[1] + "m"
		return String(x * x) + unit_sq
	else:
		return scientific(x / Global.scale / Global.scale) + " km"

func velocity_per_second(x: float, short: bool) -> String:
	if USE_LARGE_NAMES:
		var unit = "m/s" if short else "meters per second"
		x = x / Global.scale * 86.4 # m/s
		return get_num_and_prefix_string(x, short) + unit
	else:
		x = x / Global.scale * 86400 # km/s
		return scientific(x) + " km/s"


func project_init():
	pass
