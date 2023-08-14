# selection_builder.gd
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
class_name IVSelectionBuilder
extends RefCounted


# DEPRECIATE: This can be done in init function.


# project vars
var above_bodies_selection_name := "" # "SYSTEM_SOLAR_SYSTEM"


# private
var _Selection_: Script


func _project_init() -> void:
	_Selection_ = IVGlobal.script_classes._Selection_


func build_body_selection(body: IVBody) -> IVSelection:
	var parent_body := body.get_parent() as IVBody
	@warning_ignore("unsafe_method_access") # possible replacement class
	var selection: IVSelection = _Selection_.new()
	selection.is_body = true
	selection.spatial = body
	selection.body = body
	selection.name = body.name
	selection.gui_name = tr(body.name)
	selection.texture_2d = body.texture_2d
	selection.texture_slice_2d = body.texture_slice_2d
	if parent_body:
		selection.up_selection_name = parent_body.name
		# TODO: Some special handling for barycenters
	else:
		selection.up_selection_name = above_bodies_selection_name
	return selection


