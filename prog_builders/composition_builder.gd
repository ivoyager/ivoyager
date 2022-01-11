# composition_builder.gd
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

class_name IVCompositionBuilder

var _Composition_: Script

var item_regex := RegEx.new()


func make_from_string(string: String) -> IVComposition:
	var composition: IVComposition = _Composition_.new()
	composition.components = _parse_simple_list_string(string)
	return composition


func _project_init() -> void:
	_Composition_ = IVGlobal.script_classes._Composition_
	item_regex.compile("(?:([~\\d\\.]+%|trace) )?(.+)")
#	item_regex.compile("(?:([~\\d\\.]+%) )?(.+)")

func _parse_simple_list_string(string: String) -> Dictionary:
	# "item 0.0%, item2 0.0%"
	var list := string.split(", ")
	var dict := {}
	for item in list:
		var item_match := item_regex.search(item)
		var component: String = item_match.strings[2]
		if item_match.strings[1]:
			dict[component] = item_match.strings[1]
		else:
			dict[component] = null
	return dict
