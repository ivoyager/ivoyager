# orbit_space.gd
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
class_name IVOrbitSpace
extends Spatial

# Created and maintained by IVBody instance only when needed. The camera uses
# this space when orbit tracking.
#
# OrbitSpace is similar to but different than RotatingSpace for non-zero orbit
# eccentricity. In OrbitSpace, the secondary body (P2) is maintained at the
# origin with the P1 body ocillating along the x-axis between minus apoapsis
# and minus periapsis. Lagrange points are defined in RotatingSpace where the
# P1 body is fixed at minus 'characteristic length'. Z-axis is normal to
# orbit plane using 'north/up' for OrbitSpace and positive pole for
# RotatingSpace.

const PERSIST_MODE := IVEnums.PERSIST_PROCEDURAL # free & rebuild on load


