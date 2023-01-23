// orbit_ellipse.shader
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
// NORMAL.x holds the unchanging eccentric anomaly (EA) for this vertex, which is
// is an angle from 0 to TAU. NORMAL.y & z hold cached values for nu and e so
// that we recaluclate nu only when e changes.

shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec2 shape = vec2(1.0, 0.0); // a, e
uniform vec3 rotation = vec3(0.0, 0.0, 0.0); // i, Om, w
uniform vec3 reference_normal = vec3(0.0, 0.0, 1.0); // x, y, z
uniform vec3 color = vec3(0.0, 1.0, 0.0);

void vertex() {
	float a = shape.x; // semi-major axis
	float e = shape.y; // eccentricity
	float i = rotation.x; // inclination
	float Om = rotation.y; // longitude of the ascending node
	float w = rotation.z; // argument of periapsis
	
	float EA = NORMAL.x; // eccentric anomaly; a fixed angle for a given vertex
	float nu = NORMAL.y;
	if (e != NORMAL.z) {
		nu = 2.0 * atan(sqrt((1.0 + e) / (1.0 - e)) * tan(EA / 2.0));
		NORMAL.y = nu;
		NORMAL.z = e;
	}
	float r = a * (1.0 - e * cos(EA));
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
}

void fragment() {
    ALBEDO = color;
}
