# sbg_finisher.gd
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
class_name IVSBGFinisher
extends RefCounted

# Adds SBGPoints and SBGOrbits for SmallBodiesGroup instances.

signal system_build_finished()


var _SBGPoints_: GDScript
var _SBGOrbits_: GDScript

var _io_manager: IVIOManager

var _system_build_start_msec := 0
var _is_building_system := false
var _started_count := 0
var _finished_count := 0
var _sb_count := 0


func _project_init() -> void:
	IVGlobal.get_tree().node_added.connect(_on_node_added)
	_SBGPoints_ = IVGlobal.procedural_classes[&"_SBGPoints_"]
	_SBGOrbits_ = IVGlobal.procedural_classes[&"_SBGOrbits_"]
	_io_manager = IVGlobal.program[&"IOManager"]


func init_system_build() -> void:
	# Called by IVSystemBuilder if this is system build for new or loaded game.
	_is_building_system = true
	_started_count = 0
	_finished_count = 0
	_sb_count = 0


func _on_node_added(node: Node) -> void:
	var sbg := node as IVSmallBodiesGroup
	if !sbg:
		return
	if _is_building_system and _started_count == 0:
		_system_build_start_msec = Time.get_ticks_msec()
	_started_count += 2
	_init_hud_points.call_deferred(sbg)
	_init_hud_orbits.call_deferred(sbg)


func _init_hud_points(sbg: IVSmallBodiesGroup) -> void:
	var sbg_points: IVSBGPoints = _SBGPoints_.new(sbg)
	var primary_body: IVBody = sbg.get_parent()
	primary_body.add_child(sbg_points)
	_finished_count += 1
	_sb_count += sbg.get_number()
	if _is_building_system and _finished_count == _started_count:
		_finish_system_build()


func _init_hud_orbits(sbg: IVSmallBodiesGroup) -> void:
	var sbg_orbits: IVSBGOrbits = _SBGOrbits_.new(sbg)
	var primary_body: IVBody = sbg.get_parent()
	primary_body.add_child(sbg_orbits)
	_finished_count += 1
	if _is_building_system and _finished_count == _started_count:
		_finish_system_build()


func _finish_system_build() -> void: # main thread
	_is_building_system = false
	var msec :=  Time.get_ticks_msec() - _system_build_start_msec
	@warning_ignore("integer_division")
	print("Added %s small bodies in %s groups (IVSmallBodiesGroup) in %s msec"
			% [_sb_count, _finished_count / 2, msec])
	system_build_finished.emit()

