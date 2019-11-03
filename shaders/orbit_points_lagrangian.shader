// orbit_points_lagrangian.shader
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
// For trojans, a & M are determined by trojan elements d, D, f & th0 together
// with a and M of the influencing orbital body. 
shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;

uniform vec3 frame_data = vec3(0.0, 1.0, 0.0); // sim_time, lagrange a, lagrange M
uniform float point_size = 3.0;
uniform vec3 color = vec3(0.0, 1.0, 0.0);

void vertex() {
	float time = frame_data.x;
	float lagrange_a = frame_data.y;
	float lagrange_L = frame_data.z;
	
	// orbital elements modified for lagrangian
	float d = NORMAL.x;
	float e = NORMAL.y;
	float i = NORMAL.z;
	float Om = COLOR.x;
	float w = COLOR.y;
	float D = COLOR.z;
	float f = COLOR.w;
	float th0 = UV2.x;
	
	// Libration of a & M
	float th = th0 + f * time;
	float a = lagrange_a + d * sin(th);
	float L = lagrange_L + D * cos(th);
	float M = L - w - Om;
	
	// Same as orbit_points.shader from here down
	M = mod(M + 3.141592654, 6.283185307) - 3.141592654; // -PI to PI
	float E = M + e * sin(M);
	float dE = (E - M - e * sin(E)) / (1.0 - e * cos(E));
	E -= dE;
	int steps = 1;
	while (abs(dE) > 1e-5 && steps < 10) {
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
	POINT_SIZE = point_size;
}

void fragment() {
    ALBEDO = color;
}
