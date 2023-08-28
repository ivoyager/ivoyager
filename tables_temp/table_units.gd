# table_units_temp.gd
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
extends Object

# This static class defines derived units from base SI units. You should need
# it only when converting to and from internal values: i.e., specifying
# quantities in tables or code (TO internal) and GUI display (FROM internal).
#
# For GUI unit display, feel free to use our open-source IVQuantityFormatter:
# https://github.com/ivoyager/ivoyager/blob/master/program/quantity_formatter.gd
#
# It may be convenient to create a 'Units' object in your project with static
# vars below as constants. This way you can code unit quantities in your files
# as constants (e.g., 'const SOME_TIME_CONSTANT = 4.0 * Units.DAY'). If you do,
# be sure to set 'multipliers' and 'lambdas' here from your constant values so
# that there is only one source for all of your unit conversions. 

# SI base units
static var second := 1.0
static var meter := 1.0
static var kg := 1.0
static var ampere := 1.0
static var kelvin := 1.0
static var candela := 1.0

# derived units & constants
static var degree := PI / 180.0 # radians
static var minute := 60.0 * second
static var hour := 3600.0 * second
static var day := 86400.0 * second # exact Julian day
static var year := 365.25 * day # exact Julian year
static var century := 36525.0 * day
static var mm := 1e-3 * meter
static var cm := 1e-2 * meter
static var km := 1e3 * meter
static var au := 149597870700.0 * meter
static var parsec := 648000.0 * au / PI
static var speed_of_light := 299792458.0 * meter / second
static var light_year := speed_of_light * year
static var standard_gravity := 9.80665 * meter / (second * second)
static var gram := 1e-3 * kg
static var tonne := 1e3 * kg
static var hectare := 1e4 * meter * meter
static var liter := 1e-3 * meter * meter * meter
static var newton := kg * meter / (second * second)
static var pascal := newton / (meter * meter)
static var bar := 1e5 * pascal
static var atm := 101325.0 * pascal
static var joule := newton * meter
static var electronvolt := 1.602176634e-19 * joule
static var watt := newton / second
static var volt := watt / ampere
static var coulomb := second * ampere
static var weber := volt * second
static var tesla := weber / (meter * meter)
static var standard_gm := km * km * km / (second * second) # usually in these units
static var gravitational_constant := 6.67430e-11 * meter * meter * meter / (kg * second * second)

# Unit symbols below mostly follow:
# https://en.wikipedia.org/wiki/International_System_of_Units
#
# We look for unit symbol first in mulitipliers and then in lambdas.

static var multipliers := {
	# Duplicated symbols have leading underscore(s).
	
	# time
	&"s" : second,
	&"min" : minute,
	&"h" : hour,
	&"d" : day,
	&"a" : year, # official Julian year symbol
	&"y" : year,
	&"yr" : year,
	&"Cy" : century,
	# length
	&"mm" : mm,
	&"cm" : cm,
	&"m" : meter,
	&"km" : km,
	&"au" : au,
	&"AU" : au,
	&"light_year" : light_year,
	&"pc" : parsec,
	&"Mpc" : 1e6 * parsec,
	# mass
	&"g" : gram,
	&"kg" : kg,
	&"t" : tonne,
	# angle
	&"rad" : 1.0,
	&"deg" : degree,
	# temperature
	&"K" : kelvin,
	# frequency
	&"Hz" : 1.0 / second,
	&"d^-1" : 1.0 / day,
	&"a^-1" : 1.0 / year,
	&"y^-1" : 1.0 / year,
	&"yr^-1" : 1.0 / year,
	# area
	&"m^2" : meter * meter,
	&"km^2" : km * km,
	&"ha" : hectare,
	# volume
	&"l" : liter,
	&"L" : liter,
	&"m^3" : meter * meter * meter,
	&"km^3" : km * km * km,
	# velocity
	&"m/s" : meter / second,
	&"km/s" : km / second,
	&"km/h" : km / hour,
	&"au/a" : au / year,
	&"au/Cy" : au / century,
	&"AU/Cy" : au / century,
	&"speed_of_light" : speed_of_light,
	# acceleration/gravity
	&"m/s^2" : meter / (second * second),
	&"_g" : standard_gravity,
	# angular velocity
	&"rad/s" : 1.0 / second, 
	&"deg/d" : degree / day,
	&"deg/a" : degree / year,
	&"deg/Cy" : degree / century,
	# particle density
	&"m^-3" : 1.0 / (meter * meter * meter),
	# density
	&"kg/km^3" : kg / (km * km * km),
	&"g/cm^3" : gram / (cm * cm * cm),
	# mass rate
	&"kg/s" : kg / second,
	&"g/d" : gram / day,
	&"kg/d" : kg / day,
	&"t/d" : tonne / day,
	# force
	&"N" : newton,
	# pressure
	&"Pa" : pascal,
	&"bar" : bar,
	&"atm" : atm,
	# energy
	&"J" : joule,
	&"kJ" : 1e3 * joule,
	&"MJ" : 1e6 * joule,
	&"GJ" : 1e9 * joule,
	&"TJ" : 1e12 * joule,
	&"Wh" : watt * hour,
	&"kWh" : 1e3 * watt * hour,
	&"MWh" : 1e6 * watt * hour,
	&"GWh" : 1e9 * watt * hour,
	&"TWh" : 1e12 * watt * hour,
	&"eV" : electronvolt,
	# power
	&"W" : watt,
	&"kW" : 1e3 * watt,
	&"MW" : 1e6 * watt,
	&"GW" : 1e9 * watt,
	&"TW" : 1e12 * watt,
	&"GJ/d" : 1e9 * joule / day,
	# luminous intensity / luminous flux
	&"cd" : candela,
	&"cd sr" : candela, # sr is dimentionless
	&"lm" : candela, # lumen
	# luminance
	&"cd/m^2" : candela / (meter * meter),
	# electric potential
	&"V" : volt,
	# electric charge
	&"C" :  coulomb,
	# magnetic flux
	&"Wb" : weber,
	# magnetic flux density
	&"T" : tesla,
	# GM
	&"km^3/s^2" : standard_gm,
	&"m^3/s^2" : meter * meter * meter / (second * second),
	# gravitational constant
	&"m^3/(kg s^2)" : meter * meter * meter / (kg * second * second),
	&"km^3/(kg s^2)" : km * km * km / (kg * second * second),
	# information (base 10)
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
	&"deg/Cy^2" : degree / (century * century),
}

static var lambdas := {
	&"degC" : func convert_centigrade(x: float, to_internal := true) -> float:
		if to_internal:
			return (x + 273.15) * kelvin
		else:
			return x / kelvin - 273.15,
	&"degF" : func convert_fahrenheit(x: float, to_internal := true) -> float:
		if to_internal:
			return (x + 459.67) / 1.8 * kelvin
		else:
			return x / kelvin * 1.8 - 459.67,
}



static func convert_quantity(x: float, unit: StringName, to_internal := true,
		handle_unit_prefix := false) -> float:
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
	
	var multiplier: float = multipliers.get(unit, 0.0)
	if multiplier:
		return x * multiplier if to_internal else x / multiplier
	assert(lambdas.has(unit), "Unknown unit symbol '%s'" % unit)
	var lambda: Callable = lambdas[unit]
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
	
	return multipliers.has(unit) or lambdas.has(unit)

