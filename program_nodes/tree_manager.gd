# tree_manager.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2019 Charlie Whitfield
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
#
# Manages processing and visibility of system tree nodes.

extends Node
class_name TreeManager

const DPRINT := false

signal show_icons_changed(is_show)
signal show_labels_changed(is_show)
signal show_orbits_changed(is_show)


# public - read-only except for project init
var show_orbits := false
var show_icons := false
var show_labels := false

const PERSIST_AS_PROCEDURAL_OBJECT := false
const PERSIST_PROPERTIES := ["show_orbits", "show_icons", "show_labels"]

# unpersisted
var _global_time_array: Array = Global.time_array
var _settings: Dictionary = Global.settings
var _icon_quad_mesh: QuadMesh = Global.icon_quad_mesh # shared by hud_icons
var _root: Viewport
var _registrar: Registrar
var _math: Math
var _camera: VoyagerCamera
var _at_local_star_orbiter: Body
var _to_local_star_orbiter: Body
var _skip_local_system := {}
var _prev_fov := 50.0
var _viewport_height := 0.0


func set_show_icons(is_show: bool) -> void:
	show_icons = is_show
	if is_show and show_labels:
		set_show_labels(false)
	assert(DPRINT and prints("set_show_icons", is_show) or true)
	emit_signal("show_icons_changed", is_show)
	
func set_show_labels(is_show: bool) -> void:
	show_labels = is_show
	if is_show and show_icons:
		set_show_icons(false)
	assert(DPRINT and prints("set_show_labels", is_show) or true)
	emit_signal("show_labels_changed", is_show)

func set_show_orbits(is_show: bool) -> void:
	show_orbits = is_show
	assert(DPRINT and prints("set_show_orbits", is_show) or true)
	emit_signal("show_orbits_changed", is_show)


func project_init() -> void:
	Global.connect("about_to_free_procedural_nodes", self, "_clear_procedural")
	Global.connect("camera_ready", self, "_connect_camera")
	Global.connect("gui_refresh_requested", self, "_gui_refresh")
	Global.connect("setting_changed", self, "_settings_listener")
	_root = Global.objects.root
	_registrar = Global.objects.Registrar
	_math = Global.objects.Math
	_root.connect("size_changed", self, "_update_icon_size")
	_viewport_height = _root.get_visible_rect().size.y

func _clear_procedural() -> void:
	_at_local_star_orbiter = null
	_to_local_star_orbiter = null
	_disconnect_camera()
	_skip_local_system.clear()

func _gui_refresh() -> void:
	emit_signal("show_orbits_changed", show_orbits)
	emit_signal("show_icons_changed", show_icons)
	emit_signal("show_labels_changed", show_labels)
	_update_icon_size()

func _connect_camera(camera: VoyagerCamera) -> void:
	if _camera != camera:
		_disconnect_camera()
		_camera = camera
		_camera.connect("processed", self, "_camera_update")
		_camera.connect("move_started", self, "_camera_move_started")
		_camera.connect("parent_changed", self, "_camera_parent_changed")
		assert(DPRINT and prints("connected camera:", _camera) or true)

func _disconnect_camera() -> void:
	if _camera:
		_camera.disconnect("processed", self, "_camera_update")
		_camera.disconnect("move_started", self, "_camera_move_started")
		_camera.disconnect("parent_changed", self, "_camera_parent_changed")
		assert(DPRINT and prints("disconnected camera:", _camera) or true)
		_camera = null

func _camera_update(camera_global_translation: Vector3, fov: float) -> void: # every frame
	# fix icon QuadMesh if fov change
	if _prev_fov != fov:
		_prev_fov = fov
		_update_icon_size()
	var time: float = _global_time_array[0]
	_process_body(_registrar.top_body, camera_global_translation, time)

func _process_body(body: Body, camera_global_translation: Vector3, time: float) -> void:
	# barycenter mechanic expects children processed before parent
	if body.satellites:
		# skip over planet or planetoid systems we are not at or going to
		if body.is_star_orbiting and !body.is_star and body != _at_local_star_orbiter and body != _to_local_star_orbiter:
			if !_skip_local_system.get(body):
				_skip_local_system[body] = true
				for satellite in body.satellites:
					satellite.hide_visuals()
		else: # recursive process call
			_skip_local_system[body] = false
			for satellite in body.satellites:
				_process_body(satellite, camera_global_translation, time)
	body.tree_manager_process(time, show_orbits, show_icons, show_labels, camera_global_translation, _camera)

func _camera_move_started(to_body: Body, _is_camera_lock: bool) -> void:
	_to_local_star_orbiter = _get_local_star_orbiter(to_body)

func _camera_parent_changed(body: Body) -> void:
	_at_local_star_orbiter = _get_local_star_orbiter(body)
	_to_local_star_orbiter = null

func _get_local_star_orbiter(body: Body) -> Body:
	if body.is_star_orbiting:
		return body
	if body.is_star:
		return null
	return _get_local_star_orbiter(body.get_parent())

func _update_icon_size() -> void:
	if !_camera:
		return
	var scaling_factor := _math.get_fov_scaling_factor(_camera.fov)
	_viewport_height = _root.get_visible_rect().size.y
	_icon_quad_mesh.size = Vector2.ONE * (_settings.viewport_icon_size * scaling_factor / _viewport_height)

func _settings_listener(setting: String, _value) -> void:
	if setting == "viewport_icon_size":
		_update_icon_size()
