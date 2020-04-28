# hud_2d_surface.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
# Copyright (c) 2017-2020 Charlie Whitfield
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
# Parent control for HUD labels or similar 2D objects.

extends Control
class_name HUD2dSurface

func project_init():
	connect("ready", self, "_on_ready")
	Global.connect("about_to_free_procedural_nodes", self, "_free_2d_huds")
	mouse_filter = MOUSE_FILTER_IGNORE

func _on_ready():
	set_anchors_and_margins_preset(Control.PRESET_WIDE)

func _free_2d_huds():
	for child in get_children():
		child.queue_free()
