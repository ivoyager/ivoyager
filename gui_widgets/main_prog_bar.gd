# main_prog_bar.gd
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
class_name IVMainProgBar
extends ProgressBar
const SCENE := "res://ivoyager/gui_widgets/main_prog_bar.tscn"

# TODO: Clarify usage: Is this a widget or a program object? (It's currently
# added in IVProjectBuilder as a program object.)
#
# Target object must have property "progress" w/ integer value 0 - 100.
#
# Note: This will not visually update if the main thread is hung up on a
# multi-frame task. It is mainly usefull if the target object is operating
# on another thread.
#
# delay_start_frames can be useful to allow target object to reset it's
# progress when called on another thread.

var delay_start_frames := 0

var _delay_count := 0
var _object: Object


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	if _delay_count < delay_start_frames:
		_delay_count += 1
		return
	@warning_ignore("unsafe_property_access")
	value = _object.progress


func start(object: Object) -> void:
	_object = object
	value = 0
	set_process(true)
	show()


func stop() -> void:
	hide()
	set_process(false)
	_delay_count = 0

