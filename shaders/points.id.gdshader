// points.id.gdshader
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

// VERTEX encodes the fragment_id (see IVFragmentIdentifier). 
// We set POSITION directly here so VERTEX remains unchanged.
//
// Orbital parameters are set via CUSTOMx channels by IVSBGPoints.

global uniform float iv_time;

uniform float point_size = 3.0;
uniform vec3 color : source_color = vec3(0.0, 1.0, 0.0);

varying flat vec3 fragment_id;

#include "_fragment_id.gdshaderinc"
#include "_orbit_math.gdshaderinc"


void vertex() {
	fragment_id = VERTEX; // constant id for each vertex
	
	// orbital elements
	float a = CUSTOM1[0]; // semi-major axis
	float e = CUSTOM0[0]; // eccentricity
	float i = CUSTOM0[1]; // inclination
	float Om = CUSTOM0[2]; // longitude of the ascending node
	float w = CUSTOM0[3]; // argument of periapsis
	float M0 = CUSTOM1[1]; // mean anomaly at epoch
	float n = CUSTOM1[2]; // mean motion
	
	// precessions & magnitude
//	float s = CUSTOM2[0]; // nodal precession; NOT IMPLEMENTED YET
//	float g = CUSTOM2[1]; // apsidal precession; NOT IMPLEMENTED YET
//	float mag = CUSTOM2[3]; // magnitude; NOT IMPLEMENTED YET
	
	float M = M0 + n * iv_time; // mean anomaly
	M = mod(M + PI, TAU) - PI;
	
	vec3 position = get_orbit_position(a, e, i, Om, w, M);
	
	// We skip VERTEX here, but this is the 2-step version...
	// VERTEX = (MODELVIEW_MATRIX * vec4(x, y, z, 1.0)).xyz;
	// POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);	
	POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(position, 1.0));
	
	POINT_SIZE = point_size;
}


void fragment() {
	if (is_id_fragment(FRAGCOORD.xy)){
		ALBEDO = get_id_fragment_color(fragment_id);
	} else {
		ALBEDO = color;
	}
}

