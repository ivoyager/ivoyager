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
global uniform vec2 iv_mouse_fragcoord;
global uniform float iv_fragment_id_range;
global uniform float iv_fragment_id_cycler;

uniform float lp_mean_longitude; // update per frame
uniform int lp_integer; // 4 or 5; not currently used but should be for better ocillators
uniform float characteristic_length; // semi-major axis of the secondary body
uniform float point_size = 3.0;
uniform vec3 color = vec3(0.0, 1.0, 0.0);

varying flat vec3 fragment_id;


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
	
	// orbit precessions
//	float s = UV[0]; // NOT IMPLEMENTED YET
//	float g = UV[1]; // NOT IMPLEMENTED YET
	
	// libration of a & M
	float th = th0 + f * iv_time;
	float a = characteristic_length + axis_ocillator(da, th);
	float M = lp_mean_longitude - Om - w + longitude_ocillator(D, th);
	M = mod(M + PI, TAU) - PI;

// ****************************************************************************
// Entire file below is an exact copy of points.shader!!!
// TODO34: Use #include preprocessor for shared code!
// ****************************************************************************


	// Numerical approximation of eccentric anomaly.
	// A while loop here breaks WebGL1 export. From empirical testing, the
	// 2nd delta (-= dEA) is needed for the vast majority of points (hence,
	// no 'if' test). A tiny minority make it to the 5th delta.
	float EA = M + e * sin(M); // eccentric anomaly
	float dEA = (EA - M - e * sin(EA)) / (1.0 - e * cos(EA));
	EA -= dEA;
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


bool is_self_identifying_fragment(vec2 offset){
	// Follows grid pattern near mouse described in FragmentIdentifier, which
	// will capture any point in range area with POINT_SIZE >= 3 and generally
	// captures orbit lines.
	//
	// Note that FRAGCOORD x and y are offset from pixel coordinate by either
	// exaclty +0.5 (Windows) or close to but not exactly +0.5 (HTML5 export)
	// as of Godot 3.5.2. Perhaps this could change or vary on other platforms.
	// To compensate, we set iv_mouse_fragcoord = mouse_pos + Vector2(0.5, 0.5)
	// and we allow for non-whole numbers below.
	//
	// Comment out the 'mod3' filter to troubleshoot; the identifier region
	// will be visually obvious in any region of dense fragment rendering.
	
	offset = abs(offset);
	
	if (offset.x > iv_fragment_id_range) {
		return false;
	}
	
	if (offset.y > iv_fragment_id_range) {
		return false;
	}
	
	vec2 mod3 = mod(offset, 3.0);
	if (mod3.x > 0.5 || mod3.y > 0.5) {
		return false;
	}

	return true;
}


void fragment() {
	
	if (!is_self_identifying_fragment(FRAGCOORD.xy - iv_mouse_fragcoord)) {
		 // Use this group's uniform color.
		ALBEDO = color;
		
	} else {
		// Broadcast calibration color or fragment identifier at or very near
		// the mouse position. See IVFragmentIdentifier.
		
		if (iv_fragment_id_cycler < 1.0) {
			// Broadcast callibration color.
			ALBEDO = vec3(iv_fragment_id_cycler);
		
		} else {
			// Broadcast part of this fragment's identifier (1 of 3 parts).
			// iv_fragment_id_cycler value is exactly 1.0, 2.0 or 3.0.
			int id_element = int(fragment_id[int(iv_fragment_id_cycler) - 1]);
			
			int rbits = id_element & 15;
			id_element >>= 4;
			int gbits = id_element & 15;
			id_element >>= 4;
			int bbits = id_element & 15;
			
			// Godot 3.x GLES2 didn't allow bit operators.
			// Keep this code here in case we need it (for HTML5 export?)...
//			int bbits = id_element / 256;
//			int gbits = (id_element - bbits * 256) / 16;
//			int rbits = id_element - gbits * 16 - bbits * 256;
			
			// Use range 0.25-0.75 for each channel.
			float r = float(rbits) / 32.0 + 0.25;
			float g = float(gbits) / 32.0 + 0.25;
			float b = float(bbits) / 32.0 + 0.25;
			
			ALBEDO = vec3(r, g, b);
		}
	}
}

