# info_subpanel.gd
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
# Abstract base class for InfoPanel subpanels. This node is not persisted but
# you can pass non-object data into subpanel_persist, which will be passed to
# new subpanels after game load.

extends Control
class_name InfoSubpanel

enum {AVAILABLE, DISABLED, HIDDEN}

var subpanel_persist := [] # subpanel can supply data it needs to persist


static func get_availability(_selection_manager: SelectionManager) -> int:
	# must be static!
	return HIDDEN

# Overwrite functions
func init_selection() -> void :
	# called when selection_manager changes or this subpanel selected
	pass

func update_selection() -> void:
	# Test is_visible_in_tree() before doing a lot of work.
	pass

func prepare_persist_data() -> void:
	# Called before game save and panel cloning; set non-obect data in
	# subpanel_persist. Useful for a sub-subpanel selection_manager, for example.
	# (Optional)
	pass

func load_persist_data() -> void:
	# Do something with subpanel_persist data. (Optional)
	pass

# Virtual & private functions
func _init():
	_on_init()

func _on_init():
	connect("tree_exiting", self, "_prepare_to_free")
	Global.connect("about_to_free_procedural_nodes", self, "_prepare_to_free")

func _prepare_to_free():
	if Global.is_connected("about_to_free_procedural_nodes", self, "_prepare_to_free"):
		Global.disconnect("about_to_free_procedural_nodes", self, "_prepare_to_free")
