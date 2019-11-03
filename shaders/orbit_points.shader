// orbit_points.shader
// This file is part of I, Voyager
// https://ivoyager.dev
// *****************************************************************************
// Copyright (c) 2017-2019 Charlie Whitfield
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// *****************************************************************************
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
