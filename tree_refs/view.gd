# view.gd
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
class_name IVView

# Specifies (optionally) target identity and where and how camera tracks its
# target object. Passing a null-equivalent value (=init values) tells the
# camera to maintain its current value. We use selection_name to facilitate
# cache persistence. Most likely you want to persist via IVSaveBuilder system
# (so a player could save one or more views in an active game) or via an
# IVCacheManager (e.g., I, Voyager Planetarium; see planetarium/view_cacher.gd).

const NULL_ROTATION := Vector3(-INF, -INF, -INF)

# persisted
var selection_name := ""
var track_type := -1 # IVEnums.CameraTrackType
var view_type := -1 # IVEnums.ViewType (may or may not specify var values below)
var view_position := Vector3.ZERO # spherical; relative to orbit or ground ref
var view_rotations := NULL_ROTATION # euler; relative to looking_at(-origin, north)
const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["selection_name", "track_type", "view_type",
	"view_position", "view_rotations"]
