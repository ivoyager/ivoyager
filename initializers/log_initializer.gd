# log_initializer.gd
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

class_name LogInitializer


func _init() -> void:
	_on_init()
	
func _on_init() -> void:
	if !OS.is_debug_build() or !Global.debug_log_path:
		return
	var debug_log := File.new()
	if debug_log.open(Global.debug_log_path, File.WRITE) == OK:
		Global.debug_log = debug_log

func _project_init() -> void:
	Global.program.erase("LogInitializer") # frees self
