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


static func dprint(arg, arg2 = "", arg3 = "", arg4 = "") -> bool:
	# For >4 items, just use an array.
	prints(arg, arg2, arg3, arg4)
	return true


static func dprint_orphan_nodes() -> bool:
	IVGlobal.print_orphan_nodes()
	return true


static func dlog(arg) -> bool:
	var file := IVGlobal.debug_log
	if !file:
		return true
	var line := str(arg)
	file.store_line(line)
	return true


static func signal_verbosely(object: Object, signal_name: String, prefix: String) -> void:
	# Call before any other signal connections; signal must have <= 8 args.
	object.connect(signal_name, IVDebug._on_verbose_signal.bind(prefix + " " + signal_name))


static func signal_verbosely_all(object: Object, prefix: String) -> void:
	# See signal_verbosely. Prints all emitted signals from object.
	var signal_list := object.get_signal_list()
	for signal_dict in signal_list:
		var signal_name: String = signal_dict.name
		signal_verbosely(object, signal_name, prefix)


static func _on_verbose_signal(arg, arg2 = null, arg3 = null, arg4 = null,
		arg5 = null, arg6 = null, arg7 = null, arg8 = null, arg9 = null) -> void:
	# Expects signal_name as last bound argument.
	var args := [arg, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9]
	while args[-1] == null:
		args.pop_back()
	var debug_text: String = args.pop_back()
	prints(debug_text, args)


static func no_nans(thing) -> bool:
	# returns false for unsupported typeof(thing)
	var indexes := []
	match typeof(thing):
		TYPE_ARRAY:
			@warning_ignore("unsafe_method_access")
			indexes = range(thing.size())
		TYPE_DICTIONARY:
			@warning_ignore("unsafe_method_access")
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
