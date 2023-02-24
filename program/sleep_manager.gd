# sleep_manager.gd
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
class_name IVSleepManager
extends Reference

# This manager is optional. If present, it will reduce process load by putting
# to sleep IVBody instances that we don't need to process. For now, we're mainly
# concerned with planet satellites (e.g., the 150+ moons of Jupiter and Saturn).
# TODO: Probably as an option, we'll also want to manage sleep for asteroids,
# which could represent many 1000s of IVBody instances depending on extension
# project.

const IS_STAR_ORBITING := IVEnums.BodyFlags.IS_STAR_ORBITING

var _camera: Camera
var _current_star_orbiter: IVBody


func _project_init() -> void:
	IVGlobal.connect("about_to_start_simulator", self, "_on_about_to_start_simulator")
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_clear")
	IVGlobal.connect("camera_ready", self, "_connect_camera")


func _on_about_to_start_simulator(_is_new_game: bool) -> void:
	for body in IVGlobal.top_bodies:
		_change_satellite_sleep_recursive(body, true)


func _clear() -> void:
	_current_star_orbiter = null
	_disconnect_camera()


func _connect_camera(camera: Camera) -> void:
	if _camera != camera:
		_disconnect_camera()
		_camera = camera
		_camera.connect("parent_changed", self, "_on_camera_parent_changed")


func _disconnect_camera() -> void:
	if _camera and is_instance_valid(_camera):
		_camera.disconnect("parent_changed", self, "_on_camera_parent_changed")
	_camera = null


func _on_camera_parent_changed(body: IVBody) -> void:
	var to_star_orbiter := _get_star_orbiter(body)
	if _current_star_orbiter == to_star_orbiter:
		return
	if _current_star_orbiter:
		_change_satellite_sleep_recursive(_current_star_orbiter, true)
	if to_star_orbiter:
		_change_satellite_sleep_recursive(to_star_orbiter, false)
	_current_star_orbiter = to_star_orbiter


func _get_star_orbiter(body: IVBody) -> IVBody:
	while not body.flags & IS_STAR_ORBITING:
		body = body.get_parent_spatial() as IVBody
		if !body: # reached the top
			return null
	return body


func _change_satellite_sleep_recursive(body: IVBody, sleep: bool) -> void:
	for satellite in body.satellites:
		satellite.set_sleep(sleep)
		_change_satellite_sleep_recursive(satellite, sleep)
