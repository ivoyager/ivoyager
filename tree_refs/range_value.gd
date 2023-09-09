# range_value.gd
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
class_name IVRangeValue
extends RefCounted

# WIP - NOT IMPLEMENTED YET!
# Holds and creates display string for value that may have min, mean, max.
# Use NAN for not applicable (i.e., don't show). Use INF for ?.

var qformat := IVQFormat # TODO: Change to const when Godot allows

var mean := NAN
var minimum := NAN
var maximum := NAN



func get_text(dynamic_unit_type: int, precision := -1, num_type := IVQFormat.NUM_DYNAMIC,
		long_form := false, case_type := IVQFormat.CASE_MIXED) -> String:
	var mean_str := ""
	var min_str := ""
	var max_str := ""
	if is_inf(mean):
		mean_str = "?"
	elif !is_nan(mean):
		mean_str = qformat.dynamic_unit(mean, dynamic_unit_type, precision, num_type,
				long_form, case_type)
	if is_inf(minimum):
		mean_str = "?"
	elif !is_nan(minimum):
		min_str = qformat.dynamic_unit(minimum, dynamic_unit_type, precision, num_type,
				long_form, case_type)
	if is_inf(maximum):
		mean_str = "?"
	elif !is_nan(maximum):
		max_str = qformat.dynamic_unit(maximum, dynamic_unit_type, precision, num_type,
				long_form, case_type)
	
	var result_str := ""
	if min_str:
		result_str = tr("MIN") + ": " + min_str
	if mean_str:
		result_str += "; " + tr("MEAN") + ": " + mean_str
	if max_str:
		result_str += "; " + tr("MAX") + ": " + max_str
	return result_str

