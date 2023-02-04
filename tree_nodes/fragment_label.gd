# fragment_label.gd
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
class_name IVFragmentLabel
extends Label

# Requires IVFragmentIdentifier to work. Both are added in
# ProjectBuilder.gui_nodes.


var offset := Vector2(0.0, -7.0) # offset to not interfere w/ FragmentIdentifier

var _world_targeting: Array = IVGlobal.world_targeting
var _infos: Dictionary


func _ready() -> void:
	var fragment_identifier: IVFragmentIdentifier = IVGlobal.program.get("FragmentIdentifier")
	if !fragment_identifier:
		# should remove this label from ProjectBuilder too, but just in case...
		hide()
		return
	fragment_identifier.connect("fragment_changed", self, "_on_target_point_changed")
	_infos = fragment_identifier.infos
	set("custom_fonts/font", IVGlobal.fonts.hud_names)
	align = ALIGN_CENTER
	grow_horizontal = GROW_DIRECTION_BOTH
	size_flags_horizontal = SIZE_SHRINK_CENTER
	hide()


func _on_target_point_changed(id: int) -> void:
	if id == -1:
		hide()
		return
	show()
	text = _infos[id][0] # [0] index is always name_str
	rect_position = _world_targeting[0] + offset + Vector2(-rect_size.x / 2.0, -rect_size.y)

