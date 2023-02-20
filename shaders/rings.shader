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

// https://bjj.mmedia.is/data/s_rings


uniform bool is_sun_above = false;
uniform vec3 sun_translation;


uniform sampler2D ring_texture;// : hint_albedo;
uniform float inner_fraction = 0.5307358; // Saturn: 74510 km / 140390 km
uniform vec3 unlit_color = vec3(1.0, 0.97075, 0.952);


void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float z = UV.y * 2.0 - 1.0;
	float radius = sqrt(x * x + z * z);
	if (radius > 1.0 || radius < inner_fraction) {
		ALPHA = 0.0;
	} else {
		float ring_coord = (radius - inner_fraction) / (1.0 - inner_fraction);
		vec4 color1 = texture(ring_texture, vec2(ring_coord, 0.0));
		vec4 color2 = texture(ring_texture, vec2(ring_coord, 1.0));
		
		if (FRONT_FACING == is_sun_above) {
			// lit side
			vec3 sun_vector = (INV_CAMERA_MATRIX * vec4(sun_translation.x,sun_translation.y,sun_translation.z,1.0)).xyz;
			float phase_dot_product = dot(normalize(sun_vector), normalize(VIEW));
			float phase_angle = (acos(phase_dot_product));
			phase_angle /= 3.141592654;
			phase_angle = clamp(phase_angle, 0.0, 1.0); // Weird camera flashing if we don't clamp
			float scatter = mix(color2.x, color2.y, phase_angle);
			ALBEDO = color1.xyz * scatter;

		} else {
			// unlit side
			ALBEDO = unlit_color * color2.z;
		}

		ALPHA = 1.0 - color1.w;
	}
}

