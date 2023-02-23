# top_gui.gd
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
class_name IVTopGUI
extends Control

# An extension can replace the top GUI in IVProjectBuilder 
# (singletons/project_builder.gd) but see comments below:
# 
# Many GUI widgets expect to find 'selection_manager' somewhere in their 
# Control ancestry tree. This property must be assigned before IVGlobal signal
# 'system_tree_ready'.
#
# 'PERSIST_' constants are needed here for save/load persistence of the
# SelectionManager instance.
#
# IVThemeManager (prog_refs/theme_manager.gd) sets the 'main' Theme in IVGlobal
# dictionary 'themes', which is applied here. Some Theme changes are needed for
# proper GUI widget appearance.

const PERSIST_MODE := IVEnums.PERSIST_PROPERTIES_ONLY # don't free on load
const PERSIST_PROPERTIES := ["selection_manager"]

var selection_manager: IVSelectionManager


func _init() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	IVGlobal.connect("project_builder_finished", self, "_on_project_builder_finished")
	IVGlobal.connect("system_tree_built_or_loaded", self, "_on_system_tree_built_or_loaded")


func _on_project_builder_finished() -> void:
	theme = IVGlobal.themes.main


func _on_system_tree_built_or_loaded(is_new_game: bool) -> void:
	if is_new_game:
		var _SelectionManager_: Script = IVGlobal.script_classes._SelectionManager_
		selection_manager = _SelectionManager_.new()
		add_child(selection_manager)

