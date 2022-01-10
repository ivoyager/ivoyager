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
#
#             Developers! The place to start is:
#                ivoyager/singletons/project_builder.gd
#                ivoyager/singletons/global.gd
#
# *****************************************************************************
# Universe does nothing but is the simulator root node by default. You can
# change the simulator root node by using a different main scene named
# 'Universe' or by modifying var 'universe' in ProjectBuilder during
# extension init. The simulator does not care about root node name. However,
# it is critical that the correct simulator root is set in ProjectBuilder so
# it will be correctly set in Global.program.Universe before simulator start.
# Note that we use origin shifting to prevent float "imprecision shakes" when
# way out at Pluto (for example). This is the camera shifting the root node's
# translation.

extends Spatial
