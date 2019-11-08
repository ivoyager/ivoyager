# enum_globalizer.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2019 Charlie Whitfield
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
