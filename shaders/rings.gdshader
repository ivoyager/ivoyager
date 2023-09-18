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
render_mode cull_disabled; //, unshaded;

// Source data and expert guidance: https://bjj.mmedia.is/data/s_rings.
//
//
// TODO: Possible improvements:
//  - Should disappear w/ proximity. Adjust transparency?
//  - Per Bjorn, slight dimming and red shift with greater phase angle.
//  - Aliasing is very bad on the dark side. Maybe blur the transparency?


uniform bool is_sun_above = false;
uniform vec3 sun_translation;
uniform sampler2D rings_texture; //source_color;
uniform float inner_fraction = 0.5307358; // Saturn: 74510 km / 140390 km
uniform float pixel_number = 13177.0; // saturn.rings: 13177.0
uniform float pixel_size = 7.5889808e-5; // saturn.rings: 1.0 / 13177.0
uniform float min_phase = -0.75; // cos(139 degress), where we apply only forward scatter
uniform vec3 unlit_color = vec3(1.0, 0.97075, 0.952);
uniform float proximity_fade = 1.0;


void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float z = UV.y * 2.0 - 1.0;
	float radius = sqrt(x * x + z * z);
	if (radius > 1.0 || radius < inner_fraction) {
		// out of ring boundary
//		discard;
		ALPHA = 0.0;
	} else {
		
		float ring_coord = (radius - inner_fraction) / (1.0 - inner_fraction); // 0.0 .. 1.0
		
		// antialiasing sample coordinates & weights
		float pixel_mod = mod(ring_coord, pixel_size);
		float x1 = ring_coord - pixel_mod * pixel_size;
		float x0 = x1 - pixel_size;
		float x2 = x1 + pixel_size;
		float x3 = x2 + pixel_size;
		float offset0 = (x0 - ring_coord) * pixel_number;
		float offset1 = (x1 - ring_coord) * pixel_number;
		float offset2 = (x2 - ring_coord) * pixel_number;
		float offset3 = (x3 - ring_coord) * pixel_number;
		float w0 = exp(-(offset0 * offset0));
		float w1 = exp(-(offset1 * offset1));
		float w2 = exp(-(offset2 * offset2));
		float w3 = exp(-(offset3 * offset3));
		float sum_weights = w0 + w1 + w2 + w3;
		w0 /= sum_weights;
		w1 /= sum_weights;
		w2 /= sum_weights;
		w3 /= sum_weights;
		float half_pixel = pixel_size * 0.5;
		x0 += half_pixel;
		x1 += half_pixel;
		x2 += half_pixel;
		x3 += half_pixel;
		vec4 scatter_alpha_0;
		if (x0 < 0.0) {
			scatter_alpha_0 = vec4(0.0);
		} else {
			scatter_alpha_0 = texture(rings_texture, vec2(x0, 0.0));
		}
		vec4 scatter_alpha_1 = texture(rings_texture, vec2(x1, 0.0));
		vec4 scatter_alpha_2;
		vec4 scatter_alpha_3;
		if (x3 > 1.0) {
			scatter_alpha_3 = vec4(0.0);
			if (x2 > 1.0) {
				scatter_alpha_2 = vec4(0.0);
			} else {
				scatter_alpha_2 = texture(rings_texture, vec2(x2, 0.0));
			}
		} else {
			scatter_alpha_3 = texture(rings_texture, vec2(x3, 0.0));
			scatter_alpha_2 = texture(rings_texture, vec2(x2, 0.0));
		}
		float alpha = (scatter_alpha_0.w * w1 + scatter_alpha_1.w * w2
				+ scatter_alpha_2.w * w2 + scatter_alpha_3.w * w3);
		if (alpha < 0.005) {
			ALPHA = 0.0;
		} else {
			
			if (FRONT_FACING != is_sun_above) {
				
				// unlit side
				float unlit_scatter = scatter_alpha_0.z * w1 + scatter_alpha_1.z * w2;
				ALBEDO = unlit_color * unlit_scatter;
				
			} else {
				
				// lit side
				
				// back-/forward-scatter mix
				// We use 'phase' (=cos(phase_angle)), clipped for min_phase
				// and scaled to 0.0 .. 1.0. Note that 'phase' +1.0 corresponds
				// to phase angle 0 (100% backscatter). 
				vec3 sun_vector = (VIEW_MATRIX * vec4(sun_translation.x, sun_translation.y,
						sun_translation.z, 1.0)).xyz;
				
				float phase = dot(normalize(sun_vector), normalize(VIEW)); // cos(phase_angle)
				if (phase < min_phase) { // only gets forward scatter
					phase = min_phase;
				}
				phase -= min_phase; // 0.0 .. (1.0 - min_phase)
				phase /= 1.0 - min_phase; // 0.0 .. 1.0
				
				// debug
//				phase = 1.0;
				
				
				float scatter = scatter_alpha_0.y * w1 + scatter_alpha_1.y * w2; // forward only
				if (phase > 0.01) {
					float backscatter = scatter_alpha_0.x * w1 + scatter_alpha_1.x * w2;
					scatter = mix(scatter, backscatter, phase);
				}
				// lit color
				vec3 lit_color_0;
				if (x0 < 0.0) {
					lit_color_0 = vec3(1.0);
				} else {
					lit_color_0 = texture(rings_texture, vec2(x0, 1.0)).rgb;
				}
				vec3 lit_color_1 = texture(rings_texture, vec2(x1, 1.0)).rgb;
				vec3 lit_color_2;
				vec3 lit_color_3;
				if (x3 > 1.0) {
					lit_color_3 = vec3(1.0);
					if (x2 > 1.0) {
						lit_color_2 = vec3(1.0);
					} else {
						lit_color_2 = texture(rings_texture, vec2(x2, 1.0)).rgb;
					}
				} else {
					lit_color_3 = texture(rings_texture, vec2(x3, 1.0)).rgb;
					lit_color_2 = texture(rings_texture, vec2(x2, 1.0)).rgb;
				}
				vec3 lit_color = ((lit_color_0 * w0) + (lit_color_1 * w2)
						+ (lit_color_2 * w2) + (lit_color_3 * w3));
				
				ALBEDO = lit_color * scatter;
				
			}
			
			// This test blurs the sudden cull transition when camera is too near
			float depth_fade = FRAGCOORD.z / 1.0;
			if (depth_fade < alpha) {
				ALPHA = depth_fade;
			} else {
				ALPHA = alpha;
			}
		}
	}
}

