# info_subpanel.gd
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
