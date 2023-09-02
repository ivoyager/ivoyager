# table_units.gd
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
@static_unload
extends Object

# This static class defines default units and dictionaries for converting table
# float values to internal base SI units.
#
# It may be convenient to create a 'class_name Units' object in your project
# with your own unit constants and 'unit_multipliers' and 'unit_lambdas'
# dictionaries. This way you can code unit quantities in your files as
# constants (e.g., 'const SOME_TIME_CONSTANT = 4.0 * Units.DAY'). If you do,
# be sure to provide your conversion dictionaries when calling
# IVTableData.postprocess_tables(), or set conversion dictionaries directly in
# IVTableUtils.
#
# For GUI unit display, feel free to use our open-source IVQuantityFormatter:
# https://github.com/ivoyager/ivoyager/blob/master/program/quantity_formatter.gd


# SI base units
const SECOND := 1.0
const METER := 1.0
const KG := 1.0
const AMPERE := 1.0
const KELVIN := 1.0
const CANDELA := 1.0

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
# (Some odd choices may be blamed on our use in a solar system simulator.) 
#
# We look for unit symbol first in mulitipliers and then in lambdas.

static var unit_multipliers := {
	# Duplicated symbols have leading underscore(s).

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
	&"cd sr" : CANDELA, # sr is dimentionless
	&"lm" : CANDELA, # lumen
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
}

static var unit_lambdas := { # can't make const!
	&"degC" : func convert_centigrade(x: float, to_internal := true) -> float:
		if to_internal:
			return (x + 273.15) * KELVIN
		else:
			return x / KELVIN - 273.15,
	&"degF" : func convert_fahrenheit(x: float, to_internal := true) -> float:
		if to_internal:
			return (x + 459.67) / 1.8 * KELVIN
		else:
			return x / KELVIN * 1.8 - 459.67,
}

