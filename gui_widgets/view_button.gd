# view_button.gd
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
class_name IVViewButton
extends Button

# GUI button widget for 'default' views in IVViewDefaults. This button name
# must be changed to a valid key in IVViewDefaults.views.
#
# See IVViewSaveFlow for saved/removable view buttons.


func _ready() -> void:
	var view_defaults: IVViewDefaults = IVGlobal.program.ViewDefaults
	assert(view_defaults.has_view(name), "No default view with name = " + name)
	connect("pressed", view_defaults, "set_view", [name])

