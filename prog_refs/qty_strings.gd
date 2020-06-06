# qty_strings.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
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
# All functions assume sim-standard units defined in UnitDefs.

class_name QtyStrings

const unit_defs := preload("res://ivoyager/static/unit_defs.gd")
const math := preload("res://ivoyager/static/math.gd")

enum { # case_type
	CASE_MIXED, # "1.00 Million", "1.00 kHz", "1.00 Kilohertz", "1.00 Megahertz"
	CASE_LOWER, # does not modify exp_str or unit symbol
	CASE_UPPER, # does not modify exp_str or unit symbol
}

enum { # num_type (TODO: commented formats)
	NUM_DYNAMIC, # "0.0100" to "99999" as non-scientific, otherwise scientific
	NUM_SCIENTIFIC, # pure scientific
#	NUM_NO_OVERPRECISION, # e.g., "555555" -> "556000" if sig_digits = 3
#	NUM_DYN_NO_OVERPRECISION, # DYNAMIC but "55555" -> "55600" if sig_digits = 3
	NUM_DECIMAL_PL, # treat sig_digits as number of decimal places
}

enum { # option_type for number_option()
	NAMED_NUMBER, # "99999", then "1.00 Million", etc.
	NUMBER,
	UNIT,
	PREFIXED_UNIT,
	# length
	LENGTH_M_KM, # m if x < 1.0 km
	LENGTH_KM_AU, # au if x > 0.1 au
	LENGTH_M_KM_AU,
	LENGTH_M_KM_AU_LY, # ly if x > 0.1 ly
	LENGTH_M_KM_AU_PREFIXED_PARSEC, # if > 0.1 pc, pc, kpc, Mpc, Gpc, etc.
	# mass
	MASS_G_KG, # g if < 1.0 kg
	MASS_G_KG_T, # g if < 1.0 kg; t if x >= 1000.0 kg 
	MASS_G_KG_PREFIXED_T, # g, kg, t, kt, Mt, Gt, Tt, Pt etc.
	# velocity
	VELOCITY_MPS_KMPS, # km/s if >= 1.0 km/s
	VELOCITY_MPS_KMPS_C, # km/s if >= 1.0 km/s; c if >= 0.1 c
	# misc
	LATITUDE,
	LONGITUDE,
}

const LOG_OF_10 := log(10.0)

# project vars
var exp_str := "e" # e.g., set to "E", "x10^", " x 10^"
var prefix_names := [
	"yocto", "zepto", "atto", "femto", "pico", "nano", "micro", "milli",
	"", "kilo", "Mega", "Giga", "Tera", "Peta", "Exa", "Zetta", "Yotta"
] # e3, e6, ... e24
var prefix_symbols := [
	"y", "z", "a", "f", "p", "n", char(181), "m",
	"", "k", "M", "G", "T", "P", "E", "Z", "Y"
] # same indexing as above

var large_numbers := ["TXT_MILLION", "TXT_BILLION", "TXT_TRILLION", "TXT_QUADRILLION",
	"TXT_QUINTILLION", "TXT_SEXTILLION", "TXT_SEPTILLION", "TXT_OCTILLION",
	 "TXT_NONILLION", "TXT_DECILLION"] # e6, e9, e12, ... e33; localized in project_init()

# Unit symbols in the next two dictionaries must also be present in multipliers
# or functions dictionaries (by default, these are obtained from UnitDefs). The
# converse is not true.

var short_forms := {
	# If missing here, we fallback to the unit string itself (which is usually
	# the desired short form).
	"century" : "TXT_CENTURIES",
	"deg" : "TXT_DEG",
	"degC" : "TXT_DEG_C",
	"degF" : "TXT_DEG_F",
	"deg/d" : "TXT_DEG_PER_DAY",
	"deg/a" : "TXT_DEG_PER_YEAR",
	"deg/century" : "TXT_DEG_PER_CENTURY",
	"_g" : "g",
}

var long_forms := {
	# If missing here, we fallback to short_forms, then the unit string itself.
	# Note that you can dynamically prefix any "base" unit (m, g, Hz, Wh, etc.)
	# using number_prefixed_unit(). We have commonly used already-prefixed here
	# because it is common to want to display quantities such as: "3.00e9 km".
	# time
	"s" : "TXT_SECONDS",
	"min" : "TXT_MINUTES",
	"h" : "TXT_HOURS",
	"d" : "TXT_DAYS",
	"a" : "TXT_YEARS",
	"y" : "TXT_YEARS",
	"yr" : "TXT_YEARS",
	"century" : "TXT_CENTURIES",
	# length
	"mm" : "TXT_MILIMETERS",
	"cm" : "TXT_CENTIMETERS",
	"m" : "TXT_METERS",
	"km" : "TXT_KILOMETERS",
	"au" : "TXT_ASTRONOMICAL_UNITS",
	"ly" : "TXT_LIGHT_YEARS",
	"pc" : "TXT_PARSECS",
	"Mpc" : "TXT_MEGAPARSECS",
	# mass
	"g" : "TXT_GRAMS",
	"kg" : "TXT_KILOGRAMS",
	"t" : "TXT_TONNES",
	# angle
	"rad" : "TXT_RADIANS",
	"deg" : "TXT_DEGREES",
	# temperature
	"K" : "TXT_KELVIN",
	"degC" : "TXT_CENTIGRADE",
	"degF" : "TXT_FAHRENHEIT",
	# frequency
	"Hz" : "TXT_HERTZ",
	"d^-1" : "TXT_PER_DAY",
	"a^-1" : "TXT_PER_YEAR",
	"y^-1" : "TXT_PER_YEAR",
	"yr^-1" : "TXT_PER_YEAR",
	# area
	"m^2" : "TXT_SQUARE_METERS",
	"km^2" : "TXT_SQUARE_KILOMETERS",
	"ha" : "TXT_HECTARES",
	# volume
	"l" : "TXT_LITER",
	"L" : "TXT_LITER",
	"m^3" : "TXT_CUBIC_METERS",
	"km^3" : "TXT_CUBIC_KILOMETERS",
	# velocity
	"m/s" : "TXT_METERS_PER_SECOND",
	"km/s" : "TXT_KILOMETERS_PER_SECOND",
	"km/h" : "TXT_KILOMETERS_PER_HOUR",
	"c" : "TXT_SPEED_OF_LIGHT",
	# acceleration/gravity
	"m/s^2" : "TXT_METERS_PER_SECOND_SQUARED",
	"_g" : "TXT_STANDARD_GRAVITIES",
	# angular velocity
	"deg/d" : "TXT_DEGREES_PER_DAY",
	"deg/a" : "TXT_DEGREES_PER_YEAR",
	"deg/century" : "DEGREES_PER_CENTURY",
	# particle density
	"m^-3" : "TXT_PER_CUBIC_METER",
	# mass density
	"g/cm^3" : "TXT_GRAMS_PER_CUBIC_CENTIMETER",
	# mass rate
	"kg/d" : "TXT_KILOGRAMS_PER_DAY",
	"t/d" : "TXT_TONNES_PER_DAY",
	# force
	"N" : "TXT_NEWTONS",
	# pressure
	"Pa" : "TXT_PASCALS",
	"atm" : "TXT_ATMOSPHERES",
	# energy
	"J" : "TXT_JOULES",
	"Wh" : "TXT_WATT_HOURS",
	"kWh" : "TXT_KILOWATT_HOURS",
	"MWh" : "TXT_MEGAWATT_HOURS",
	"eV" : "TXT_ELECTRONVOLTS",
	# power
	"W" : "TXT_WATTS",
	"kW" : "TXT_KILOWATTS",
	"MW" : "TXT_MEGAWATTS",
	# luminous intensity / luminous flux
	"cd" : "TXT_CANDELAS",
	"lm" : "TXT_LUMENS",
	# luminance
	"cd/m^2" : "TXT_CANDELAS_PER_SQUARE_METER",
	# electric potential
	"V" : "TXT_VOLTS",
	# electric charge
	"C" :  "TXT_COULOMBS",
	# magnetic flux
	"Wb" : "TXT_WEBERS",
	# magnetic flux density
	"T" : "TXT_TESLAS",
}

# private
var _n_prefixes: int
var _prefix_offset: int
var _n_lg_numbers: int
var _format2 := [null, null] # scratch array
var _format4 := [null, null, null, null] # scratch array
var _multipliers: Dictionary
var _functions: Dictionary

func project_init():
	_multipliers = Global.unit_multipliers
	_functions = Global.unit_functions
	_n_prefixes = prefix_symbols.size()
	assert(_n_prefixes == prefix_names.size())
	_prefix_offset = prefix_symbols.find("")
	assert(_prefix_offset == prefix_names.find(""))
	_n_lg_numbers = large_numbers.size()
	for i in range(_n_lg_numbers):
		large_numbers[i] = tr(large_numbers[i])

func number_option(x: float, option_type: int, unit := "", sig_digits := -1, num_type := NUM_DYNAMIC,
		long_form := false, case_type := CASE_MIXED) -> String:
	# wrapper for functions below
	match option_type:
		NAMED_NUMBER:
			return named_number(x, sig_digits, case_type)
		NUMBER:
			return number(x, sig_digits, num_type)
		UNIT:
			return number_unit(x, unit, sig_digits, num_type, long_form, case_type)
		PREFIXED_UNIT:
			return number_prefixed_unit(x, unit, sig_digits, num_type, long_form, case_type)
		LENGTH_M_KM: # m if x < 1.0 km
			if x < unit_defs.KM:
				return number_unit(x, "m", sig_digits, num_type, long_form, case_type)
			return number_unit(x, "km", sig_digits, num_type, long_form, case_type)
		LENGTH_KM_AU: # au if x > 0.1 au
			if x < 0.1 * unit_defs.AU:
				return number_unit(x, "km", sig_digits, num_type, long_form, case_type)
			return number_unit(x, "au", sig_digits, num_type, long_form, case_type)
		LENGTH_M_KM_AU:
			if x < unit_defs.KM:
				return number_unit(x, "m", sig_digits, num_type, long_form, case_type)
			elif x < 0.1 * unit_defs.AU:
				return number_unit(x, "km", sig_digits, num_type, long_form, case_type)
			return number_unit(x, "au", sig_digits, num_type, long_form, case_type)
		LENGTH_M_KM_AU_LY:
			if x < unit_defs.KM:
				return number_unit(x, "m", sig_digits, num_type, long_form, case_type)
			elif x < 0.1 * unit_defs.AU:
				return number_unit(x, "km", sig_digits, num_type, long_form, case_type)
			elif x < 0.1 * unit_defs.LIGHT_YEAR:
				return number_unit(x, "au", sig_digits, num_type, long_form, case_type)
			return number_unit(x, "ly", sig_digits, num_type, long_form, case_type)
		LENGTH_M_KM_AU_PREFIXED_PARSEC:
			if x < unit_defs.KM:
				return number_unit(x, "m", sig_digits, num_type, long_form, case_type)
			elif x < 0.1 * unit_defs.AU:
				return number_unit(x, "km", sig_digits, num_type, long_form, case_type)
			elif x < 0.1 * unit_defs.PARSEC:
				return number_unit(x, "au", sig_digits, num_type, long_form, case_type)
			return number_prefixed_unit(x, "pc", sig_digits, num_type, long_form, case_type)
		MASS_G_KG: # g if < 1.0 kg
			if x < unit_defs.KG:
				return number_unit(x, "g", sig_digits, num_type, long_form, case_type)
			return number_unit(x, "kg", sig_digits, num_type, long_form, case_type)
		MASS_G_KG_T: # g if < 1.0 kg; t if x >= 1000.0 kg 
			if x < unit_defs.KG:
				return number_unit(x, "g", sig_digits, num_type, long_form, case_type)
			elif x < unit_defs.TONNE:
				return number_unit(x, "kg", sig_digits, num_type, long_form, case_type)
			return number_unit(x, "t", sig_digits, num_type, long_form, case_type)
		MASS_G_KG_PREFIXED_T: # g, kg, t, kt, Mt, Gt, Tt, etc.
			if x < unit_defs.KG:
				return number_unit(x, "g", sig_digits, num_type, long_form, case_type)
			elif x < unit_defs.TONNE:
				return number_unit(x, "kg", sig_digits, num_type, long_form, case_type)
			return number_prefixed_unit(x, "t", sig_digits, num_type, long_form, case_type)
		VELOCITY_MPS_KMPS: # km/s if >= 1.0 km/s
			if x < unit_defs.KM / unit_defs.SECOND:
				return number_unit(x, "m/s", sig_digits, num_type, long_form, case_type)
			return number_unit(x, "km/s", sig_digits, num_type, long_form, case_type)
		VELOCITY_MPS_KMPS_C: # c if >= 0.1 c
			if x < unit_defs.KM / unit_defs.SECOND:
				return number_unit(x, "m/s", sig_digits, num_type, long_form, case_type)
			elif x < 0.1 * unit_defs.SPEED_OF_LIGHT:
				return number_unit(x, "c", sig_digits, num_type, long_form, case_type)
			return number_unit(x, "km/s", sig_digits, num_type, long_form, case_type)
		LATITUDE:
			return latitude(x, sig_digits, long_form, case_type)
		LONGITUDE:
			return longitude(x, sig_digits, long_form, case_type)
			
	assert(false, "Unkknown option_type: " + String(option_type))
	return String(x)

func latitude_longitude(lat: float, long: float, decimal_pl := 0, long_form := false,
		case_type := CASE_MIXED) -> String:
	return latitude(lat, decimal_pl, long_form, case_type) + " " \
			+ longitude(long, decimal_pl, long_form, case_type)

func latitude(x: float, decimal_pl := 0, long_form := false, case_type := CASE_MIXED) -> String:
	var suffix: String
	if long_form:
		if x >= 0.0 or is_zero_approx(x):
			suffix = tr("TXT_NORTH")
		else:
			suffix = tr("TXT_SOUTH")
	else:
		if x >= 0.0 or is_zero_approx(x):
			suffix = tr("TXT_NORTH_SHORT")
		else:
			suffix = tr("TXT_SOUTH_SHORT")
	if case_type == CASE_LOWER:
		suffix = suffix.to_lower()
	elif case_type == CASE_UPPER:
		suffix = suffix.to_upper()
	var num_str := number_unit(x, "deg", decimal_pl, NUM_DECIMAL_PL, long_form, case_type)
	return (num_str + suffix).lstrip("-")

func longitude(x: float, decimal_pl := 0, long_form := false, case_type := CASE_MIXED) -> String:
	var suffix: String
	if long_form:
		if x >= 0.0 or is_zero_approx(x):
			suffix = tr("TXT_EAST")
		else:
			suffix = tr("TXT_WEST")
	else:
		if x >= 0.0 or is_zero_approx(x):
			suffix = tr("TXT_EAST_SHORT")
		else:
			suffix = tr("TXT_WEST_SHORT")
	if case_type == CASE_LOWER:
		suffix = suffix.to_lower()
	elif case_type == CASE_UPPER:
		suffix = suffix.to_upper()
	var num_str := number_unit(x, "deg", decimal_pl, NUM_DECIMAL_PL, long_form, case_type)
	return (num_str + suffix).lstrip("-")

func number(x: float, sig_digits := -1, num_type := NUM_DYNAMIC) -> String:
	# sig_digets = -1 displays decimal precision "as is".
	# see SCI_ enums for num_type.
	if num_type == NUM_DECIMAL_PL:
		_format2[0] = sig_digits
		_format2[1] = x
		return ("%.*f" % _format2)
	var exp10 := 0
	if x != 0.0:
		exp10 = int(floor(log(abs(x)) / LOG_OF_10))
	if exp10 > 4 or exp10 < -2 or num_type == NUM_SCIENTIFIC:
		var divisor := pow(10.0, exp10)
		x = x / divisor if !is_zero_approx(divisor) else 1.0
		if sig_digits == -1:
			return String(x) + exp_str + String(exp10)
		else:
			_format4[0] = sig_digits - 1
			_format4[1] = x
			_format4[2] = exp_str
			_format4[3] = exp10
			return "%.*f%s%s" % _format4 # e.g., 5.55e5
	if sig_digits == -1:
		return (String(x))
	var decimal_pl := sig_digits - exp10 - 1
	if decimal_pl < 1:
		return "%.f" % x # whole number
	else:
		_format2[0] = decimal_pl
		_format2[1] = x
		return "%.*f" % _format2 # e.g., 0.0555

func named_number(x: float, sig_digits := 3, case_type := CASE_MIXED) -> String:
	# returns integer string up to "999999", then "1.00 Million", etc.;
	if abs(x) < 1e6:
		return "%.f" % x
	var exp_div_3 := int(floor(log(abs(x)) / (LOG_OF_10 * 3.0)))
	var lg_num_index := exp_div_3 - 2
	if lg_num_index < 0: # shouldn't happen but just in case
		return "%.f" % x
	if lg_num_index >= _n_lg_numbers:
		lg_num_index = _n_lg_numbers - 1
		exp_div_3 = lg_num_index + 2
	x /= pow(10.0, exp_div_3 * 3)
	var lg_number_str: String = large_numbers[lg_num_index]
	if case_type == CASE_LOWER:
		lg_number_str = lg_number_str.to_lower()
	elif case_type == CASE_UPPER:
		lg_number_str = lg_number_str.to_upper()
	return number(x, sig_digits, NUM_DYNAMIC) + " " + lg_number_str

func number_unit(x: float, unit: String, sig_digits := -1, num_type := NUM_DYNAMIC,
		long_form := false, case_type := CASE_MIXED) -> String:
	# unit must be in multipliers or functions dicts (by default these are
	# MULTIPLIERS and FUNCTIONS in ivoyager/static/unit_defs.gd)
	if sig_digits == -1:
		sig_digits = math.get_decimal_precision(x)
	x = unit_defs.conv(x, unit, true, false, _multipliers, _functions)
	var number_str := number(x, sig_digits, num_type)
	if long_form and long_forms.has(unit):
		unit = tr(long_forms[unit])
	elif short_forms.has(unit):
		unit = tr(short_forms[unit])
	if case_type == CASE_LOWER:
		unit = unit.to_lower()
	elif case_type == CASE_UPPER:
		unit = unit.to_upper()
	return number_str + " " + unit

func number_prefixed_unit(x: float, unit: String, sig_digits := -1, num_type := NUM_DYNAMIC,
		long_form := false, case_type := CASE_MIXED) -> String:
	# Example results: "1.00 Gt" or "1.00 Gigatonnes" (w/ unit = "t" and
	# long_form = false or true, repspectively). You won't see scientific
	# notation unless the internal value falls outside of the prefixes range.
	# WARNING: Don't try to prefix an already-prefixed unit (eg, km) or any
	# composite unit where the first unit has a power other than 1 (eg, m^3).
	# The result will look weird and/or be wrong (eg, 1000 m^3 -> 1.00 km^3).
	# unit = "" ok; otherwise, unit must be in multipliers or functions dicts.
	if sig_digits == -1:
		sig_digits = math.get_decimal_precision(x)
	if unit:
		x = unit_defs.conv(x, unit, true, false, _multipliers, _functions)
	var exp_div_3 := int(floor(log(abs(x)) / (LOG_OF_10 * 3.0)))
	var si_index := exp_div_3 + _prefix_offset
	if si_index < 0:
		si_index = 0
		exp_div_3 = -_prefix_offset
	elif si_index >= _n_prefixes:
		si_index = _n_prefixes - 1
		exp_div_3 = si_index - _prefix_offset
	x /= pow(10.0, exp_div_3 * 3)
	var number_str := number(x, sig_digits, num_type)
	if long_form and long_forms.has(unit):
		unit = tr(long_forms[unit])
	elif short_forms.has(unit):
		unit = tr(short_forms[unit])
	if long_form:
		unit = prefix_names[si_index] + unit
	else:
		unit = prefix_symbols[si_index] + unit
	if case_type == CASE_LOWER:
		unit = unit.to_lower()
	elif case_type == CASE_UPPER:
		unit = unit.to_upper()
	return number_str + " " + unit
