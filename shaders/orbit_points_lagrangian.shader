// orbit_points_lagrangian.shader
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
// For trojans, a & M are determined by trojan elements d, D, f & th0 together
// with a and M of the influencing orbital body.

shader_type spatial;
render_mode cull_disabled, skip_vertex_transform;

uniform vec3 frame_data = vec3(0.0, 1.0, 0.0); // sim_time, lagrange a, lagrange M
uniform float point_size = 3.0;
uniform vec3 color = vec3(0.0, 1.0, 0.0);

void vertex() {
	float time = frame_data.x;
	float lagrange_a = frame_data.y;
	float lagrange_L = frame_data.z;
	
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
	
	// Same as orbit_points.shader from here down
	M = mod(M + 3.141592654, 6.283185307) - 3.141592654; // -PI to PI
	float EA = M + e * sin(M);
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
	VERTEX = (MODELVIEW_MATRIX * vec4(x, y, z, 1.0)).xyz;
	POINT_SIZE = point_size;
}

void fragment() {
    EMISSION = color;
}
