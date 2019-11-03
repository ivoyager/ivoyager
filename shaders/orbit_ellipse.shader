// orbit_ellipse.shader
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
// NORMAL.x holds the unchanging eccentric anomaly (E) for this vertex, which is
// an angle from 0 to TAU. NORMAL.y & z hold cached values for nu and e so that
// we recaluclate nu only when e changes.
shader_type spatial;
render_mode unshaded, cull_disabled; //, skip_vertex_transform;

uniform vec2 shape = vec2(1.0, 0.0); // a, e
uniform vec3 rotation = vec3(0.0, 0.0, 0.0); // i, Om, w
uniform vec3 reference_normal = vec3(0.0, 0.0, 1.0); // x, y, z
uniform vec3 color = vec3(0.0, 1.0, 0.0);

void vertex() {
	float a = shape.x;
	float e = shape.y;
	float i = rotation.x;
	float Om = rotation.y;
	float w = rotation.z;
	
	float E = NORMAL.x; // E is a fixed angle for a given vertex
	float nu = NORMAL.y;
	if (e != NORMAL.z) {
		nu = 2.0 * atan(sqrt((1.0 + e) / (1.0 - e)) * tan(E / 2.0));
		NORMAL.y = nu;
		NORMAL.z = e;
	}
	float r = a * (1.0 - e * cos(E));
	float cos_i = cos(i);
	float sin_Om = sin(Om);
	float cos_Om = cos(Om);
	float sin_w_nu = sin(w + nu);
	float cos_w_nu = cos(w + nu);
	float x = r * (cos_Om * cos_w_nu - sin_Om * sin_w_nu * cos_i);
	float y = r * (sin_Om * cos_w_nu + cos_Om * sin_w_nu * cos_i);
	float z = r * sin(i) * sin_w_nu;
	if (reference_normal == vec3(0.0, 0.0, 1.0)) {
		VERTEX = vec3(x, y, z);
	} else {
		// Use Rodrigues Formula for rotation from ecliptic
		float cos_th = dot(vec3(0.0, 0.0, 1.0), reference_normal);
		vec3 X = cross(vec3(0.0, 0.0, 1.0), reference_normal);
		float sin_th = length(X);
		vec3 k = X / sin_th; // normalized cross product
		vec3 R = vec3(x, y, z);
		VERTEX = R * cos_th + cross(k, R) * sin_th + k * dot(k, R) * (1.0 - cos_th);
	}
	
	// VERTEX = (MODELVIEW_MATRIX * vec4(x, y, z, 1.0)).xyz;
	// POINT_SIZE = 4.0;
	// VERTEX = vec3(x, y, z);
}

void fragment() {
    ALBEDO = color;
}
