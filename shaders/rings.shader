// rings.shader
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

// Source data and expert guidance: https://bjj.mmedia.is/data/s_rings


uniform bool is_sun_above = false;
uniform vec3 sun_translation;


uniform sampler2D rings_texture;// : hint_albedo;
uniform float inner_fraction = 0.5307358; // Saturn: 74510 km / 140390 km
uniform float pixel_size = 7.5889808e-5; // saturn.rings: 1/13177

uniform float max_phase_angle = 3.141592654; // TODO: Max out at 135 degrees, not 180
uniform vec3 unlit_color = vec3(1.0, 0.97075, 0.952);


void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float z = UV.y * 2.0 - 1.0;
	float radius = sqrt(x * x + z * z);
	if (radius > 1.0 || radius < inner_fraction) {
		
		// out of ring boundary
		ALPHA = 0.0;
		
	} else {
		
		float ring_coord = (radius - inner_fraction) / (1.0 - inner_fraction);
		
		// antialiasing coordinates & weights
		float pixel_mod = mod(ring_coord, pixel_size);
		float x0 = ring_coord - pixel_mod + 0.5 * pixel_size;
		float x1 = x0 + pixel_size;
		float w1 = pixel_mod * pixel_size;
		float w0 = 1.0 - w1;
		
		
		vec4 scatter_alpha_0 = texture(rings_texture, vec2(x0, 0.0));
		vec4 scatter_alpha_1;
		if (x1 <= 1.0) {
			scatter_alpha_1 = texture(rings_texture, vec2(x1, 0.0));
		} else {
			scatter_alpha_1 = vec4(0.0);
		}
		float alpha = scatter_alpha_0.w * w0 + scatter_alpha_1.w * w1;
		if (alpha < 0.001) {
			ALPHA = 0.0;
		} else {
			ALPHA = alpha;
			if (FRONT_FACING != is_sun_above) {
				
				// unlit side
				float unlit_scatter = scatter_alpha_0.z * w0 + scatter_alpha_1.z * w1;
				ALBEDO = unlit_color * unlit_scatter
				
			} else {
				
				// lit side
				
				// phase angle
				vec3 sun_vector = (INV_CAMERA_MATRIX * vec4(sun_translation.x,sun_translation.y,sun_translation.z,1.0)).xyz;
//				float phase_dot_product = dot(normalize(sun_vector), normalize(VIEW));
				float phase_angle = (acos(dot(normalize(sun_vector), normalize(VIEW))));
				float phase = clamp(phase_angle / max_phase_angle, 0.0, 1.0);
				// back- and forward-scatter
				float scatter = scatter_alpha_0.y * w0 + scatter_alpha_1.y * w1; // forward only
				if (phase < 1.0) {
					float backscatter = scatter_alpha_0.x * w0 + scatter_alpha_1.x * w1;
					scatter = mix(backscatter, scatter, phase);
				}
				// lit color
				vec3 lit_color_0 = texture(rings_texture, vec2(x0, 1.0)).rgb;
				vec3 lit_color_1;
				if (x1 <= 1.0) {
					lit_color_1 = texture(rings_texture, vec2(x1, 1.0)).rgb;
				} else {
					lit_color_1 = vec3(1.0);
				}
				vec3 lit_color = (lit_color_0 * w0) + (lit_color_1 * w1);
				
				ALBEDO = lit_color * scatter;
				
			}
		
		
//			vec4 scatteralpha = texture(rings_texture, vec2(ring_coord, 0.0));
//
//			if (FRONT_FACING == is_sun_above) {
//				// lit side
//				vec4 litcolor = texture(rings_texture, vec2(ring_coord, 1.0));
//				vec3 sun_vector = (INV_CAMERA_MATRIX * vec4(sun_translation.x,sun_translation.y,sun_translation.z,1.0)).xyz;
//				float phase_dot_product = dot(normalize(sun_vector), normalize(VIEW));
//				float phase_angle = (acos(phase_dot_product));
//				phase_angle /= 3.141592654;
//				phase_angle = clamp(phase_angle, 0.0, 1.0); // Weird camera flashing if we don't clamp
//				float scatter = mix(scatteralpha.x, scatteralpha.y, phase_angle);
//				ALBEDO = litcolor.xyz * scatter;
//
//			} else {
//				// unlit side
//				ALBEDO = unlit_color * scatteralpha.z;
//			}
//			ALPHA = scatteralpha.w;
		}

	}
}

