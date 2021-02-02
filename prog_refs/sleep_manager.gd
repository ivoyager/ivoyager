# sleep_manager.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# "I, Voyager" is a registered trademark of Charlie Whitfield
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
# This manager is optional. If present, it will reduce process load by putting
# to sleep Body instances that we don't need to process. For now, we're mainly
# concerned with planet satellites (e.g., the 150+ moons of Jupiter and Saturn).
# TODO: Probably as an option, we'll also want to manage sleep for asteroids,
# which could represent many 1000s of Body instances.

class_name SleepManager

const IS_STAR_ORBITING := Enums.BodyFlags.IS_STAR_ORBITING
const NEVER_SLEEP := Enums.BodyFlags.NEVER_SLEEP

var _camera: Camera
var _camera_body: Body

func project_init() -> void:
	Global.connect("about_to_free_procedural_nodes", self, "_clear")
	Global.connect("camera_ready", self, "_connect_camera")

func _clear() -> void:
	_camera_body = null
	_disconnect_camera()

func _connect_camera(camera: Camera) -> void:
	if _camera != camera:
		_disconnect_camera()
		_camera = camera
		_camera.connect("parent_changed", self, "_camera_parent_changed")

func _disconnect_camera() -> void:
	if _camera and is_instance_valid(_camera):
		_camera.disconnect("parent_changed", self, "_camera_parent_changed")
	_camera = null

func _camera_parent_changed(body: Body) -> void:
	if _camera_body:
		_update_sleep_for_camera(_camera_body, false)
	_camera_body = body
	_update_sleep_for_camera(body, true)

func _update_sleep_for_camera(body: Body, is_incoming: bool) -> void:
	# We want the up-tree star orbiter, from which we will work down
	while not body.flags & IS_STAR_ORBITING:
		body = body.get_parent_spatial() as Body
		if !body:
			return
	_change_sleep_recursive(body, !is_incoming)

func _change_sleep_recursive(body: Body, sleep: bool) -> void:
	# Call on planet to put all satellites (and satellites of satellites) to
	# sleep; the planet has BodyFlags.NEVER_SLEEP so will not go to sleep.
	body.set_sleep(sleep)
	for satellite in body.satellites:
		_change_sleep_recursive(satellite, sleep)
