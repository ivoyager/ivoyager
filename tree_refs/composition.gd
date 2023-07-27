# composition.gd
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
class_name IVComposition
extends RefCounted

# This object is designed for simple display. It could be extended to do more.
# For I, Voyager, we keep amounts as strings to preserve significant digits.

enum CompositionType {
	BY_WEIGHT, 
	BY_VOLUME,
}

const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL
const PERSIST_PROPERTIES := [
	"type",
	"components",
]

# persisted
var type: int
var components := {} # chemicals w/ amount string or null


func get_labels_values_display(labels_prefix := "") -> Array:
	var result := ["", ""] # label, value
	for key in components:
		var value = components[key]
		var optn_newline := "\n" if result[0] else ""
		match typeof(value):
			TYPE_NIL:
				result[0] += optn_newline + labels_prefix + key
				result[1] += optn_newline + ""
			TYPE_STRING:
				result[0] += optn_newline + labels_prefix + key
				result[1] += optn_newline + value
	return result
