# enum_globalizer.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2019 Charlie Whitfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# *****************************************************************************
#
# This class should be accessed by your project builder or a subclass only.
# To append the "globalize" array before project_init(), hook up to
# ProjectBuilder "project_objects_instantiated" signal. Alternatively, call add()
# directly from project builder or a subclass.

extends Reference
class_name EnumGlobalizer

var _enums: Dictionary = Global.enums

var globalize := [
	[SelectionItem.SelectionType, "SelectionType", ""],
	[TableReader.DataTableTypes, "DataTableTypes", ""],
	]

func add(enum_dict: Dictionary, enum_dict_name := "", reverse_suffix := "") -> void:
	# Individual _enums and enum_dict_name (if provided) must be globally unique.
	# If reverse_suffix is provided, a "reverse enum" dict is made with key =
	# enum_dict_name + reverse_suffix.
	for key in enum_dict:
		assert(!_enums.has(key))
		_enums[key] = enum_dict[key]
	if enum_dict_name:
		assert(!_enums.has(enum_dict_name))
		_enums[enum_dict_name] = enum_dict
		if reverse_suffix:
			var reverse_dict_name := enum_dict_name + reverse_suffix
			var reverse_dict := {}
			for key in enum_dict:
				reverse_dict[enum_dict[key]] = key
			_enums[reverse_dict_name] = reverse_dict

func project_init() -> void:
	for args in globalize:
		add(args[0], args[1], args[2])
