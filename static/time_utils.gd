# time_utils.gd
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
# "Date" here ALWAYS refers to Gregorian y, m, d.
# JD is Julian Date, a float (astronomy, not computer mainframe!)
# JDN is Julian Day Number.
# Julian calculations from https://en.wikipedia.org/wiki/Julian_day.
#
# Note that JDN is not aligned with Earth's rotation!
# Our clock is a "UT" based on Earth's rotation. Since we don't
# simulate variation in Earth rotation, we have a straightforward UT based on
# a constant. It's not UTC and not quite UT1, but closer to the latter in
# concept. Specifically, a clock second is not exactly an SI second.


class_name TimeUtils

enum {SUN, MON, TUE, WED, THU, FRI, SAT}

# these are for sim_time conversion only!
const SECOND := UnitDefs.SECOND
const MINUTE := UnitDefs.MINUTE
const HOUR := UnitDefs.HOUR
const DAY := UnitDefs.DAY

const J2000_JD := 2451545.0 # Julian Date (JD) of J2000 epoch time 
const EARTH_ROTATION_D := 0.99726968 # same as planets.csv table!
const EARTH_ROTATION := EARTH_ROTATION_D * DAY # in sim_time units

# We should avoid conversion to & from JD, since it requires adding numbers
# that differ by many orders of magnitude. Our sim_time is time since J2000,
# easily converted to days. UT1 is on a different scale (clock s are not SI s!)
# but it is also referenced to J2000.
# 
# var ut1 = get_ut1(sim_time)
# var jdn = get_jdn_for_ut1(ut1)
# set_clock(ut1, clock)
# set_date(jdn, date)
# 

static func get_ut1(sim_time: float) -> float:
	# Use fposmod(ut1) to get fraction of day
	var earth_rotations := sim_time / EARTH_ROTATION
	# Earth Rotation Angle = TAU * fposmod(earth_rotations, 1.0)
	return (earth_rotations - 0.7790572732640) / 1.00273781191135448

static func get_jdn_for_ut1(ut1: float) -> int:
	# Get JDN for UT1 12:00; this applies the full UT1 day.
	var ut1_1200 := floor(ut1) + 0.5
	var earth_rotations := ut1_1200 * 1.00273781191135448 + 0.7790572732640
	var j2000_days := earth_rotations * EARTH_ROTATION_D
	return int(j2000_days + J2000_JD)

static func set_date(jdn: int, date: Array) -> void:
	# Gregorian date!
	# Date is "for the afternoon at the beginning of the given Julian day",
	# according to Wiki. Arghh! JDN rollover has no relationship to UT
	# midnight!
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	var f := jdn + 1401 + ((((4 * jdn + 274277) / 146097) * 3) / 4) - 38
	var e := 4 * f + 3
	# warning-ignore:integer_division
	var g := (e % 1461) / 4
	var h := 5 * g + 2
	# warning-ignore:integer_division
	var m := (((h / 153) + 2) % 12) + 1
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	date[0] = (e / 1461) - 4716 + ((14 - m) / 12) # year
	# warning-ignore:integer_division
	date[1] = m # month
	# warning-ignore:integer_division
	date[2] = ((h % 153) / 5) + 1 # day

static func set_clock(ut1: float, clock: Array) -> void:
	# ut1 is fraction of day
	var total_seconds := int(ut1 * 86400.0)
	clock[0] = total_seconds / 3600
	# warning-ignore:integer_division
	clock[1] = (total_seconds / 60) % 60
	clock[2] = total_seconds % 60



static func get_jd(sim_time: float) -> float:
	return sim_time / DAY + J2000_JD # sim_time starts at noon, 1/1/2000!

static func get_jdn_from_date(y: int, m: int, d: int) -> int:
	# Gregorian date!
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	var jdn := (1461 * (y + 4800 + (m - 14)/12))/4
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	jdn += (367 * (m - 2 - 12 * ((m - 14)/12)))/12
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	# warning-ignore:integer_division
	jdn -= (3 * ((y + 4900 + (m - 14)/12)/100))/4 + d - 32075
	return jdn

static func get_jd_from_jdn_hms(jdn: int, h := 12, m := 0, s := 0) -> float:
	var jd := jdn + (h - 12) / 24.0 + m / 1440.0 + s / 86400.0
	if h < 12:
		jd += 1
	return jd

static func get_jd_from_jdn_ut1(jdn: int, ut1 := 0.5) -> float:
	var jd := jdn + ut1 - 0.5
	if ut1 < 0.5:
		jd += 1
	return jd

static func get_day_of_week(jdn: int) -> int: # see enums above
	return (jdn + 1) % 7

