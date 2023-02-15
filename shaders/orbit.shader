// orbit.shader
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

// Broadcasts id near mouse for FragmentIdentifier. 
//
// TODO4.0: Use array chanels CUSTOM1, 2, 3, 4.
// TODO4.0: Use global uniforms where appropriate.

uniform vec2 mouse_coord;
uniform float fragment_range = 9.0;
uniform float fragment_cycler = 0.0;
uniform vec3 fragment_id; // single orbit has one id
uniform vec3 color = vec3(0.0, 0.0, 1.0);


bool is_id_signaling_pixel(vec2 offset){
	// Follows grid pattern near mouse described in FragmentIdentifier. You can
	// modify to return true in the full range area for debugging, but that
	// causes FragmentIdentifier to do a worse job identifying valid ids in a
	// crowded field of points.
	
	// Note that FRAGCOORD is always offset +0.5 from pixel coordinate in both
	// x and y. If that changes, the following line will need to be changed.
	offset -= vec2(0.5);
	
	offset = abs(offset);
	if (offset.x > fragment_range) {
		return false;
	}
	if (offset.y > fragment_range) {
		return false;
	}
	if (mod(offset, 3.0) != vec2(0.0)) {
		return false;
	}

	return true;
}


void fragment() {
	if (is_id_signaling_pixel(FRAGCOORD.xy - mouse_coord)) {
		// Broadcast callibration or id color. See tree_nodes/fragment_identifier.gd.
		if (fragment_cycler < 1.0) {
			ALBEDO = vec3(fragment_cycler); // calibration color
		} else {
			int id_element;
			if (fragment_cycler == 1.0){
				id_element = int(fragment_id.x);
			} else {
				if (fragment_cycler == 2.0){
					id_element = int(fragment_id.y);
				} else {
					id_element = int(fragment_id.z);
				}
			}
			
			// Ouch! GLES2 doesn't allow bit operators! Can't use '<<' or '&'.
			// TODO 4.0: recode w/ bit operators!
			int bbits = id_element / 256;
			int gbits = (id_element - bbits * 256) / 16;
			int rbits = id_element - gbits * 16 - bbits * 256;
			
			float r = float(rbits) / 32.0 + 0.25;
			float g = float(gbits) / 32.0 + 0.25;
			float b = float(bbits) / 32.0 + 0.25;
			
			ALBEDO = vec3(r, g, b); // encodes id
		}
	
	} else {
		ALBEDO = color; // use this group's uniform
	}
}

