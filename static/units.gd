# units.gd
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
class_name IVUnits

# Godot issue #37529 prevents localization of global class_name to const. Use:
# const units := preload("res://ivoyager/static/units.gd")
#
# This class defines units from base SI units in universe.gd. You should need
# it only when converting to and from simulator values: e.g., data import,
# specifying quantities in class headers (e.g., a mass or radius cutoff),
# and GUI display (see program_refs/qty_txt_converter.gd for generating
# quantity strings).
# WE SHOULD NEVER NEED TO CONVERT IN OUR INTERNAL PROCESSING!
#
# See additional comments in universe.gd.

# SI base units - all sim units derived from these!
const SECOND := SIBaseUnits.SECOND
const METER := SIBaseUnits.METER
const KG := SIBaseUnits.KG
const AMPERE := SIBaseUnits.AMPERE
const KELVIN := SIBaseUnits.KELVIN
const CANDELA := SIBaseUnits.CANDELA

# derived units & constants
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
const STANDARD_GRAVITY := 9.80665 * METER / (SECOND * SECOND)
const GRAM := 1e-3 * KG
const TONNE := 1e3 * KG
const HECTARE := 1e4 * METER * METER
const LITER := 1e-3 * METER * METER * METER
const NEWTON := KG * METER / (SECOND * SECOND)
const PASCAL := NEWTON / (METER * METER)
const BAR := 1e5 * PASCAL
const ATM := 101325.0 * PASCAL
const JOULE := NEWTON * METER
const ELECTRONVOLT := 1.602176634e-19 * JOULE
const WATT := NEWTON / SECOND
const VOLT := WATT / AMPERE
const COULOMB := SECOND * AMPERE
const WEBER := VOLT * SECOND
const TESLA := WEBER / (METER * METER)
const STANDARD_GM := KM * KM * KM / (SECOND * SECOND) # usually in these units
const GRAVITATIONAL_CONSTANT := 6.67430e-11 * METER * METER * METER / (KG * SECOND * SECOND)

# Symbols below mostly follow:
# https://en.wikipedia.org/wiki/International_System_of_Units

const MULTIPLIERS := {
	# duplicated symbols have leading underscore(s)
	# time
	"s" : SECOND,
	"min" : MINUTE,
	"h" : HOUR,
	"d" : DAY,
	"a" : YEAR, # official Julian year symbol
	"y" : YEAR,
	"yr" : YEAR,
	"Cy" : CENTURY,
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
	"au/Cy" : AU / CENTURY,
	"AU/Cy" : AU / CENTURY,
	"c" : SPEED_OF_LIGHT,
	# acceleration/gravity
	"m/s^2" : METER / (SECOND * SECOND),
	"_g" : STANDARD_GRAVITY,
	# angular velocity
	"rad/s" : 1.0 / SECOND, 
	"deg/d" : DEG / DAY,
	"deg/a" : DEG / YEAR,
	"deg/Cy" : DEG / CENTURY,
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
	"bar" : BAR,
	"atm" : ATM,
	# energy
	"J" : JOULE,
	"kJ" : 1e3 * JOULE,
	"MJ" : 1e6 * JOULE,
	"GJ" : 1e9 * JOULE,
	"TJ" : 1e12 * JOULE,
	"Wh" : WATT * HOUR,
	"kWh" : 1e3 * WATT * HOUR,
	"MWh" : 1e6 * WATT * HOUR,
	"GWh" : 1e9 * WATT * HOUR,
	"TWh" : 1e12 * WATT * HOUR,
	"eV" : ELECTRONVOLT,
	# power
	"W" : WATT,
	"kW" : 1e3 * WATT,
	"MW" : 1e6 * WATT,
	"GW" : 1e9 * WATT,
	"TW" : 1e12 * WATT,
	"GJ/d" : 1e9 * JOULE / DAY,
	# luminous intensity / luminous flux
	"cd" : CANDELA,
	"cd sr" : CANDELA, # sr is dimentionless
	"lm" : CANDELA, # lumen
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
	"m^3/(kg s^2)" : METER * METER * METER / (KG * SECOND * SECOND),
	"km^3/(kg s^2)" : KM * KM * KM / (KG * SECOND * SECOND),
	# misc
	"deg/Cy^2" : DEG / (CENTURY * CENTURY),
	"flops" : 1.0 / SECOND,
	"FLOPS" : 1.0 / SECOND,
	"bits" : 1.0,
}

const FUNCTIONS := {
	# TODO 4.0: this will become a real functions dictionary
	"degC" : "convert_centigrade",
	"degF" : "convert_fahrenheit",
}


static func convert_quantity(x: float, unit: String, to_internal := true,
		preprocess := false, multipliers := MULTIPLIERS, functions := FUNCTIONS) -> float:
	# Converts x in specified units to internal representation (to_internal =
	# true) or from internal to specified units (to_internal = false).
	# unit can be any key in MULTIPLIERS or FUNCTIONS (or supplied replacement
	# dictionaries); preprocess = true handles prefixes "10^x " or "1/".
	# Valid examples: "1/Cy", "10^24 kg", "1/(10^3 yr)".
	if preprocess: # mainly for table import
		if unit.begins_with("1/"):
			unit = unit.lstrip("1/")
			if unit.begins_with("(") and unit.ends_with(")"):
				unit = unit.lstrip("(").rstrip(")")
			to_internal = !to_internal
		if unit.begins_with("10^"):
			var space_pos := unit.find(" ")
			assert(space_pos > 3, "A space must follow '10^xx'")
			var exponent_str := unit.substr(3, space_pos - 3)
			var pre_multiplier := pow(10.0, int(exponent_str))
			unit = unit.substr(space_pos + 1, 999)
			x *= pre_multiplier
	var multiplier: float = multipliers.get(unit, 0.0)
	if multiplier:
		return x * multiplier if to_internal else x / multiplier
	if functions.has(unit):
		# TODO 4.0: fix this hack when we have 1st class functions!
		var units = load("res://ivoyager/static/units.gd")
		return units.call(functions[unit], x, to_internal)
	assert(false, "Unknown unit symbol: " + unit)
	return x


static func convert_centigrade(x: float, to_internal := true) -> float:
	return x + 273.15 if to_internal else x - 273.15


static func convert_fahrenheit(x: float, to_internal := true) -> float:
	return  (x + 459.67) * (5.0 / 9.0) if to_internal else x * (9.0 / 5.0) - 459.67


static func is_valid_unit(unit: String, preprocess := false,
		multipliers := MULTIPLIERS, functions := FUNCTIONS) -> bool:
	# unit can be any key in MULTIPLIERS or FUNCTIONS (or supplied replacement
	# dictionaries); preprocess = true handles prefixes "10^x " or "1/".
	# Valid examples: "1/Cy", "10^24 kg", "1/(10^3 yr)".
	if preprocess: # mainly for table import
		if unit.begins_with("1/"):
			unit = unit.lstrip("1/")
			if unit.begins_with("(") and unit.ends_with(")"):
				unit = unit.lstrip("(").rstrip(")")
		if unit.begins_with("10^"):
			var space_pos := unit.find(" ")
			assert(space_pos > 3, "A space must follow '10^xx'")
			unit = unit.substr(space_pos + 1, 999)
	return multipliers.has(unit) or functions.has(unit)
