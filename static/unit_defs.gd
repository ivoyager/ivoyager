# unit_defs.gd
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
# const unit_defs := preload("res://ivoyager/static/unit_defs.gd")
#
# This class defines the internal representation of all unit quantities! You
# should need it only for "in/out conversions": i.e., data table import,
# specifying unit quantities in class headers (e.g., a mass or radius cutoff),
# and GUI (see program_refs/qty_strings.gd for generating quantity strings).
# WE SHOULD NEVER NEED TO CONVERT IN OUR INTERNAL PROCESSING!
#
# CAUTION! Setting METER = 1.0 breaks the engine with AABB and other errors.
# Small values 1e-9 to 1e-15 work fine as far as I can tell, even when zoomed
# up to asteroid-sized bodies.

class_name UnitDefs

# SI base units
const SECOND := 1.0 # Godot engine delta per sim second
const METER := 1e-9 # Godot engine translation per sim meter (scale)
const KG := 1.0
const AMPERE := 1.0
const KELVIN := 1.0
const CANDELA := 1.0

# derived units
const DEG := PI / 180.0 # radians
const MINUTE := 60.0 * SECOND
const HOUR := 3600.0 * SECOND
const DAY := 86400.0 * SECOND # exact Julian day
const YEAR := 365.25 * DAY # exact Julian year
const CENTURY := 36525.0 * DAY
const MM := 1e-3 * METER
const CM := 1e-2 * METER
const KM := 1e3 * METER
const AU := 149597870700.0 * METER
const PARSEC := 648000.0 * AU / PI
const SPEED_OF_LIGHT := 299792458.0 * METER / SECOND
const LIGHT_YEAR := SPEED_OF_LIGHT * YEAR
const GRAM := 1e-3 * KG
const TONNE := 1e3 * KG
const HECTARE := 1e4 * METER * METER
const LITER := 1e-3 * METER * METER * METER
const NEWTON := KG * METER / (SECOND * SECOND)
const PASCAL := NEWTON / (METER * METER)
const JOULE := NEWTON * METER
const ELECTRONVOLT := 1.602176634e-19 * JOULE
const WATT := NEWTON / SECOND
const VOLT := WATT / AMPERE
const COULOMB := SECOND * AMPERE
const WEBER := VOLT * SECOND
const TESLA := WEBER / (METER * METER)
const STANDARD_GM := KM * KM * KM / (SECOND * SECOND) # usually in these units

# Symbols below mostly follow:
# https://en.wikipedia.org/wiki/International_System_of_Units

# TODO: yr -> y

const MULTIPLIERS := {
	# time
	"s" : SECOND,
	"min" : MINUTE,
	"h" : HOUR,
	"d" : DAY,
	"a" : YEAR, # official Julian year symbol
	"y" : YEAR,
	"yr" : YEAR,
	"century" : CENTURY,
	# length
	"mm" : MM,
	"cm" : CM,
	"m" : METER,
	"km" : KM,
	"au" : AU,
	"AU" : AU,
	"ly" : LIGHT_YEAR,
	"pc" : PARSEC,
	"Mpc" : 1e6 * PARSEC,
	# mass
	"g" : GRAM,
	"kg" : KG,
	"t" : TONNE,
	# angle
	"rad" : 1.0,
	"deg" : DEG,
	# temperature
	"K" : KELVIN,
	# frequency
	"Hz" : 1.0 / SECOND,
	"d^-1" : 1.0 / DAY,
	"a^-1" : 1.0 / YEAR,
	"y^-1" : 1.0 / YEAR,
	"yr^-1" : 1.0 / YEAR,
	# area
	"m^2" : METER * METER,
	"km^2" : KM * KM,
	"ha" : HECTARE,
	# volume
	"l" : LITER,
	"L" : LITER,
	"m^3" : METER * METER * METER,
	"km^3" : KM * KM * KM,
	# velocity
	"m/s" : METER / SECOND,
	"km/s" : KM / SECOND,
	"km/h" : KM / HOUR,
	"au/a" : AU / YEAR,
	"au/century" : AU / CENTURY,
	"AU/century" : AU / CENTURY,
	"c" : SPEED_OF_LIGHT,
	# angular velocity
	"rad/s" : 1.0 / SECOND, 
	"deg/d" : DEG / DAY,
	"deg/a" : DEG / YEAR,
	"deg/century" : DEG / CENTURY,
	# particle density
	"m^-3" : 1.0 / (METER * METER * METER),
	# density
	"kg/km^3" : KG / (KM * KM * KM),
	"g/cm^3" : GRAM / (CM * CM * CM),
	# mass rate
	"kg/s" : KG / SECOND,
	"g/d" : GRAM / DAY,
	"kg/d" : KG / DAY,
	"t/d" : TONNE / DAY,
	# force
	"N" : NEWTON,
	# pressure
	"Pa" : PASCAL,
	# energy
	"J" : JOULE,
	"Wh" : WATT * HOUR,
	"kWh" : 1e3 * WATT * HOUR,
	"MWh" : 1e6 * WATT * HOUR,
	"eV" : ELECTRONVOLT,
	# power
	"W" : WATT,
	"kW" : 1e3 * WATT,
	"MW" : 1e6 * WATT,
	# luminous intensity / luminous flux
	"cd" : CANDELA,
	"lm" : CANDELA, # lumen (really cd * sr, but sr is dimentionless)
	# luminance
	"cd/m^2" : CANDELA / (METER * METER),
	# electric potential
	"V" : VOLT,
	# electric charge
	"C" :  COULOMB,
	# magnetic flux
	"Wb" : WEBER,
	# magnetic flux density
	"T" : TESLA,
	# GM
	"km^3/s^2" : STANDARD_GM,
	"m^3/s^2" : METER * METER * METER / (SECOND * SECOND),
	# gravitational constant
	"km^3/(kg s^2)" : KM * KM * KM / (KG * SECOND * SECOND),
}

const FUNCTIONS := {
	# TODO 4.0: this will become a real functions dictionary
	"degC" : "conv_centigrade",
	"degF" : "conv_fahrenheit",
}


static func conv(x: float, unit: String, to_unit := false, preprocess := false,
		multipliers := MULTIPLIERS, functions := FUNCTIONS) -> float:
	# unit can be any key in MULTIPLIERS or FUNCTIONS (or supplied replacement
	# dictionaries); preprocess = true handles prefixes "10^x " or "1/".
	# Valid examples: "1/century", "10^24 kg", "1/(10^3 yr)".
	if preprocess: # mainly for table import
		if unit.begins_with("1/"):
			unit = unit.lstrip("1/")
			if unit.begins_with("(") and unit.ends_with(")"):
				unit = unit.lstrip("(").rstrip(")")
			to_unit = !to_unit
		if unit.begins_with("10^"):
			var space_pos := unit.find(" ")
			assert(space_pos > 3, "A space must follow '10^xx'")
			var exponent_str := unit.substr(3, space_pos - 3)
			var pre_multiplier := pow(10.0, int(exponent_str))
			unit = unit.substr(space_pos + 1, 999)
			x *= pre_multiplier
	var multiplier: float = multipliers.get(unit, 0.0)
	if multiplier:
		return x / multiplier if to_unit else x * multiplier
	if functions.has(unit):
		# this is a hack until we have 1st class functions in 4.0
		var unit_defs = load("res://ivoyager/static/unit_defs.gd")
		return unit_defs.call(functions[unit], x, to_unit)
	assert(false, "Unknown unit symbol: " + unit)
	return x

static func conv_centigrade(x: float, to := false) -> float:
	return x - 273.15 if to else x + 273.15

static func conv_fahrenheit(x: float, to := false) -> float:
	return x * (9.0 / 5.0) - 459.67 if to else (x + 459.67) * (5.0 / 9.0)
