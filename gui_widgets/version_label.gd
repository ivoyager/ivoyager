# version_label.gd
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
class_name IVVersionLabel
extends Label

# GUI widget.
#
# Formats as 'Planetarium 0.0.14a-dev 20230223' with options below.
# If project == false or IVGlobal.project_name == "", will give ivoyager version.


var use_project := true # otherwise, displays ivoyager version
var multiline := true # splits format at spaces
var add_name := false
var add_ymd := false
var add_ymd_if_dev := true


func _ready():
	set_label()


func set_label() -> void:
	# Call directly if properties changed after added to tree.
	var sep := "\n" if multiline else " "
	var is_project := use_project and IVGlobal.project_name
	text = ""
	if add_name:
		text += (IVGlobal.project_name if is_project else "I, Voyager") + sep
	text += IVGlobal.project_version if is_project else IVGlobal.IVOYAGER_VERSION
	text += IVGlobal.project_build if is_project else IVGlobal.IVOYAGER_BUILD
	var state := IVGlobal.project_state if is_project else IVGlobal.IVOYAGER_STATE
	if state:
		text += "-" + state
	if add_ymd or (add_ymd_if_dev and state == "dev"):
		text += sep + str(IVGlobal.project_ymd if is_project else IVGlobal.IVOYAGER_YMD)

