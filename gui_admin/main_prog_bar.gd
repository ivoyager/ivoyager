# signal_prog_bar.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2019 Charlie Whitfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# *****************************************************************************
#
# Target object must have property "progress" w/ integer value 0 - 100. This
# node updates when the main thread is idle, so the target object needs to be
# operating on another thread to see progress.

extends ProgressBar
class_name MainProgBar
const SCENE := "res://ivoyager/gui_admin/main_prog_bar.tscn"

var _object: Object

func start(object: Object) -> void:
	_object = object
	value = 0
	set_process(true)
	show()
	
func stop() -> void:
	hide()
	set_process(false)

func project_init():
	connect("ready", self, "set_process", [false])

func _process(delta: float) -> void:
	_on_process(delta)
	
func _on_process(_delta: float) -> void:
	value = _object.progress
