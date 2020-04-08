# conv.gd
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
# Issue #37529 prevents localization of global class_name to const. Use:
# const conv := preload("res://ivoyager/static/conv.gd")
#
# The sim uses units s, km, kg, rad internally (km * Global.scale for engine
# properties). Ideally, we should need to convert units only at data table
# import and for GUI display.

class_name Conv

# conversion constants
const HOUR := 3600.0 # s
const DAY := 86400.0 # s
const YEAR := 365.25 * DAY # exact Julian year
const CENTURY := 100.0 * YEAR
const AU := 149597870.0 # km
const PARSEC := 648000.0 * AU / PI
const DEG := 360.0 / TAU # rad
const C := 299792.458 # km/s

# Mostly follows https://en.wikipedia.org/wiki/International_System_of_Units
const SYMBOLS := { # multipliers to get sim-standard unit
	# time
	"s" : 1.0,
	"min" : 60.0,
	"h" : HOUR,
	"d" : DAY,
	"a" : YEAR, # official Julian year symbol
	"century" : CENTURY,
	# length
	"m" : 0.001,
	"km" : 1.0,
	"au" : AU,
	"pc" : PARSEC,
	"Mpc" : PARSEC * 1e6,
	# mass
	"g" : 0.001,
	"kg" : 1.0,
	"t" : 1000.0, # tonnes
	# angle
	"rad" : 1.0,
	"deg" : DEG,
	# temperature
	"K" : 1.0,
	# area
	"m^2" : 0.001 * 0.001,
	"km^2" : 1.0,
	"ha" : 0.1 * 0.1, # hectare
	# volume
	"m^3" : 0.001 * 0.001 * 0.001,
	"km^3" : 1.0,
	# velocity
	"m/s" : 0.001,
	"km/s" : 1.0,
	"km/h" : 1.0 / HOUR,
	"au/a" : AU / YEAR,
	"au/century" : AU / CENTURY,
	"c" : C,
	# angular velocity
	"rad/s" : 1.0, 
	"deg/d" : DEG / DAY,
	"deg/a" : DEG / YEAR,
	"deg/century" : DEG / CENTURY,
	# density
	"kg/km^3" : 1.0,
	"g/cm^3" : 1000.0 / pow(100000.0, 3.0),
	# mass rate
	"kg/s" : 1.0,
	"g/d" : 0.001 / DAY,
	"kg/d" : 1.0 / DAY,
	"t/d" : 1000.0 / DAY,
	# other
	"km^3/s^2" : 1.0, # data table GMs
	"m^3/s^2" : pow(0.001, 3.0), # alternative GM
}

# For func calls below, unit_symbol can be any SYMBOLS key or "(key)", "1/key"
# or "1/(key)". It can be preceeded by a multiplier of the exact form "10^x ".
# Valid examples: "1/century", "1/(km^3/s^2)", "10^24 kg".
# You can optionally supply your own symbols dict.

static func from(x: float, unit_symbol: String, symbols := SYMBOLS) -> float:
	var multiplier := get_multiplier(unit_symbol, symbols)
	if multiplier == 0.0: # already asserted below
		return x
	return x * multiplier

static func to(x: float, unit_symbol: String, symbols := SYMBOLS) -> float:
	var divisor := get_multiplier(unit_symbol, symbols)
	if divisor == 0.0: # already asserted below
		return x
	return x / divisor

static func get_multiplier(unit_symbol: String, symbols := SYMBOLS) -> float:
	var pre_multiplier := 1.0
	if unit_symbol.begins_with("10^"):
		var space_pos := unit_symbol.find(" ")
		assert(space_pos > 3, "A space must follow '10^x'")
		var exponent_str := unit_symbol.substr(3, space_pos - 3)
		pre_multiplier = pow(10.0, float(exponent_str))
		unit_symbol = unit_symbol.substr(space_pos + 1, 999)
	var is_reciprocol := unit_symbol.begins_with("1/")
	if is_reciprocol:
		unit_symbol = unit_symbol.lstrip("1/")
	if unit_symbol.begins_with("(") and unit_symbol.ends_with(")"):
		unit_symbol = unit_symbol.lstrip("(").rstrip(")")
	var multiplier: float = symbols.get(unit_symbol, 0.0)
	if multiplier == 0.0: # not found
		assert(false, "Unknown unit symbol: " + unit_symbol)
		return 0.0
	if is_reciprocol:
		multiplier = 1.0 / multiplier
	return multiplier * pre_multiplier
