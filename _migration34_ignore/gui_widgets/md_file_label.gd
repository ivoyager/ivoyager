# md_file_label.gd
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
class_name IVMDFileLabel
extends RichTextLabel

# GUI widget. Reads an extermal .md file and converts to BB code with links.
# This is narrowly coded to read ivoyager/credits.md. Someone should expand
# its function to additional md features.

var regexes := [
	["header", "^## (.+)"],
	["empty_header", "^##$"],
	["url", "\\[(.+)\\]\\((http.+)\\)"],
]

var _urls := {}


func _ready():
	connect("meta_clicked", Callable(self, "_on_meta_clicked"))
	for regex_array in regexes:
		var regular_expression = regex_array[1]
		var regex := RegEx.new()
		regex.compile(regular_expression)
		regex_array[1] = regex


func read_file(path: String, skip_header := true) -> void:
	var file := File.new()
	if file.open(path, File.READ) != OK:
		print("ERROR: Could not open for read: ", path)
		return
	var converted_text := ""
	while true:
		var line := file.get_line()
		if file.eof_reached():
			break
		if !line:
			continue
		if skip_header and line.begins_with("# "):
			skip_header = false
			continue
		converted_text += convert_line(line)
	text = converted_text


func convert_line(line: String) -> String:
	for regex_array in regexes:
		var type: String = regex_array[0]
		var regex: RegEx = regex_array[1]
		var regex_match = regex.search(line)
		if !regex_match:
			continue
		match type:
			"header":
				line = "\n" + regex_match.get_string(1) + "\n"
			"empty_header":
				line = "\n"
			"url":
				var whole = regex_match.get_string(0)
				var txt = regex_match.get_string(1)
				var url = regex_match.get_string(2)
				_urls[txt] = url
				line = line.replace(whole, "[url]" + txt + "[/url]")
	return line + "\n"


func _on_meta_clicked(meta: String) -> void:
	var url: String = _urls[meta]
	prints("Opening external link:", url)
	OS.shell_open(url)
