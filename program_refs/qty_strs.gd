# qty_strs.gd
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
# Be careful with units! Assumed input unit is specified in function comment,
# sometimes with optional args to change. display_type args are used only for
# resulting display string. We use 3 significant digets throughout (you'll have
# to extend and override functions to change that).

class_name QtyStrs

enum { # func_type for get_str()
	FUNC_NUMBER,
	FUNC_SCIENTIFIC,
	FUNC_NAMED_NUMBER,
	FUNC_LENGTH, # display LENGTH_M_KM_AU
	FUNC_LENGTH_SCALED, # display LENGTH_M_KM_AU
	FUNC_MASS, # display MASS_G_KG
	FUNC_MASS2, # display MASS_G_KG_PREFIXED_T
	FUNC_MASS_T, # input tonnes; display MASS_T
	FUNC_MASS_T2, # input tonnes; display MASS_G_KG_PREFIXED_T
	FUNC_VELOCITY, # input km/s; display m/s or km/s
	FUNC_AREA,
	FUNC_AREA_HA,
}

enum { # case_type
	MIXED_CASE, # "1.00 Million"
	LOWER_CASE # "1.00 million"
	UPPER_CASE, # "1.00 MILLION"
}

enum { # display_type for length()
	LENGTH_M,
	LENGTH_KM,
	LENGTH_AU,
	LENGTH_M_KM, # m if x < 1.0 km
	LENGTH_KM_AU, # au if x > 0.1 au
	LENGTH_M_KM_AU,
	LENGTH_PREFIXED_M # m, km, Mm, Gm, etc.
}

enum { # display_type for mass()
	MASS_G,
	MASS_KG,
	MASS_T, # t or tonne
	MASS_G_KG, # g if < 1.0 kg
	MASS_G_KG_T, # g if < 1.0 kg; t if x >= 1000.0 kg 
	MASS_PREFIXED_G, # g, kg, Mg, Gg, etc.
	MASS_PREFIXED_T, # t, kt, Mt, Gt, etc.
	MASS_G_KG_PREFIXED_T, # g, kg, t, kt, Mt, Gt, etc.
}

enum { # input_type for velocity()
	V_INPUT_MPS, # m/s
	V_INPUT_KMPS, # km/s
	V_INPUT_KMPH, # km/h
	V_INPUT_KMPD, # km/d (sim standard units)
	V_INPUT_C, # fraction c
}

enum { # display_type for velocity()
	VELOCITY_MPS, # m/s
	VELOCITY_KMPS, # km/s
	VELOCITY_MPS_KMPS, # km/s if >= 1.0 km/s
	VELOCITY_KMPH, # km/h
	VELOCITY_C, # fraction c
	VELOCITY_MPS_KMPS_C, # c if >= 0.1 c
}

const LOG_OF_10 := log(10)

# project vars
var exp_str := "e" # or change to "E" or "x10^"
var prefix_names := ["kilo", "Mega", "Giga", "Tera", "Peta", "Exa", "Zetta", "Yotta"]
var prefix_symbols := ["k", "M", "G", "T", "P", "E", "Z", "Y"] # e3, e6, ... e24
var large_numbers := ["TXT_MILLION", "TXT_BILLION", "TXT_TRILLION", "TXT_QUADRILLION",
	"TXT_QUINTILLION", "TXT_SEXTILLION", "TXT_SEPTILLION", "TXT_OCTILLION",
	 "TXT_NONILLION", "TXT_DECILLION"] # e6, e9, e12, ... e33; localized in project_init()

# private
var _scale: float
var _n_prefixes: int
var _n_lg_numbers: int


func project_init():
	_scale = Global.scale
	_n_prefixes = prefix_symbols.size()
	_n_lg_numbers = large_numbers.size()
	for i in range(_n_lg_numbers):
		large_numbers[i] = tr(large_numbers[i])
	assert(_n_prefixes == prefix_names.size())

func get_str(x: float, func_type: int, short := true) -> String:
	# wrapper to call functions below
	match func_type:
		FUNC_NUMBER:
			return String(x) # TODO: "1 000 000 000" format?
		FUNC_SCIENTIFIC:
			return scientific(x)
		FUNC_NAMED_NUMBER:
			return named_number(x) # "1.00 Million" after "999999"
		FUNC_LENGTH: # input in km
			return length(x, false, LENGTH_M_KM_AU, short)
		FUNC_LENGTH_SCALED: # input is sim scale
			return length(x, true, LENGTH_M_KM_AU, short)
		FUNC_MASS:
			return mass(x, MASS_G_KG, short)
		FUNC_MASS2:
			return mass(x, MASS_G_KG_PREFIXED_T, short)
		FUNC_MASS_T:
			return mass(x * 1000.0, MASS_T, short)
		FUNC_MASS_T2:
			return mass(x * 1000.0, MASS_G_KG_PREFIXED_T, short)
		FUNC_VELOCITY:
			return velocity(x, V_INPUT_KMPS, VELOCITY_MPS_KMPS, short)
		FUNC_AREA:
			pass # not supported yet
		_:
			assert(false)
	return ""

func scientific(x: float, force_scientific := false) -> String:
	# returns "0.0100" to "99999" as non-scientific unless force_scientific
	if x == 0.0:
		return "0.00" + exp_str + "0" if force_scientific else "0"
	var exponent := floor(log(abs(x)) / LOG_OF_10)
	if exponent > 4.0 or exponent < -2.0 or force_scientific:
		var divisor := pow(10.0, exponent)
		x = x / divisor if !is_zero_approx(divisor) else 1.0
		return "%.2f%s%s" % [x, exp_str, exponent] # e.g., 5.55e5
	elif exponent > 1.0:
		return "%.f" % x # 55555, 5555, or 555
	elif exponent == 1.0:
		return "%.1f" % x # 55.5
	elif exponent == 0.0:
		return "%.2f" % x # 5.55
	elif exponent == -1.0:
		return "%.3f" % x # 0.555
	else: # -2.0
		return "%.4f" % x # 0.0555

func named_number(x: float, case_type := MIXED_CASE) -> String:
	# returns integer string up to "999999", then "1.00 Million", etc.
	if abs(x) < 1e6:
		return "%.f" % x
	var lg_num_index = int(log(abs(x)) / (LOG_OF_10 * 3.0)) - 2
	if lg_num_index >= _n_lg_numbers:
		lg_num_index = _n_lg_numbers - 1
	x /= pow(10.0, 3 * (lg_num_index + 2))
	var lg_number_str: String = large_numbers[lg_num_index]
	if case_type == LOWER_CASE:
		lg_number_str = lg_number_str.to_lower()
	elif case_type == UPPER_CASE:
		lg_number_str = lg_number_str.to_upper()
	return scientific(x) + " " + lg_number_str

func number_prefix_unit(x: float, short := true, unit := "") -> String:
	# e.g., "1.00 G" or "1.00 Giga" + unit if provided
	var exponent := floor(log(abs(x)) / LOG_OF_10)
	if exponent < 3.0:
		return scientific(x) + " " + unit
	var si_index := int(exponent / 3.0) - 1
	if si_index >= _n_prefixes:
		si_index = _n_prefixes - 1
	x /= pow(10.0, 3.0 * (si_index + 1))
	var prefix: String = prefix_symbols[si_index] if short else prefix_names[si_index]
	return scientific(x) + " " + prefix + unit

func length(x: float, is_sim_scale := false, display_type := LENGTH_M_KM_AU, short := true) -> String:
	# x assumed to be in km unless is_sim_scale
	if is_sim_scale:
		x /= _scale
	var unit: String
	match display_type:
		LENGTH_M:
			x *= 1000.0
			unit = "m" if short else "meters"
		LENGTH_KM:
			unit = "km" if short else "kilometers"
		LENGTH_AU:
			x /= 149597870.7 # 1 au = 149597870.7 km
			unit = "au" if short else "astronomical units"
		LENGTH_KM_AU:
			if x > 14959787.07: # 0.1 au
				x /= 149597870.7
				unit = "au" if short else "astronomical units"
			else:
				unit = "km" if short else "kilometers"
		LENGTH_M_KM:
			if x < 1.0:
				x *= 1000.0
				unit = "m" if short else "meters"
			else:
				unit = "km" if short else "kilometers"
		LENGTH_M_KM_AU:
			if x < 1.0:
				x *= 1000.0
				unit = "m" if short else "meters"
			elif x > 14959787.07:
				x /= 149597870.7
				unit = "au" if short else "astronomical units"
			else:
				unit = "km" if short else "kilometers"
		LENGTH_PREFIXED_M:
			x *= 1000.0
			return number_prefix_unit(x, short, "m" if short else "meters")
		_:
			assert(false)
			unit = "!unknown length call!"
	return scientific(x) + " " + unit

func mass(x: float, display_type := MASS_G_KG, short := true) -> String:
	# x assumed to be in kg
	var unit: String
	match display_type:
		MASS_G:
			x *= 1000.0
			unit = "g" if short else "grams"
		MASS_KG:
			unit = "kg" if short else "kilograms"
		MASS_T:
			x /= 1000.0
			unit = "t" if short else "tonnes"
		MASS_G_KG:
			if x < 1.0:
				x *= 1000.0
				unit = "g" if short else "grams"
			else:
				unit = "kg" if short else "kilograms"
		MASS_G_KG_T:
			if x < 1.0:
				x *= 1000.0
				unit = "g" if short else "grams"
			elif x >= 1000.0:
				x /= 1000.0
				unit = "t" if short else "tonnes"
			else:
				unit = "kg" if short else "kilograms"
		MASS_PREFIXED_G:
			x *= 1000.0
			return number_prefix_unit(x, short, "g" if short else "grams")
		MASS_PREFIXED_T: # e.g., Yt or Yottatonne
			x /= 1000.0
			return number_prefix_unit(x, short, "t" if short else "tonnes")
		MASS_G_KG_PREFIXED_T:
			if x < 1.0:
				x *= 1000.0
				unit = "g" if short else "grams"
			elif x >= 1000.0:
				x /= 1000.0
				return number_prefix_unit(x, short, "t" if short else "tonnes")
			else:
				unit = "kg" if short else "kilograms"
		_:
			assert(false)
			unit = "!unknown mass call!"
	return scientific(x) + " " + unit

func velocity(x: float, input_type := V_INPUT_KMPS, display_type := VELOCITY_MPS_KMPS,
		short := true) -> String:
	match input_type:
		V_INPUT_MPS: # m/s
			x *= 86.4
		V_INPUT_KMPS: # km/s
			x *= 86400.0
		V_INPUT_KMPH: # km/h
			x *= 24.0
		V_INPUT_KMPD: # km/d (sim standard units)
			pass
		V_INPUT_C: # fraction c (299792458 m/s)
			x *= 25902068371.2
		_:
			assert(false)
	var unit: String
	match display_type:
		VELOCITY_MPS: # m/s
			x /= 86.4
			unit = "m/s" if short else "meters per second"
		VELOCITY_KMPS: # km/s
			x /= 86400.0
			unit = "km/s" if short else "kilometers per second"
		VELOCITY_MPS_KMPS: # km/s if >= 1.0 km/s
			if x < 86400.0:
				x /= 86.4
				unit = "m/s" if short else "meters per second"
			else:
				x /= 86400.0
				unit = "km/s" if short else "kilometers per second"
		VELOCITY_KMPH: # km/h
			x /= 24.0
			unit = "km/h" if short else "kilometers per hour"
		VELOCITY_C: # fraction c
			x /= 25902068371.2
			unit = "c" if short else "light speed"
		VELOCITY_MPS_KMPS_C: # c if >= 0.1 c
			if x < 86400.0:
				x /= 86.4
				unit = "m/s" if short else "meters per second"
			elif x >= 2590206837.12: # 0.1 c
				x /= 25902068371.2
				unit = "c" if short else "light speed"
			else:
				x /= 86400.0
				unit = "km/s" if short else "kilometers per second"
		_:
			assert(false)
			unit = "!unknown mass call!"
	return scientific(x) + " " + unit

