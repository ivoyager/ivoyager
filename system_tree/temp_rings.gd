# temp_rings.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2019 Charlie Whitfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# *****************************************************************************
#
# TODO: Make a rings shader!

extends MeshInstance
class_name TempRings

const TOO_FAR_RADIUS_MULTIPLIER := 2e3

var _rings_material := SpatialMaterial.new()

func init(rings_file: String, radius: float) -> void:
	var texture: Texture = FileHelper.find_resource(Global.rings_dir, rings_file)
	assert(texture) # no fallback!
	_rings_material.albedo_texture = texture
	_rings_material.flags_transparent = true
	_rings_material.params_cull_mode = SpatialMaterial.CULL_DISABLED
	_rings_material.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
	scale = Vector3(radius * 2.0, radius * 2.0, 1.0)
	cast_shadow = SHADOW_CASTING_SETTING_ON
	hide()

func _ready() -> void:
	_on_ready()

func _on_ready():
	mesh = QuadMesh.new()
	set_surface_material(0, _rings_material)
	
	