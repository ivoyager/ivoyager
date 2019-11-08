// orbit_points.shader
// This file is part of I, Voyager
// https://ivoyager.dev
// Copyright (c) 2017-2019 Charlie Whitfield
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
//
// Duplicates orbital math in utilities/orbits.gd.

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
	int steps = 1;
	while (abs(dE) > 1e-5 && steps < 10) {
		// Some TNOs never converge w/ threshold 1e-6. I think they get close in
		// several steps and then flip between two values outside the threshold,
		// perhaps due to single-precision floats.
		dE = (E - M - e * sin(E)) / (1.0 - e * cos(E));
		E -= dE;
		steps += 1;
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

	// For fun, set POINT_SIZE = float(steps)
	POINT_SIZE = point_size;
//	test_color = color;
}

void fragment() {
	
    ALBEDO = color;
}
