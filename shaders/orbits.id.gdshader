// orbits.shader
// This file is part of I, Voyager
// https://ivoyager.dev
// *****************************************************************************
// Copyright 2017-2023 Charlie Whitfield
// I, Voyager is a registered trademark of Charlie Whitfield in the US
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// *****************************************************************************
shader_type spatial;
render_mode unshaded, cull_disabled;

// Used by IVSBGOrbits (a MultiMeshInstance3D) for identification of individual
// orbit lines from many.

uniform vec3 color : source_color = vec3(0.0, 0.0, 1.0);

varying flat vec3 fragment_id;

#include "_fragment_id.gdshaderinc"


void vertex() {
	fragment_id = INSTANCE_CUSTOM.xyz;
}


void fragment() {
	if (is_id_fragment(FRAGCOORD.xy)){
		ALBEDO = get_id_fragment_color(fragment_id);
	} else {
		ALBEDO = color;
	}
}

