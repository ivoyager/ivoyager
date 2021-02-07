# projection_surface.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield
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
# Parent control for HUD labels or similar 2D objects. All children are freed
# on exit or game load.

extends Control
class_name ProjectionSurface

func project_init():
	pass

func _ready():
	Global.connect("about_to_free_procedural_nodes", self, "_free_children")
	set_anchors_and_margins_preset(Control.PRESET_WIDE)
	mouse_filter = MOUSE_FILTER_IGNORE

func _free_children():
	for child in get_children():
		child.queue_free()
