// points.l4l5.id.gdshader
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

// See comments in points.id.shader.
//
// For L4/L5 objects, a & M are determined by da, D, f & th0 together with
// characteristic_length (semi-major axis of the secondary body) and mean
// longitude (leading or lagging secondary body by 60 degrees).
//
// da: amplitude of axis ocillation
// D: amplitude of longitudinal ocillation
// f: frequency of ocillation (period = TAU / f)
// th0: phase at epoch
// e, i, s, g: same as non-lagrange-point orbits
// de (not used): e ocillation, I think. If so, what is the frequency & phase?
//
// We're using a harmonic ocillator as a *very* rough approximation. There are
// no closed-form solutions so we can only approximate L-point librations.
// TODO: Notwithstanding above, we could improve our ocillator functions to
// give more 'tadpole'-shaped librations.

global uniform float iv_time;

uniform float lp_mean_longitude; // update per frame
uniform int lp_integer; // 4 or 5; not currently used but should be for better ocillators
uniform float characteristic_length; // semi-major axis of the secondary body
uniform float point_size = 3.0;
uniform vec3 color : source_color = vec3(0.0, 1.0, 0.0);

varying flat vec3 fragment_id;

#include "_fragment_id.gdshaderinc"
#include "_orbit_math.gdshaderinc"


float longitude_ocillator(float D, float th){
	// th = 0 when trojan is at 'leading' extreme (max L relative to L-point).
	return D * cos(th);
}


float axis_ocillator(float da, float th){
	// clockwise; leading L4s are slowed and fall into lower orbit as they
	// approach the secondary body
	return da * sin(th);
}


void vertex() {
	fragment_id = VERTEX;
	
	// orbit elements
	float e = CUSTOM0[0]; // eccentricity
	float i = CUSTOM0[1]; // inclination
	float Om = CUSTOM0[2]; // longitude of the ascending node
	float w = CUSTOM0[3]; // argument of periapsis
	
	// lagrangian
	float da = CUSTOM1[0]; // amplitude of axis ocillation
	float D = CUSTOM1[1]; // amplitude of longitudinal ocillation
	float f = CUSTOM1[2]; // frequency of ocillation
	float th0 = CUSTOM1[3]; // ocillator at epoch
	
	// orbit precessions & magnitude
//	float s = CUSTOM2[0]; // nodal precession; NOT IMPLEMENTED YET
//	float g = CUSTOM2[1]; // apsidal precession; NOT IMPLEMENTED YET
//	float mag = CUSTOM2[3]; // magnitude; NOT IMPLEMENTED YET
	
	// libration of a & M
	float th = th0 + f * iv_time;
	float a = characteristic_length + axis_ocillator(da, th);
	float M = lp_mean_longitude - Om - w + longitude_ocillator(D, th);
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

