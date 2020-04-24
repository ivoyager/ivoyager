# selection_panel.gd
# This file is part of I, Voyager
# https://ivoyager.dev
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

extends DraggablePanel
class_name SelectionPanel
const SCENE := "res://ivoyager/gui_game/selection_panel.tscn"

func _ready() -> void:
	var selection_data: Control = $TRBox/Scroll/SelectionData
	selection_data.labels_width = 135
	selection_data.values_width = 100
	pass
	
	
