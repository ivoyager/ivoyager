# time_set_popup.gd
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
class_name IVTimeSetPopup
extends PopupPanel
const SCENE := "res://ivoyager/gui_popups/time_set_popup.tscn"

# Call popup() to show.


func _ready() -> void:
	connect("about_to_show", self, "_on_about_to_show")
	$"%TimeSetter".connect("time_set", self, "_on_time_set")


func _on_about_to_show() -> void:
	$"%TimeSetter".set_current()


func _on_time_set(is_close: bool) -> void:
	if is_close:
		hide()

