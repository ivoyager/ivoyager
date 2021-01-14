# vis_on_mo_ckbx.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
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
# GUI widget. PanelContainer can be locked visible (toggle on) or visible on
# mouse-over only (toggle off). This widget is used in Planetarium.
#
# Target will be the first PanelContainer in this widget's ancestor tree. This
# widget uses _input() while in mouse-over mode; it's best not to use _input()
# where avoidable!

extends CheckBox

var detection_margins := Vector2(50.0, 50.0)

onready var _panel_container: PanelContainer
var _detection_rect := Rect2()
var _is_running := false
var _is_mouse_button_pressed := false
var _is_panel_visible := true

func _ready():
	Global.connect("run_state_changed", self, "_on_run_state_changed")
	_panel_container = _get_panel_container()
	_panel_container.connect("item_rect_changed", self, "_adjust_detection_rect")
	connect("toggled", self, "_on_toggled")
	set_process_input(false)

func _on_run_state_changed(is_running: bool) -> void:
	_is_running = is_running

func _get_panel_container() -> PanelContainer:
	var parent: Control = get_parent() # if error here, see useage above
	var panel_container := parent as PanelContainer
	while !panel_container:
		parent = parent.get_parent()
		panel_container = parent as PanelContainer
	return panel_container

func _adjust_detection_rect() -> void:
	_detection_rect.position = _panel_container.rect_position - detection_margins
	_detection_rect.size = _panel_container.rect_size + 2.0 * detection_margins

func _on_toggled(is_pressed: bool) -> void:
	if is_pressed:
		set_process_input(false)
		_panel_container.show()
	else:
		set_process_input(true)

func _input(event: InputEvent) -> void:
	# We process input only when in mouse-over mode
	if !_is_running:
		return
	if event is InputEventMouseButton:
		_is_mouse_button_pressed = event.pressed # don't show/hide GUIs during mouse drag
	elif event is InputEventMouseMotion:
		if _is_mouse_button_pressed:
			return # don't show/hide during mouse drag!
		var new_visible := _detection_rect.has_point(event.position)
		if _is_panel_visible != new_visible:
			_is_panel_visible = new_visible
			_panel_container.visible = new_visible
