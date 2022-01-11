# version_label.gd
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
# GUI widget. Use set_version_label to display an extension version. Otherwise,
# displays I, Voyager version.

extends Label

func set_version_label(extension_name := "", include_name := true,
		prepend_v := true, name_version_separator := " ",
		prepend_text := "", append_text := "") -> void:
	# extension_name = "" will display I, Voyager version
	var program_name := ""
	var version := ""
	if !extension_name: # display I, Voyager version
		program_name = "I, Voyager"
		version = IVGlobal.IVOYAGER_VERSION
	else:
		for loop_info in IVGlobal.extensions:
			var loop_name: String = loop_info[0]
			if loop_name == extension_name:
				program_name = extension_name
				version = loop_info[1]
				break
	if !version:
		return # failed to find extension
	var label_text := prepend_text
	if include_name:
		label_text += program_name + name_version_separator
	if prepend_v:
		label_text += "v"
	label_text += version + append_text
	text = label_text

func _ready():
	set_version_label()
