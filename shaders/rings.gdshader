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

// Source data and color/phase-angle tips: https://bjj.mmedia.is/data/s_rings.
// See https://github.com/ivoyager/ivbinary_maker for conversion of source data
// to the 3 png files. The 3 images have the same alpha channel.
//
// Adjusted to match https://bjj.mmedia.is/3dtest/saturn/saturn_montage.jpg
// on the lit side. Those are rendered (not real) so we still need ground truth
// comparisons to Cassini images (lit and unlit sides).
//
// The png files must be imported as Texture2D with mipmaps/generate = true.
// I guess our n x 2 texture gets shrunk to n/2 x 1, n/4 x 1, n/8 x 1,
// n/16 x 1, n/32 x 1, and so on. We always texelFetch with y=0. The LOD level
// can vary hugely across the rings when close at a steep angle, from 0 to 5+
// in the same view.
//
// ALBEDO is set with color values >> 1.0. It's necessary to get proper
// brightness given the 'thinness' (i.e., transparency) of our material with
// black space as background.
// 
// WARNING! For litside determination, FRONT_FACING is not reliable as of Godot
// 4.2.2. It's sometimes wrong on my laptop (NVIDIA GeForce GTX 1650 Ti). For
// this reason and to save shader computation, lit versus unlit side is
// determined externally and set as uniform.
// 

// set by rings.gd once
uniform sampler2DArray textures : source_color; // backscatter, forwardscatter, unlitside
uniform float texture_width;
uniform float texture_start; // from center
uniform float inner_margin; // from center, includes padding (> texture_start)
uniform float outer_margin; // from center, includes padding (< 1.0)

// set by rings.gd each frame if changed
uniform vec4 frame_data; // xyz, sun_position; w, +1.0 if litside else -1.0

// visual settings
uniform float dfdr_multiplier = 0.3; // for LOD; smaller for more detail & more aliasing
uniform float phase_exponent = 6.0; // larger narrows the low phase-angle effect
uniform float forwardscatter_redshift = 1.05;
uniform float unlitside_boost = 3.0; // general brightening
uniform float litside_phase_boost = 6.0; // low phase-angle brightening
uniform float unlitside_phase_boost = 4.0;



vec4 sample_color(int texel, float texel_fraction, int array_index, int lod) {
	// Ring span is end-padded with fully transparent texels to avoid edge
	// artifacts.
	vec4 sample = texelFetch(textures, ivec3(texel, 0, array_index), lod);
	texel += 1;
	sample += texelFetch(textures, ivec3(texel, 0, array_index), lod);
	texel += 1;
	sample += texelFetch(textures, ivec3(texel, 0, array_index), lod);
	texel += 1;
	sample += texelFetch(textures, ivec3(texel, 0, array_index), lod) * texel_fraction;
	texel -= 6;
	sample += texelFetch(textures, ivec3(texel, 0, array_index), lod) * (1.0 - texel_fraction);
	texel += 1;
	sample += texelFetch(textures, ivec3(texel, 0, array_index), lod);
	texel += 1;
	sample += texelFetch(textures, ivec3(texel, 0, array_index), lod);
	return sample / 6.0;
}


void fragment() {
	// remap plane to a 2x2 square with 0,0 center
	float x = UV.x * 2.0 - 1.0;
	float y = UV.y * 2.0 - 1.0;
	float radius = sqrt(x * x + y * y);
	
	// dFdx() & dFdy() must be before the 'if' fork to avoid edge artifacts!
	float texture_fraction = (radius - texture_start) / (1.0 - texture_start);
	float texel_position = texture_fraction * texture_width;
	float dfdx = dFdx(texel_position); // texels per horizontal screen pixel
	float dfdy = dFdy(texel_position); // texels per vertical screen pixel
	
	if (radius < inner_margin || radius > outer_margin) {
		// out of render area
		discard;
	
	} else {
	
		// LOD for anti-aliasing
		float dfdr = sqrt(dfdx * dfdx + dfdy * dfdy);
		float lod_map = log2(dfdr * dfdr_multiplier);
		lod_map = clamp(round(lod_map), 0.0, 8.0);
		int lod = int(lod_map);
		
		// position in the LOD texture
		texel_position /= float(1 << lod);
		int texel = int(texel_position);
		float texel_fraction = fract(texel_position);
		
		// phase effects (phase_mix = 1.0 corresponds to phase angle = 0.0)
		vec3 sun_vector = (VIEW_MATRIX * vec4(frame_data.xyz, 1.0)).xyz;
		float phase_mix = dot(normalize(sun_vector), VIEW) / 2.0 + 0.5;
		phase_mix = pow(phase_mix, phase_exponent);
		
		vec4 color;
		vec3 albedo;
		
		if (frame_data.w > 0.0) {
			// lit side
			vec4 backscatter = sample_color(texel, texel_fraction, 0, lod);
			vec4 forwardscatter = sample_color(texel, texel_fraction, 1, lod);
			forwardscatter.r *= forwardscatter_redshift;
			color = mix(forwardscatter, backscatter, phase_mix);
			albedo = color.rgb * (litside_phase_boost * phase_mix + 1.0);
		} else {
			// unlit side
			color = sample_color(texel, texel_fraction, 2, lod);
			albedo = color.rgb * unlitside_boost;
			albedo *= (unlitside_phase_boost * phase_mix + 1.0);
		}
		
		// debug lod mapping
//		albedo = vec3(lod_map / 8.0, lod_map / 8.0, 1.0 - lod_map / 8.0);
		
		ALBEDO = albedo;
		ALPHA = color.a;
	
	}
}

