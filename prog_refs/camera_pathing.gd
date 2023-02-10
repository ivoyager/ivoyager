# camera_pathing.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2023 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield in the US
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# *****************************************************************************
class_name IVCameraPathing
extends Reference

# Provides camera path determination and interpolation.
# What do we want to minimize?

const math := preload("res://ivoyager/static/math.gd") 


func interpolate_cartesian_path(from_transform: Transform, from_spatial: Spatial,
		to_transform: Transform, to_spatial: Spatial, current_spatial: Spatial,
		progress: float) -> Transform:
	# Here for reference. Just a simple cartesian interpolation.
	
	# translation
	var from_global_translation := from_spatial.global_translation + from_transform.origin
	var to_global_translation := to_spatial.global_translation + to_transform.origin
	var translation := from_global_translation.linear_interpolate(to_global_translation, progress)
	translation -= current_spatial.global_translation
	
	# basis
	var from_global_basis := from_spatial.global_transform.basis * from_transform.basis
	var to_global_basis := to_spatial.global_transform.basis * to_transform.basis
	var basis := from_global_basis.slerp(to_global_basis, progress)
	basis = current_spatial.global_transform.basis.inverse() * basis
	
	return Transform(basis, translation)


func interpolate_spherical_path(from_transform: Transform, from_spatial: Spatial,
		to_transform: Transform, to_spatial: Spatial, current_spatial: Spatial,
		progress: float) -> Transform:
	# Interpolate spherical coordinates around a reference Spatial. Reference
	# is either the parent (if 'from' or 'to' is child of the other) or common
	# ancestor. This is likely the dominant view object during transition, so
	# we want to minimize orientation change relative to it.
	var ref_spatial := get_reference_spatial(from_spatial, to_spatial)
	
	# translation
	var ref_global_translation := ref_spatial.global_translation
	var from_global_translation := from_spatial.global_translation + from_transform.origin
	var to_global_translation := to_spatial.global_translation + to_transform.origin
	var from_ref_translation := from_global_translation - ref_global_translation
	var to_ref_translation := to_global_translation - ref_global_translation
	
	# Godot 3.5.2 BUG? angle_to() seems to break with large vectors. Needs testing.
	var from_direction := from_ref_translation.normalized()
	var to_direction := to_ref_translation.normalized()
	var rotation_axis := from_direction.cross(to_direction).normalized()
	if !rotation_axis: # edge case
		rotation_axis = Vector3(0.0, 0.0, 1.0)
	var path_angle := from_direction.angle_to(to_direction) # < PI
	var ref_translation := from_direction.rotated(rotation_axis, path_angle * progress)
	ref_translation *= lerp(from_ref_translation.length(), to_ref_translation.length(), progress)
	var translation := ref_translation + ref_global_translation - current_spatial.global_translation

	# Quat.slerp() for basis change
	var from_global_basis := from_spatial.global_transform.basis * from_transform.basis
	var to_global_basis := to_spatial.global_transform.basis * to_transform.basis
	var from_global_quat := Quat(from_global_basis)
	var to_global_quat := Quat(to_global_basis)
	var global_quat := from_global_quat.slerp(to_global_quat, progress)
	var global_basis := Basis(global_quat)
	var basis := current_spatial.global_transform.basis.inverse() * global_basis
	
	# Basis.slerp()
#	var from_global_basis := from_spatial.global_transform.basis * from_transform.basis
#	var to_global_basis := to_spatial.global_transform.basis * to_transform.basis
#	var basis := from_global_basis.slerp(to_global_basis, progress)
#	basis = current_spatial.global_transform.basis.inverse() * basis
	
	# Euler angles
#	var from_global_basis := from_spatial.global_transform.basis * from_transform.basis
#	var to_global_basis := to_spatial.global_transform.basis * to_transform.basis
#	var from_global_euler := from_global_basis.get_euler()
#	var to_global_euler := to_global_basis.get_euler()
#	var global_euler := Vector3(
#		lerp_angle(from_global_euler[0], to_global_euler[0], progress),
#		lerp_angle(from_global_euler[1], to_global_euler[1], progress),
#		lerp_angle(from_global_euler[2], to_global_euler[2], progress)
#	)
#	var global_basis := Basis(global_euler)
#	var basis := current_spatial.global_transform.basis.inverse() * global_basis

	return Transform(basis, translation)


func get_reference_spatial(spatial1: Spatial, spatial2: Spatial) -> Spatial:
	# Returns parent spatial or common ancestor.
	while spatial1:
		var loop_spatial2 := spatial2
		while loop_spatial2:
			if spatial1 == loop_spatial2:
				return loop_spatial2
			loop_spatial2 = loop_spatial2.get_parent_spatial()
		spatial1 = spatial1.get_parent_spatial()
	assert(false)
	return null

