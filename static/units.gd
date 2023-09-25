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
# Compound multiplier units are added here for quick lookup. These could be
# parsed by IVTableUtils.convert_unit() but it is slower to do so.
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
	&"a" : YEAR, # Julian year symbol
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
	&"1/Cy" : 1.0 / CENTURY,
	# area
	&"m^2" : METER * METER,
	&"km^2" : KM * KM,
	&"ha" : HECTARE,
	# volume
	&"l" : LITER,
	&"L" : LITER,
	&"m^3" : METER * METER * METER,
	# velocity
	&"m/s" : METER / SECOND,
	&"km/s" : KM / SECOND,
	&"au/Cy" : AU / CENTURY,
	&"c" : SPEED_OF_LIGHT,
	# acceleration/gravity
	&"m/s^2" : METER / (SECOND * SECOND),
	&"_g" : STANDARD_GRAVITY,
	# angular velocity
	&"rad/s" : 1.0 / SECOND, 
	&"deg/d" : DEG / DAY,
	&"deg/Cy" : DEG / CENTURY,
	# particle density
	&"m^-3" : 1.0 / (METER * METER * METER),
	# density
	&"g/cm^3" : GRAM / (CM * CM * CM),
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
	&"Wh" : WATT * HOUR,
	&"kWh" : 1e3 * WATT * HOUR,
	&"MWh" : 1e6 * WATT * HOUR,
	&"GWh" : 1e9 * WATT * HOUR,
	&"eV" : ELECTRONVOLT,
	# power
	&"W" : WATT,
	&"kW" : 1e3 * WATT,
	&"MW" : 1e6 * WATT,
	&"GW" : 1e9 * WATT,
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
	# information
	&"bit" : 1.0,
	&"B" : 8.0,
	# information (base 10)
	&"kbit" : 1e3,
	&"Mbit" : 1e6,
	&"Gbit" : 1e9,
	&"Tbit" : 1e12,
	&"kB" : 8e3,
	&"MB" : 8e6,
	&"GB" : 8e9,
	&"TB" : 8e12,
	# information (base 2)
	&"Kibit" : 1024.0,
	&"Mibit" : 1024.0 ** 2,
	&"Gibit" : 1024.0 ** 3,
	&"Tibit" : 1024.0 ** 4,
	&"KiB" : 8.0 * 1024.0,
	&"MiB" : 8.0 * 1024.0 ** 2,
	&"GiB" : 8.0 * 1024.0 ** 3,
	&"TiB" : 8.0 * 1024.0 ** 4,
	# misc
	&"deg/Cy^2" : DEG / (CENTURY * CENTURY),
}

static var lambdas := {
	&"degC" : func convert_centigrade(x: float, to_internal := true) -> float:
		return x + 273.15 if to_internal else x - 273.15,
	&"degF" : func convert_fahrenheit(x: float, to_internal := true) -> float:
		return  (x + 459.67) / 1.8 if to_internal else x * 1.8 - 459.67,
}

