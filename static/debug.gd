# debug.gd
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
# Wrap all calls in assert(). E.g., assert(Debug.dlog("something")).

class_name Debug

static func dlog(value) -> bool:
	var file: File = IVGlobal.debug_log
	if !file:
		return true
	var line := str(value)
	file.store_line(line)
	return true

static func no_nans(thing) -> bool:
	# returns false for unsupported typeof(thing)
	var indexes := []
	match typeof(thing):
		TYPE_ARRAY:
			indexes = range(thing.size())
		TYPE_DICTIONARY:
			indexes = thing.keys()
		TYPE_VECTOR3:
			indexes = range(3)
		TYPE_BASIS:
			if !no_nans(thing.x) or !no_nans(thing.y) or !no_nans(thing.z):
				return false
		TYPE_TRANSFORM:
			if !no_nans(thing.basis) or !no_nans(thing.origin):
				return false
		_:
			return false
	if indexes:
		for index in indexes:
			if is_nan(thing[index]):
				return false
	return true

