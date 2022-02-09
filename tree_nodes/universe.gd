# universe.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2022 Charlie Whitfield
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
extends Spatial

# *****************************************************************************
#
#             Developers! The place to start is:
#                ivoyager/singletons/project_builder.gd
#                ivoyager/singletons/global.gd
#
# *****************************************************************************
#
# Universe is the main scene and simulator root node used by Project Template.
# You can change the simulator root node by modifying var 'universe' in
# IVProjectBuilder during extension init, or by having a different main scene
# named 'Universe' at boot time. Except for boot sequence in IVProjectBuilder,
# the simulator does not care about node names. (Except for GUI, ivoyager
# almost never obtains nodes by name. Dictionaries in IVGlobal are used
# instead.)
#
# We use origin shifting to prevent float "imprecision shakes" (for example,
# when way out at Pluto). To do this, the camera shifts this node's (or
# substitute root node's) translation every frame.
#
# 'persist' dictionary is not used by ivoyager but is available for gamesave
# persistence in extension projects. It can hold Godot built-ins, nested
# containers or other 'persist objects'. See prog_builders/save_builder.gd for
# details.

var persist := {}
const PERSIST_AS_PROCEDURAL_OBJECT := false # persist but don't free on load
const PERSIST_PROPERTIES := ["persist"]
