// points_l4_l5.shader
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

// See comments in points.shader.
//
// For L4/L5 objects, a & M are determined by da, D, f & th0 together with
// Lagrange point radius and longitude.
//
// da: amplitude of axis ocillation
// D: amplitude of longitudinal ocillation
// f: frequency of ocillation (period = TAU / f)
// e, i, s, g: same as non-lagrange-point orbits
//
// We're using a harmonic ocillator as a *very* rough approximation. There is
// no closed-form solution so this will always be approximate.
// TODO: Notwithstanding above, we could hack our ocillator functions to give
// more 'tadpole'-shaped librations.

uniform float time; // update per frame
uniform float lp_mean_longitude; // update per frame
uniform int lp_integer; // 4 or 5; not currently used but could be for better ocillators
uniform float characteristic_length; // semi-major axis of the secondary body
uniform float point_size = 3.0;
uniform vec2 mouse_coord;
uniform float fragment_range = 9.0;
uniform float fragment_cycler = 0.0;
uniform vec3 color = vec3(0.0, 1.0, 0.0);



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

	// orbit elements
	float e = COLOR[0]; // eccentricity
	float i = COLOR[1]; // inclination
	float Om = COLOR[2]; // longitude of the ascending node
	float w = COLOR[3]; // argument of periapsis
	
	// orbit precessions
	float s = UV[0]; // NOT IMPLEMENTED YET
	float g = UV[1]; // NOT IMPLEMENTED YET
	
	// lagrangian
	float da = NORMAL[0]; // amplitude of axis ocillation
	float D = NORMAL[1]; // amplitude of longitudinal ocillation
	float f = NORMAL[2]; // frequency of ocillation
	float th0 = UV2[0]; // ocillator at epoch
	
	// libration of a & M
	float th = th0 + f * time;
	float a = characteristic_length + axis_ocillator(da, th);
	float M = lp_mean_longitude - Om - w + longitude_ocillator(D, th);
	M = mod(M + 3.141592654, 6.283185307) - 3.141592654; // -PI to PI;

// ****************************************************************************
// Entire file below is an exact copy of points.shader!!!
// ****************************************************************************

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
	
	// We skip VERTEX which is used to encode point_id.
	// But this is how we would get VERTEX and then POSITION...
	// VERTEX = (MODELVIEW_MATRIX * vec4(x, y, z, 1.0)).xyz;
	// POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);	
	POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(x, y, z, 1.0));

	POINT_SIZE = point_size;
}


bool is_id_signaling_pixel(vec2 offset){
	// Follows grid pattern near mouse described in FragmentIdentifier, which
	// will capture any point in range area with POINT_SIZE >= 3 and generally
	// captures orbit lines.
	//
	// Note that FRAGCOORD x and y are offset from pixel coordinate by either
	// exaclty +0.5 (Windows) or close to but not exactly +0.5 (HTML5 export).
	// Code below covers either case. Comment out the 'mod' filter to
	// troubleshoot (the calibration region wlll be painfully obvious).
	
	offset -= vec2(0.5);
	offset = abs(offset);
	
	if (offset.x > fragment_range) {
		return false;
	}
	
	if (offset.y > fragment_range) {
		return false;
	}
	
	vec2 mod_3 = mod(offset, 3.0);
	if (mod_3.x > 0.5 || mod_3.y > 0.5) {
		return false;
	}

	return true;
}


void fragment() {
	if (is_id_signaling_pixel(FRAGCOORD.xy - mouse_coord)) {
		// Broadcast callibration or id color. See tree_nodes/fragment_identifier.gd.
		if (fragment_cycler < 1.0) {
			ALBEDO = vec3(fragment_cycler); // calibration color
		} else {
			int id_element;
			// Note: There is *some* interpolation of VERTEX even though we are
			// at the vertex point - hence VERTEX elements are no longer whole
			// numbers. The +0.5 below fixes small interpolation bumps.
			if (fragment_cycler == 1.0){
				id_element = int(VERTEX.x + 0.5);
			} else {
				if (fragment_cycler == 2.0){
					id_element = int(VERTEX.y + 0.5);
				} else {
					id_element = int(VERTEX.z + 0.5);
				}
			}
			
			// Ouch! GLES2 doesn't allow bit operators! Can't use '<<' or '&'.
			// TODO 4.0: recode w/ bit operators!
			int bbits = id_element / 256;
			int gbits = (id_element - bbits * 256) / 16;
			int rbits = id_element - gbits * 16 - bbits * 256;
			
			float r = float(rbits) / 32.0 + 0.25;
			float g = float(gbits) / 32.0 + 0.25;
			float b = float(bbits) / 32.0 + 0.25;
			
			ALBEDO = vec3(r, g, b); // encodes id
		}
	
	} else {
		ALBEDO = color; // use this group's uniform
	}
}
