# quantity_formatter.gd
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
class_name IVQuantityFormatter
extends RefCounted

# Helper for formatting numbers and quanties for GUI. All unit conversions are
# as defined in IVUnits.

const units := preload("res://ivoyager/static/units.gd")
const math := preload("res://ivoyager/static/math.gd")

enum { # case_type
	CASE_MIXED, # "1.00 Million", "1.00 kHz", "1.00 Kilohertz", "1.00 Megahertz"
	CASE_LOWER, # does not modify exp_str, unit symbols, N, S, E, W (maybe others)
	CASE_UPPER, # does not modify exp_str or unit symbols (maybe others)
}

enum { # num_type
	NUM_DYNAMIC, # 0.01 to 99999 as non-scientific, otherwise scientific
	NUM_SCIENTIFIC, # pure scientific
	NUM_PRECISION, # eg, precision = 3 -> "12300", "1.23", "0.0000123"
	NUM_DECIMAL_PL, # treat precision as number of decimal places
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
	# mass rate
	MASS_RATE_G_KG_PREFIXED_T_PER_D # g/d, kg/d, t/d, kt/d, Mt/d, Gt/d, etc.
	# time
	TIME_D_Y, # d if < 1000 d, else y
	# velocity
	VELOCITY_MPS_KMPS, # km/s if >= 1.0 km/s
	VELOCITY_MPS_KMPS_C, # km/s if >= 1.0 km/s; c if >= 0.1 c
	# misc
	LATITUDE,
	LONGITUDE,
}

enum { # lat_long_type
	N_S_E_W,
	LAT_LONG,
	PITCH_YAW,
}

const LOG_OF_10 := log(10.0)

# project vars
var exp_str := "e" # e.g., set to "E", "x10^", " x 10^"
var prefix_names := [ # e-24, ..., e24
	"yocto", "zepto", "atto", "femto", "pico", "nano", "micro", "milli",
	"", "kilo", "Mega", "Giga", "Tera", "Peta", "Exa", "Zetta", "Yotta"
]
var prefix_symbols := [ # e-24, ..., e24
	"y", "z", "a", "f", "p", "n", char(181), "m",
	"", "k", "M", "G", "T", "P", "E", "Z", "Y"
]
var large_numbers := ["TXT_MILLION", "TXT_BILLION", "TXT_TRILLION", "TXT_QUADRILLION",
	"TXT_QUINTILLION", "TXT_SEXTILLION", "TXT_SEPTILLION", "TXT_OCTILLION",
	 "TXT_NONILLION", "TXT_DECILLION"] # e6, ..., e33; localized in _project_init()

# Unit symbols in the next two dictionaries must also be present in multipliers
# or functions dictionaries. (The converse is not true.)
var short_forms := {
	# If missing here, we fallback to the unit string itself, which is usually
	# the desired short form. Asterisk before TXT_KEY means no space before
	# unit.
	"deg" : "*TXT_DEG",
	"degC" : "TXT_DEG_C",
	"degF" : "TXT_DEG_F",
	"deg/d" : "*TXT_DEG_PER_DAY",
	"deg/a" : "*TXT_DEG_PER_YEAR",
	"deg/Cy" : "*TXT_DEG_PER_CENTURY",
	"_g" : "g", # reused symbol ("_g" in function call; "g" in GUI)
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
	"Cy" : "TXT_CENTURIES",
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
	"deg/Cy" : "DEGREES_PER_CENTURY",
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
var _multipliers: Dictionary
var _functions: Dictionary


func _project_init():
	_multipliers = IVGlobal.unit_multipliers
	_functions = IVGlobal.unit_functions
	_n_prefixes = prefix_symbols.size()
	assert(_n_prefixes == prefix_names.size())
	_prefix_offset = prefix_symbols.find("")
	assert(_prefix_offset == prefix_names.find(""))
	_n_lg_numbers = large_numbers.size()
	for i in range(_n_lg_numbers):
		large_numbers[i] = tr(large_numbers[i])
	for unit in short_forms:
		var txt_key: String = short_forms[unit]
		if txt_key.begins_with("*"):
			short_forms[unit] = tr(short_forms[unit].lstrip("*"))
		else:
			short_forms[unit] = " " + tr(short_forms[unit])
	for unit in long_forms:
		long_forms[unit] = " " + tr(long_forms[unit])


func number_option(x: float, option_type: int, unit := "", precision := 3, num_type := NUM_DYNAMIC,
		long_form := false, case_type := CASE_MIXED) -> String:
	# wrapper for functions below
	match option_type:
		NAMED_NUMBER:
			return named_number(x, precision, case_type)
		NUMBER:
			if unit:
				return number(x, precision, num_type) + " " + unit
			else:
				return number(x, precision, num_type)
		UNIT:
			return number_unit(x, unit, precision, num_type, long_form, case_type)
		PREFIXED_UNIT:
			return number_prefixed_unit(x, unit, precision, num_type, long_form, case_type)
		LENGTH_M_KM: # m if x < 1.0 km
			if x < units.KM:
				return number_unit(x, "m", precision, num_type, long_form, case_type)
			return number_unit(x, "km", precision, num_type, long_form, case_type)
		LENGTH_KM_AU: # au if x > 0.1 au
			if x < 0.1 * units.AU:
				return number_unit(x, "km", precision, num_type, long_form, case_type)
			return number_unit(x, "au", precision, num_type, long_form, case_type)
		LENGTH_M_KM_AU:
			if x < units.KM:
				return number_unit(x, "m", precision, num_type, long_form, case_type)
			elif x < 0.1 * units.AU:
				return number_unit(x, "km", precision, num_type, long_form, case_type)
			return number_unit(x, "au", precision, num_type, long_form, case_type)
		LENGTH_M_KM_AU_LY:
			if x < units.KM:
				return number_unit(x, "m", precision, num_type, long_form, case_type)
			elif x < 0.1 * units.AU:
				return number_unit(x, "km", precision, num_type, long_form, case_type)
			elif x < 0.1 * units.LIGHT_YEAR:
				return number_unit(x, "au", precision, num_type, long_form, case_type)
			return number_unit(x, "ly", precision, num_type, long_form, case_type)
		LENGTH_M_KM_AU_PREFIXED_PARSEC:
			if x < units.KM:
				return number_unit(x, "m", precision, num_type, long_form, case_type)
			elif x < 0.1 * units.AU:
				return number_unit(x, "km", precision, num_type, long_form, case_type)
			elif x < 0.1 * units.PARSEC:
				return number_unit(x, "au", precision, num_type, long_form, case_type)
			return number_prefixed_unit(x, "pc", precision, num_type, long_form, case_type)
		MASS_G_KG: # g if < 1.0 kg
			if x < units.KG:
				return number_unit(x, "g", precision, num_type, long_form, case_type)
			return number_unit(x, "kg", precision, num_type, long_form, case_type)
		MASS_G_KG_T: # g if < 1.0 kg; t if x >= 1000.0 kg 
			if x < units.KG:
				return number_unit(x, "g", precision, num_type, long_form, case_type)
			elif x < units.TONNE:
				return number_unit(x, "kg", precision, num_type, long_form, case_type)
			return number_unit(x, "t", precision, num_type, long_form, case_type)
		MASS_G_KG_PREFIXED_T: # g, kg, t, kt, Mt, Gt, Tt, etc.
			if x < units.KG:
				return number_unit(x, "g", precision, num_type, long_form, case_type)
			elif x < units.TONNE:
				return number_unit(x, "kg", precision, num_type, long_form, case_type)
			return number_prefixed_unit(x, "t", precision, num_type, long_form, case_type)
		MASS_RATE_G_KG_PREFIXED_T_PER_D: # g/d, kg/d, t/d, kt/d, Mt/d, Gt/d, etc.
			if x < units.KG / units.DAY:
				return number_unit(x, "g/d", precision, num_type, long_form, case_type)
			elif x < units.TONNE / units.DAY:
				return number_unit(x, "kg/d", precision, num_type, long_form, case_type)
			return number_prefixed_unit(x, "t/d", precision, num_type, long_form, case_type)
		TIME_D_Y:
			if x <= 1000.0 * units.DAY:
				return number_unit(x, "d", precision, num_type, long_form, case_type)
			else:
				return number_unit(x, "y", precision, num_type, long_form, case_type)
		VELOCITY_MPS_KMPS: # km/s if >= 1.0 km/s
			if x < units.KM / units.SECOND:
				return number_unit(x, "m/s", precision, num_type, long_form, case_type)
			return number_unit(x, "km/s", precision, num_type, long_form, case_type)
		VELOCITY_MPS_KMPS_C: # c if >= 0.1 c
			if x < units.KM / units.SECOND:
				return number_unit(x, "m/s", precision, num_type, long_form, case_type)
			elif x < 0.1 * units.SPEED_OF_LIGHT:
				return number_unit(x, "c", precision, num_type, long_form, case_type)
			return number_unit(x, "km/s", precision, num_type, long_form, case_type)
		LATITUDE:
			return latitude(x, precision, long_form, case_type)
		LONGITUDE:
			return longitude(x, precision, long_form, case_type)
			
	assert(false, "Unkknown option_type: " + String(option_type))
	return String(x)


func latitude_longitude(lat_long: Vector2, decimal_pl := 0, lat_long_type := N_S_E_W,
		long_form := false, case_type := CASE_MIXED) -> String:
	return latitude(lat_long[0], decimal_pl, lat_long_type, long_form, case_type) + " " \
			+ longitude(lat_long[1], decimal_pl, lat_long_type, long_form, case_type)


func latitude(x: float, decimal_pl := 0, lat_long_type := N_S_E_W, long_form := false,
		case_type := CASE_MIXED) -> String:
	x = rad_to_deg(x)
	x = wrapf(x, -180.0, 180.0)
	var suffix: String
	if lat_long_type == N_S_E_W:
		if x > -0.0001: # prefer N if nearly 0 after conversion
			suffix = tr("TXT_NORTH") if long_form else tr("TXT_NORTH_SHORT")
		else:
			suffix = tr("TXT_SOUTH") if long_form else tr("TXT_SOUTH_SHORT")
		x = abs(x)
	elif lat_long_type == LAT_LONG:
		suffix = tr("TXT_LATITUDE") if long_form else tr("TXT_LATITUDE_SHORT")
	else: # PITCH_YAW
		suffix = tr("TXT_PITCH")
	if lat_long_type != N_S_E_W or long_form: # don't lower case N, S
		if case_type == CASE_LOWER:
			suffix = suffix.to_lower()
		elif case_type == CASE_UPPER:
			suffix = suffix.to_upper()
	return "%.*f\u00B0 %s" % [decimal_pl, x, suffix]


func longitude(x: float, decimal_pl := 0, lat_long_type := N_S_E_W, long_form := false,
		case_type := CASE_MIXED) -> String:
	x = rad_to_deg(x)
	var suffix: String
	if lat_long_type == N_S_E_W:
		x = wrapf(x, -180.0, 180.0)
		if x > -0.0001 and x < 179.9999: # nearly 0 is E; nearly 180 is W
			suffix = tr("TXT_EAST") if long_form else tr("TXT_EAST_SHORT")
		else:
			suffix = tr("TXT_WEST") if long_form else tr("TXT_WEST_SHORT")
		x = abs(x)
	elif lat_long_type == LAT_LONG:
		x = wrapf(x, 0.0, 360.0)
		suffix = tr("TXT_LONGITUDE") if long_form else tr("TXT_LONGITUDE_SHORT")
	else: # PITCH_YAW
		x = wrapf(x, -180.0, 180.0)
		suffix = tr("TXT_YAW")
	if lat_long_type != N_S_E_W or long_form: # don't lower case E, W
		if case_type == CASE_LOWER:
			suffix = suffix.to_lower()
		elif case_type == CASE_UPPER:
			suffix = suffix.to_upper()
	return "%.*f\u00B0 %s" % [decimal_pl, x, suffix]


func number(x: float, precision := 3, num_type := NUM_DYNAMIC) -> String:
	# precision <= 0 displays "as is" regardless of num_type. This will often
	# show inappropriately large precision if there have been unit conversions.
	# see NUM_ enums for num_type.
	
	if precision <= 0:
		return (String(x))
		
	# specified decimal places
	if num_type == NUM_DECIMAL_PL:
		return ("%.*f" % [precision, x])
	
	# All below use significant digits, not decimal places!
	# handle 0.0 case
	if x == 0.0: # don't do '0.00e0' even if NUM_SCIENTIFIC
		return "%.*f" % [precision - 1, 0.0] # e.g., '0.00' for precision 3
		
	var abs_x := abs(x)
	var pow10 := floor(log(abs_x) / LOG_OF_10)
	
	if num_type == NUM_PRECISION:
		var decimal_pl := precision - int(pow10) - 1
		if decimal_pl > 0:
			return "%.*f" % [decimal_pl, x] # e.g., '0.0555'
		if decimal_pl == 0:
			return "%.f" % x # whole number, '555'
		else: # remove over-precision
			var divisor := pow(10.0, -decimal_pl)
			x = round(x / divisor)
			return String(x * divisor) # '555000'
	
	# handle 0.01 - 99999 for NUM_DYNAMIC
	if num_type == NUM_DYNAMIC and abs_x < 99999.5 and abs_x > 0.01:
		var decimal_pl := precision - int(pow10) - 1
		if decimal_pl > 0:
			return "%.*f" % [decimal_pl, x] # e.g., '0.0555'
		else:
			return "%.f" % x # whole number, allow over-precision
	
	# scientific
	var divisor := pow(10.0, pow10)
	x = x / divisor if !is_zero_approx(divisor) else 1.0
	var exp_precision := pow(10.0, precision - 1)
	var precision_rounded := round(x * exp_precision) / exp_precision
	if precision_rounded == 10.0: # prevent '10.00e3' after rounding
		x /= 10.0
		pow10 += 1
	return "%.*f%s%s" % [precision - 1, x, exp_str, pow10] # e.g., '5.55e5'


func named_number(x: float, precision := 3, case_type := CASE_MIXED) -> String:
	# returns integer string up to "999999", then "1.00 Million", etc.;
	if abs(x) < 1e6:
		return "%.f" % x
	var exp_3s_index := int(floor(log(abs(x)) / (LOG_OF_10 * 3.0)))
	var lg_num_index := exp_3s_index - 2
	if lg_num_index < 0: # shouldn't happen but just in case
		return "%.f" % x
	if lg_num_index >= _n_lg_numbers:
		lg_num_index = _n_lg_numbers - 1
		exp_3s_index = lg_num_index + 2
	x /= pow(10.0, exp_3s_index * 3)
	var lg_number_str: String = large_numbers[lg_num_index]
	if case_type == CASE_LOWER:
		lg_number_str = lg_number_str.to_lower()
	elif case_type == CASE_UPPER:
		lg_number_str = lg_number_str.to_upper()
	return number(x, precision, NUM_DYNAMIC) + " " + lg_number_str


func number_unit(x: float, unit: String, precision := 3, num_type := NUM_DYNAMIC,
		long_form := false, case_type := CASE_MIXED) -> String:
	# unit must be in multipliers or functions dicts (by default these are
	# MULTIPLIERS and FUNCTIONS in ivoyager/static/units.gd)
	x = units.convert_quantity(x, unit, false, false, _multipliers, _functions)
	var number_str := number(x, precision, num_type)
	if long_form and long_forms.has(unit):
		unit = long_forms[unit]
	elif short_forms.has(unit):
		unit = short_forms[unit]
	else:
		unit = " " + unit
	if case_type == CASE_LOWER:
		unit = unit.to_lower()
	elif case_type == CASE_UPPER:
		unit = unit.to_upper()
	return number_str + unit


func number_prefixed_unit(x: float, unit: String, precision := -1, num_type := NUM_DYNAMIC,
		long_form := false, case_type := CASE_MIXED) -> String:
	# Example results: "1.00 Gt" or "1.00 Gigatonnes" (w/ unit = "t" and
	# long_form = false or true, repspectively). You won't see scientific
	# notation unless the internal value falls outside of the prefixes range.
	# WARNING: Don't try to prefix an already-prefixed unit (eg, km) or any
	# composite unit where the first unit has a power other than 1 (eg, m^3).
	# The result will look weird and/or be wrong (eg, 1000 m^3 -> 1.00 km^3).
	# unit = "" ok; otherwise, unit must be in multipliers or functions dicts.
	if unit:
		x = units.convert_quantity(x, unit, false, false, _multipliers, _functions)
	var exp_3s_index := 0
	if x != 0.0:
		exp_3s_index = int(floor(log(abs(x)) / (LOG_OF_10 * 3.0)))
	var si_index := exp_3s_index + _prefix_offset
	if si_index < 0:
		si_index = 0
		exp_3s_index = -_prefix_offset
	elif si_index >= _n_prefixes:
		si_index = _n_prefixes - 1
		exp_3s_index = si_index - _prefix_offset
	x /= pow(10.0, exp_3s_index * 3)
	var number_str := number(x, precision, num_type)
	var prepend_space := true
	if long_form and long_forms.has(unit):
		unit = long_forms[unit].lstrip(" ")
	elif short_forms.has(unit):
		unit = short_forms[unit]
		if unit.begins_with(" "):
			unit = unit.lstrip(" ")
		else:
			prepend_space = false
	if long_form:
		unit = prefix_names[si_index] + unit
	else:
		unit = prefix_symbols[si_index] + unit
	if case_type == CASE_LOWER:
		unit = unit.to_lower()
	elif case_type == CASE_UPPER:
		unit = unit.to_upper()
	if prepend_space:
		return number_str + " " + unit
	return number_str + unit
