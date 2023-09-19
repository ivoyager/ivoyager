// rings.gdshader
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
render_mode cull_disabled;

// Source data and expert guidance: https://bjj.mmedia.is/data/s_rings.
//
//
// TODO: Possible improvements:
//  - Should disappear w/ proximity. Adjust transparency?
//  - Per Bjorn, slight dimming and red shift with greater phase angle.
//  - Aliasing is very bad on the dark side. Maybe blur the transparency?


uniform bool is_sun_above = false;
uniform vec3 sun_translation;
uniform sampler2D rings_texture : source_color;
uniform float inner_fraction = 0.5307358; // Saturn: 74510 km / 140390 km
uniform float inner_fraction_margin = 0.5254; // -1% for antialias sampling

uniform float pixel_number = 13177.0; // saturn.rings: 13177.0
uniform float pixel_size = 7.5889808e-5; // saturn.rings: 1.0 / 13177.0




uniform float proximity_fade = 1.0;


vec4 test_redshifted_fowardscatter(vec4 forwardscatter) {
	// This is here for testing to determine the right amount.
	// Then we bake it into the asset texture.
	float red_shift = 0.05;
	vec3 shift = vec3(0.5) - abs(forwardscatter.xyz - vec3(0.5)); // max shift; 0.0 to 0.5
	shift *= vec3(red_shift, -red_shift * 0.5,  -red_shift * 0.5);
	return forwardscatter + vec4(shift, 0.0);
}


vec4 get_color(float ring_position, float phase_mix) {
	// phase_mix < -1.0 means unlit side
	if (ring_position < 0.0 || ring_position > 1.0) {
		// black, fully transparent for antialiasing
		return vec4(0.0);
	}
	if (phase_mix < -1.0) {
		// unlit side
		return texture(rings_texture, vec2(ring_position, 2.0));
	}
	
	vec4 forwardscatter = texture(rings_texture, vec2(ring_position, 1.0));
	forwardscatter = test_redshifted_fowardscatter(forwardscatter);
	
	if (phase_mix < 0.01) {
		// full forward scatter
//		return forwardscatter;
		return vec4(1.0, 0.0, 0.0, 1.0); // debug
	}
//	vec4 backscatter = texture(rings_texture, vec2(ring_position, 0.0));
//	return mix(forwardscatter, backscatter, phase_mix);
	return mix(vec4(1.0, 0.0, 0.0, 1.0), vec4(0.0, 1.0, 0.0, 1.0), phase_mix); // debug
}


void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float z = UV.y * 2.0 - 1.0;
	float radius = sqrt(x * x + z * z);
	if (radius > 1.01 || radius < inner_fraction_margin) {
		// out of ring area
		discard;
	
	} else {
		float ring_position = (radius - inner_fraction) / (1.0 - inner_fraction); // ~-0.01 to 1.01
		float phase_mix = -2.0;
		
		if (FRONT_FACING == is_sun_above) {
			// lit side
			vec3 sun_vector = (VIEW_MATRIX * vec4(sun_translation, 1.0)).xyz;
			// We use dot product to get cos(phase_angle). Then we generate the
			// desired backscatter mix from 0.0 to 1.0.
			phase_mix = dot(normalize(sun_vector), VIEW); // -1.0 to +1.0
			phase_mix /= 2.0;
			phase_mix += 0.5; // 0.0 to 1.0
			phase_mix = pow(phase_mix, 4.0); // narrow the backscatter region
		}
		
		vec4 color = get_color(ring_position, phase_mix);
		ALBEDO = color.rgb;
		ALPHA = color.a;
		
	}
}

