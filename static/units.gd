# units.gd
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
class_name IVUnits
extends Object

# This class defines derived units from base SI units in si_base_units.gd. You
# should need it only when converting to and from simulator values: i.e.,
# specifying quantities in tables or code (to internal) and GUI display (from
# internal).
#
# WE SHOULD NEVER NEED TO CONVERT UNITS IN OUR INTERNAL PROCESSING!
#
# See static/qformat.gd for display unit strings.
#
# You can modify dictionaries 'multipliers' & 'lambdas' BUT DON'T REPLACE THEM!
# (These are referenced throughout ivoyager code.) It's ok to clear them
# and fill with your own project conversions. You will need to create your own
# static 'Units' class if you need different unit constants.


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

# Unit symbols below mostly follow:
# https://en.wikipedia.org/wiki/International_System_of_Units
#
# We look for unit symbol first in mulitipliers and then in lambdas.

static var multipliers := {
	# Duplicated symbols have leading underscore(s).
	# See IVQuantityFormater for unit display strings.
	
	# time
	&"s" : SECOND,
	&"min" : MINUTE,
	&"h" : HOUR,
	&"d" : DAY,
	&"a" : YEAR, # official Julian year symbol
	&"y" : YEAR,
	&"yr" : YEAR,
	&"Cy" : CENTURY,
	# length
	&"mm" : MM,
	&"cm" : CM,
	&"m" : METER,
	&"km" : KM,
	&"au" : AU,
	&"AU" : AU,
	&"ly" : LIGHT_YEAR,
	&"pc" : PARSEC,
	&"Mpc" : 1e6 * PARSEC,
	# mass
	&"g" : GRAM,
	&"kg" : KG,
	&"t" : TONNE,
	# angle
	&"rad" : 1.0,
	&"deg" : DEG,
	# temperature
	&"K" : KELVIN,
	# frequency
	&"Hz" : 1.0 / SECOND,
	&"d^-1" : 1.0 / DAY,
	&"a^-1" : 1.0 / YEAR,
	&"y^-1" : 1.0 / YEAR,
	&"yr^-1" : 1.0 / YEAR,
	# area
	&"m^2" : METER * METER,
	&"km^2" : KM * KM,
	&"ha" : HECTARE,
	# volume
	&"l" : LITER,
	&"L" : LITER,
	&"m^3" : METER * METER * METER,
	&"km^3" : KM * KM * KM,
	# velocity
	&"m/s" : METER / SECOND,
	&"km/s" : KM / SECOND,
	&"km/h" : KM / HOUR,
	&"au/a" : AU / YEAR,
	&"au/Cy" : AU / CENTURY,
	&"AU/Cy" : AU / CENTURY,
	&"c" : SPEED_OF_LIGHT,
	# acceleration/gravity
	&"m/s^2" : METER / (SECOND * SECOND),
	&"_g" : STANDARD_GRAVITY,
	# angular velocity
	&"rad/s" : 1.0 / SECOND, 
	&"deg/d" : DEG / DAY,
	&"deg/a" : DEG / YEAR,
	&"deg/Cy" : DEG / CENTURY,
	# particle density
	&"m^-3" : 1.0 / (METER * METER * METER),
	# density
	&"kg/km^3" : KG / (KM * KM * KM),
	&"g/cm^3" : GRAM / (CM * CM * CM),
	# mass rate
	&"kg/s" : KG / SECOND,
	&"g/d" : GRAM / DAY,
	&"kg/d" : KG / DAY,
	&"t/d" : TONNE / DAY,
	# force
	&"N" : NEWTON,
	# pressure
	&"Pa" : PASCAL,
	&"bar" : BAR,
	&"atm" : ATM,
	# energy
	&"J" : JOULE,
	&"kJ" : 1e3 * JOULE,
	&"MJ" : 1e6 * JOULE,
	&"GJ" : 1e9 * JOULE,
	&"TJ" : 1e12 * JOULE,
	&"Wh" : WATT * HOUR,
	&"kWh" : 1e3 * WATT * HOUR,
	&"MWh" : 1e6 * WATT * HOUR,
	&"GWh" : 1e9 * WATT * HOUR,
	&"TWh" : 1e12 * WATT * HOUR,
	&"eV" : ELECTRONVOLT,
	# power
	&"W" : WATT,
	&"kW" : 1e3 * WATT,
	&"MW" : 1e6 * WATT,
	&"GW" : 1e9 * WATT,
	&"TW" : 1e12 * WATT,
	&"GJ/d" : 1e9 * JOULE / DAY,
	# luminous intensity / luminous flux
	&"cd" : CANDELA,
	&"lm" : CANDELA, # 1 lm = 1 cd·sr, but sr is dimensionless
	# luminance
	&"cd/m^2" : CANDELA / (METER * METER),
	# electric potential
	&"V" : VOLT,
	# electric charge
	&"C" :  COULOMB,
	# magnetic flux
	&"Wb" : WEBER,
	# magnetic flux density
	&"T" : TESLA,
	# GM
	&"km^3/s^2" : STANDARD_GM,
	&"m^3/s^2" : METER * METER * METER / (SECOND * SECOND),
	# gravitational constant
	&"m^3/(kg s^2)" : METER * METER * METER / (KG * SECOND * SECOND),
	&"km^3/(kg s^2)" : KM * KM * KM / (KG * SECOND * SECOND),
	# information (base 10; KiB, MiB, etc. would take some coding...)
	&"bit" : 1.0,
	&"b" : 1.0,
	&"kb" : 1e3,
	&"Mb" : 1e6,
	&"Gb" : 1e9,
	&"Tb" : 1e12,
	&"Byte" : 8.0,
	&"B" : 8.0,
	&"kB" : 8e3,
	&"MB" : 8e6,
	&"GB" : 8e9,
	&"TB" : 8e12,
	# misc
	&"deg/Cy^2" : DEG / (CENTURY * CENTURY),
	&"m^0.5" : METER ** 0.5,
	&"m^0.4" : METER ** 0.4,
}

static var lambdas := {
	&"degC" : func convert_centigrade(x: float, to_internal := true) -> float:
		return x + 273.15 if to_internal else x - 273.15,
	&"degF" : func convert_fahrenheit(x: float, to_internal := true) -> float:
		return  (x + 459.67) / 1.8 if to_internal else x * 1.8 - 459.67,
}



static func convert_quantity(x: float, unit: StringName, to_internal := true,
		multipliers_ := multipliers, lambdas_ := lambdas, handle_unit_prefix := false) -> float:
	# Converts x in specified units to internal representation (to_internal =
	# true) or from internal to specified units (to_internal = false).
	#
	# If handle_unit_prefix == true, we handle simple unit prefixes '10^x ' and
	# '1/'. Valid examples: "1/Cy", "10^24 kg", "1/(10^3 yr)".
	#
	# After prefix handling (if used), 'unit' must be a dictionary key in either
	# 'multipliers_' or 'lambdas_'.
	
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
	
	var multiplier: float = multipliers_.get(unit, 0.0)
	if multiplier:
		return x * multiplier if to_internal else x / multiplier
	assert(lambdas_.has(unit), "Unknown unit symbol '%s'" % unit)
	var lambda: Callable = lambdas_[unit]
	return lambda.call(x, to_internal)


static func is_valid_unit(unit: StringName, multipliers_ := multipliers, lambdas_ := lambdas,
		handle_unit_prefix := false) -> bool:
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
	
	return multipliers_.has(unit) or lambdas_.has(unit)

