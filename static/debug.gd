# debug.gd
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
class_name IVDebug
extends Object

# Print & log functions return true so they can be wrapped in assert(). E.g.,
#     assert(IVDebug.dlog("something"))
#     assert(!DPRINT or IVDebug.dprint("something"))


static func dprint(value) -> bool:
	print(value)
	return true


static func dprint2(value1, value2) -> bool:
	print(value1, value2)
	return true


static func dprint3(value1, value2, value3) -> bool:
	print(value1, value2, value3)
	return true


static func dprint4(value1, value2, value3, value4) -> bool:
	print(value1, value2, value3, value4)
	return true


static func dlog(value) -> bool:
	var file := IVGlobal.debug_log
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
		TYPE_TRANSFORM3D:
			if !no_nans(thing.basis) or !no_nans(thing.origin):
				return false
		_:
			return false
	if indexes:
		for index in indexes:
			if is_nan(thing[index]):
				return false
	return true
