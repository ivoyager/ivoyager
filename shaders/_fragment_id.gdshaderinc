// _fragment_id.gdshaderinc
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

// Functions here allow implementation of fragment identification for 'id'
// shaders. Pixels near the mouse (in a grid pattern) can broadcast a series
// of calibration colors followed by 3 fragment identifier colors to be
// detected by IVFragmentIdentifier. IVFragmentIdentifier sets the 3 shader
// globals here to drive the system.

global uniform vec2 iv_mouse_fragcoord;
global uniform float iv_fragment_id_range;
global uniform float iv_fragment_id_cycler;


bool is_id_fragment(vec2 fragcoord_xy){
	// Follows grid pattern near mouse described in FragmentIdentifier, which
	// will capture any point in range area with POINT_SIZE >= 3 and generally
	// captures orbit lines.
	//
	// Note that FRAGCOORD x and y are offset from pixel coordinate by either
	// exaclty +0.5 (Windows) or close to but not exactly +0.5 (HTML5 export)
	// as of Godot 3.5.2. Perhaps this could change or vary on other platforms?
	// To compensate, we set iv_mouse_fragcoord = mouse_pos + Vector2(0.5, 0.5)
	// and we allow for non-whole numbers below.
	//
	// Comment out the 'mod3' filter to troubleshoot; the identifier region
	// will be visually obvious in any region of dense fragment rendering.
 	
	vec2 mouse_offset = abs(fragcoord_xy - iv_mouse_fragcoord);
	
	if (mouse_offset.x > iv_fragment_id_range) {
		return false;
	}
	if (mouse_offset.y > iv_fragment_id_range) {
		return false;
	}
	vec2 mod3 = mod(mouse_offset, 3.0);
	if (mod3.x > 0.5 || mod3.y > 0.5) {
		return false;
	}
	
	return true;
}


vec3 get_id_fragment_color(vec3 fragment_id_color){
	
	if (iv_fragment_id_cycler < 1.0) {
		// broadcast callibration color
		return vec3(iv_fragment_id_cycler);
	}
	
	// Broadcast part of this fragment's identifier (1 of 3 parts).
	// 'iv_fragment_id_cycler' value is exactly 1.0, 2.0 or 3.0.
	int id_element = int(fragment_id_color[int(iv_fragment_id_cycler) - 1]);
	
	int rbits = id_element & 15;
	id_element >>= 4;
	int gbits = id_element & 15;
	id_element >>= 4;
	int bbits = id_element & 15;
	
	// Godot 3.x GLES2 didn't allow bit operators.
	// Keep this code in case we need it for HTML5 export...
//	int bbits = id_element / 256;
//	int gbits = (id_element - bbits * 256) / 16;
//	int rbits = id_element - gbits * 16 - bbits * 256;
	
	// Use range 0.25-0.75 for each channel.
	float r = float(rbits) / 32.0 + 0.25;
	float g = float(gbits) / 32.0 + 0.25;
	float b = float(bbits) / 32.0 + 0.25;
	
	return vec3(r, g, b);
}

