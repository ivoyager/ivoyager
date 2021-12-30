// orbit_points.shader
// This file is part of I, Voyager
// https://ivoyager.dev
// *****************************************************************************
// Copyright 2017-2022 Charlie Whitfield
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
render_mode unshaded, cull_disabled, skip_vertex_transform;

uniform float time = 0.0;
uniform float point_size = 3.0;
uniform vec3 color = vec3(0.0, 1.0, 0.0);
//varying flat vec3 test_color;

void vertex() {
	// orbital elements
	float a = NORMAL.x;
	float e = NORMAL.y;
	float i = NORMAL.z;
	float Om = COLOR.x;
	float w = COLOR.y;
	float M0 = COLOR.z;
	float n = COLOR.w;
	
	float M = M0 + n * time;
	M = mod(M + 3.141592654, 6.283185307) - 3.141592654; // -PI to PI
	
	float E = M + e * sin(M);
	float dE = (E - M - e * sin(E)) / (1.0 - e * cos(E));
	E -= dE;
	// A while loop here breaks WebGL1 export. 5 steps is enough.
	if (abs(dE) > 1e-5){
		dE = (E - M - e * sin(E)) / (1.0 - e * cos(E));
		E -= dE;
		if (abs(dE) > 1e-5){
			dE = (E - M - e * sin(E)) / (1.0 - e * cos(E));
			E -= dE;
			if (abs(dE) > 1e-5){
				dE = (E - M - e * sin(E)) / (1.0 - e * cos(E));
				E -= dE;
				if (abs(dE) > 1e-5){
					dE = (E - M - e * sin(E)) / (1.0 - e * cos(E));
					E -= dE;
				}
			}
		}
	}
	float nu = 2.0 * atan(sqrt((1.0 + e) / (1.0 - e)) * tan(E / 2.0));
	float r = a * (1.0 - e * cos(E));
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
    ALBEDO = color;
}
