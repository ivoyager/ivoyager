# signal_prog_bar.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield
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
# Target object must have property "progress" w/ integer value 0 - 100. This
# node updates when the main thread is idle, so the target object needs to be
# operating on another thread to see progress. delay_start_frames can be useful
# to allow target object to reset it's progress when called on another thread.

extends ProgressBar
class_name MainProgBar
const SCENE := "res://ivoyager/gui_admin/main_prog_bar.tscn"

var delay_start_frames := 0

var _object: Object
var _delay_count := 0

func start(object: Object) -> void:
	_object = object
	value = 0
	set_process(true)
	show()
	
func stop() -> void:
	hide()
	set_process(false)
	_delay_count = 0

func _project_init():
	connect("ready", self, "set_process", [false])

func _ready() -> void:
	set_process(false)

func _process(_delta: float) -> void:
	if _delay_count < delay_start_frames:
		_delay_count += 1
		return
	value = _object.progress
