// points_lagrangian.shader
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
render_mode unshaded, cull_disabled, skip_vertex_transform;

// See comments in orbit_points.shader.
//
// For trojans, a & M are determined by trojan elements d, D, f & th0 together
// with a and M of the influencing orbital body.


uniform float time;
uniform vec2 lagrange_data; // lagrange a, lagrange L
uniform float point_size = 3.0;
uniform vec2 mouse_coord;
uniform float fragment_range = 9.0;
uniform float fragment_cycler = 0.0;
uniform vec3 color = vec3(0.0, 1.0, 0.0);


void vertex() {
	float lagrange_a = lagrange_data.x;
	float lagrange_L = lagrange_data.y;
	
	// orbital elements modified for lagrangian
	float d = NORMAL.x; // 
	float e = NORMAL.y; // eccentricity
	float i = NORMAL.z; // inclination
	float Om = COLOR.x; // longitude of the ascending node
	float w = COLOR.y; // argument of periapsis
	float D = COLOR.z; // 
	float f = COLOR.w; // 
	float th0 = UV2.x; // 
	
	// Libration of a & M
	float th = th0 + f * time;
	float a = lagrange_a + d * sin(th);
	float L = lagrange_L + D * cos(th);
	float M = L - w - Om;
	
// ****************************************************************************
// Entire file below is an exact copy of orbit_points.shader!!!
// ****************************************************************************
	M = mod(M + 3.141592654, 6.283185307) - 3.141592654; // -PI to PI
	
	float EA = M + e * sin(M); // eccentric anomaly
	float dEA = (EA - M - e * sin(EA)) / (1.0 - e * cos(EA));
	EA -= dEA;
	// A while loop here breaks WebGL1 export. 5 steps is enough.
	if (abs(dEA) > 1e-5){
		dEA = (EA - M - e * sin(EA)) / (1.0 - e * cos(EA));
		EA -= dEA;
		if (abs(dEA) > 1e-5){
			dEA = (EA - M - e * sin(EA)) / (1.0 - e * cos(EA));
			EA -= dEA;
			if (abs(dEA) > 1e-5){
				dEA = (EA - M - e * sin(EA)) / (1.0 - e * cos(EA));
				EA -= dEA;
				if (abs(dEA) > 1e-5){
					dEA = (EA - M - e * sin(EA)) / (1.0 - e * cos(EA));
					EA -= dEA;
				}
			}
		}
	}
	float nu = 2.0 * atan(sqrt((1.0 + e) / (1.0 - e)) * tan(EA / 2.0));
	float r = a * (1.0 - e * cos(EA));
	float cos_i = cos(i);
	float sin_Om = sin(Om);
	float cos_Om = cos(Om);
	float sin_w_nu = sin(w + nu);
	float cos_w_nu = cos(w + nu);
	float x = r * (cos_Om * cos_w_nu - sin_Om * sin_w_nu * cos_i);
	float y = r * (sin_Om * cos_w_nu + cos_Om * sin_w_nu * cos_i);
	float z = r * sin(i) * sin_w_nu;
	
	// We skip VERTEX which is used to encode point_id.
	// But this is how we would get VERTEX and then POSITION...
	// VERTEX = (MODELVIEW_MATRIX * vec4(x, y, z, 1.0)).xyz;
	// POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);	
	POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(x, y, z, 1.0));

	POINT_SIZE = point_size;
}


bool is_id_signaling_pixel(vec2 offset){
	// Follows grid pattern near mouse described in FragmentIdentifier, which
	// will capture any point in range area with POINT_SIZE >= 3. You can
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
			// Note: There is *some* interpolation of VERTEX even though we are
			// at the vertex point - hence VERTEX elements are no longer whole
			// numbers. The +0.5 below fixes small interpolation bumps.
			if (fragment_cycler == 1.0){
				id_element = int(VERTEX.x + 0.5);
			} else {
				if (fragment_cycler == 2.0){
					id_element = int(VERTEX.y + 0.5);
				} else {
					id_element = int(VERTEX.z + 0.5);
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
