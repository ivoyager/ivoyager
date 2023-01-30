// orbit_points.shader
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
// Duplicates orbital math in system_refs/orbit.gd.

shader_type spatial;
render_mode cull_disabled, skip_vertex_transform;

uniform vec4 frame_data; // time, cycle_value, mouse_x, mouse_y
uniform float point_size = 3.0;
uniform vec3 color = vec3(0.0, 1.0, 0.0);

varying flat vec3 identifier;


void vertex() {
	// orbital elements
	float time = frame_data.x;
	float a = NORMAL.x; // semi-major axis
	float e = NORMAL.y; // eccentricity
	float i = NORMAL.z; // inclination
	float Om = COLOR.x; // longitude of the ascending node
	float w = COLOR.y; // argument of periapsis
	float M0 = COLOR.z; // mean anomaly at epoch
	float n = COLOR.w; // mean motion
	
	float M = M0 + n * time; // mean anomaly
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
	
	identifier = VERTEX; // yeah, that's crazy!
}


bool is_id_signaling_pixel(vec2 offset){
	// Follows grid pattern near mouse described in PointPicker. You can modify
	// to return true in full area (eg, 13 x 13), but that causes PointPicker
	// to do a worse job identifying valid ids in a crowded field of points.
	//
	// Note that FRAGCOORD is always offset +vec2(0.5) from pixel coordinate.
	// If that changes it will break this function.
	offset -= vec2(0.5);
	offset = abs(offset);
	
	if (offset.x > 6.0) {
		return false;
	}
	if (offset.y > 6.0) {
		return false;
	}
	if (offset.x != 0.0 && offset.x != 3.0 && offset.x != 6.0) {
		return false;
	}
	if (offset.y != 0.0 && offset.y != 3.0 && offset.y != 6.0) {
		return false;
	}
	
	return true;
}


void fragment() {
	vec2 mouse_coord = frame_data.zw;
	if (is_id_signaling_pixel(FRAGCOORD.xy - mouse_coord)) {
		// Broadcast callibration or id color. See tree_noes/point_picker.gd.
		float cycle_value = frame_data.y;
		if (cycle_value < 1.0) {
			EMISSION = vec3(cycle_value); // calibration color
		} else {
			// Ouch! GLES2 doesn't allow bit operators!
			// TODO 4.0: recode w/ bit operators!
			int id_element;
			if (cycle_value == 1.0){
				id_element = int(identifier.x);
			} else {
				if (cycle_value == 2.0){
					id_element = int(identifier.y);
				} else {
					id_element = int(identifier.z);
				}
			}
			
			int bbits = id_element / 256;
			int gbits = (id_element - bbits * 256) / 16;
			int rbits = id_element - gbits * 16 - bbits * 256;
			
			float r = float(rbits) / 32.0 + 0.25;
			float g = float(gbits) / 32.0 + 0.25;
			float b = float(bbits) / 32.0 + 0.25;
			
			EMISSION = vec3(r, g, b); // encodes id
		}
	
	} else {
		// color for this point group
		EMISSION = color;
	}
	ALBEDO = vec3(0.0);
}
