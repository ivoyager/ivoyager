# debug.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
# Copyright (c) 2017-2020 Charlie Whitfield
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
# Singleton "Debug". To avoid overhead in non-debug builds, wrap Debug calls in
# assert(). E.g., assert(Debug.dlog("something")).

extends Node

const file_utils := preload("res://ivoyager/static/file_utils.gd")

# print settings
#const PROFILER_UPDATE_SEC = 0 # 0 to disable
const PRINT_FRAME_HANGS = false
const ROUTINE_PRINT = false
const VERBOSE_PRINT = false
const DEBUG_PRINT = false

const LOGS_PATH = "user://logs"
const LOGS_EXTENSION = ".log"

var logging_period = 0.0 # seconds; != 0.0 writes logs during runtime

var _logs = { # strings replaced by files at _ready()
	loga = "a",
	logb = "b",
	logc = "c",
	logd = "debug",
	}

var _logs_inited = false

func _ready():
	# Logs overwritten at startup.
	file_utils.make_dir_if_doesnt_exist(LOGS_PATH)
	for key in _logs:
		var log_name = _logs[key]
		var log_path = LOGS_PATH.plus_file(log_name + LOGS_EXTENSION)
		var file = File.new()
		file.open(log_path, File.WRITE)
		_logs[key] = file
	_logs_inited = true
	force_logging_periodic()

func force_logging_periodic():
	# FIXME or open issue: enabling with logging_period != 0.0 causes 
	# errors at quit indicating memory leaks
	logging_period = 0.0 # temp disable
	
	while logging_period != 0.0:
		yield(get_tree().create_timer(logging_period), "timeout")
		force_logging()

func force_logging():
	# Set logging_period != 0.0 or press ctrl-shift-D to call. Logs aren't
	# normally written during runtime. We force write by closing/opening files.
	print("force logging")
	for key in _logs:
		var file = _logs[key]
		var log_path = file.get_path()
		file.close()
		file.open(log_path, File.READ_WRITE)
		file.seek_end()

func add_log(log_name, override_log_func = null):
	# Do this before this singleton's _ready() to add log file names written to
	# with logn(), or to override default log names written to by loga(), logb(),
	# logc() and logd().
	assert(!_logs_inited)
	assert(override_log_func == null or _logs.has(override_log_func))
	if override_log_func != null:
		_logs[override_log_func] = log_name
	else:
		_logs[log_name] = log_name
	return true

func loga(arg1, arg2 = "`", arg3 = "`"):
	return log_file("loga", arg1, arg2, arg3)

func logb(arg1, arg2 = "`", arg3 = "`"):
	return log_file("logb", arg1, arg2, arg3)

func logc(arg1, arg2 = "`", arg3 = "`"):
	return log_file("logc", arg1, arg2, arg3)

func logd(arg1, arg2 = "`", arg3 = "`"):
	return log_file("logd", arg1, arg2, arg3)

func log_file(log_name, arg1, arg2 = "`", arg3 = "`"):
	var log_line = str(arg1)
	if typeof(arg2) != TYPE_STRING or arg2 != "`":
		log_line += " %s" % arg2
		if typeof(arg3) != TYPE_STRING or arg3 != "`":
			log_line += " %s" % arg3
	_logs[log_name].store_line(log_line)
	return true

static func rprint(arg1, arg2 = "`", arg3 = "`"):
	if ROUTINE_PRINT:
		var line = str(arg1)
		if typeof(arg2) != TYPE_STRING or arg2 != "`":
			line += " %s" % arg2
			if typeof(arg3) != TYPE_STRING or arg3 != "`":
				line += " %s" % arg3
		print(line)
	return true

static func vprint(arg1, arg2 = "`", arg3 = "`"):
	if VERBOSE_PRINT:
		var line = str(arg1)
		if typeof(arg2) != TYPE_STRING or arg2 != "`":
			line += " %s" % arg2
			if typeof(arg3) != TYPE_STRING or arg3 != "`":
				line += " %s" % arg3
		print(line)
	return true

static func dprint(arg1, arg2 = "`", arg3 = "`"):
	if DEBUG_PRINT:
		var line = str(arg1)
		if typeof(arg2) != TYPE_STRING or arg2 != "`":
			line += " %s" % arg2
			if typeof(arg3) != TYPE_STRING or arg3 != "`":
				line += " %s" % arg3
		print(line)
	return true
