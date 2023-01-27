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

uniform float mouse_range = 10.0;
uniform float time = 0.0;
uniform float point_size = 3.0;
uniform vec2 mouse_coord = vec2(0.0, 0.0);
uniform vec3 color = vec3(0.0, 1.0, 0.0);
uniform float cycle_value = 0.0;
uniform int test_id = 0;


void vertex() {
	// orbital elements
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
	
	// we skip VERTEX, but this is how we to VERTEX and then POSITION...
	// VERTEX = (MODELVIEW_MATRIX * vec4(x, y, z, 1.0)).xyz;
	// POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	
	POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(x, y, z, 1.0));

	POINT_SIZE = point_size;
	
}

void fragment() {
	if ((abs(mouse_coord.x - FRAGCOORD.x) < mouse_range)
			&& (abs(mouse_coord.y - FRAGCOORD.y) < mouse_range)){
		// special color if under mouse
		if (cycle_value < 1.0) {
			EMISSION = vec3(cycle_value); // calibration color
		} else {
			// Ouch! GLES2 doesn't allow bit operators!
			int shift_id = test_id;
			if (cycle_value > 1.0) {
				if (cycle_value == 2.0) {
				shift_id /= 4096; // << 12
				} else {
					shift_id /= 16777216; // << 24
				}
			}
//			float r1 = float(shift_id & 15) / 32.0 + 0.25;
			
			EMISSION = vec3(0.5); // encode id
		}
		
		

		ALBEDO = vec3(0.0);
	} else {
		ALBEDO = vec3(0.0);
		EMISSION = color;
	}
}
