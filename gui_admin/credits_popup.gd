# credits_popup.gd
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
# WIP - I'm not super happy with the credits appearance right now. Needs work!
# This was narrowly coded to parse ivoyager/CREDITS.md or file with identical
# markup. Someone can generalize if they want.

extends PopupPanel
class_name CreditsPopup
const SCENE := "res://ivoyager/gui_admin/credits_popup.tscn"

enum {
	PLAIN_TEXT,
	MAIN_HEADER,
	SUBSECTION_HEADER,
	BLOCK_TEXT,
	BOLD_TEXT
	}

# project vars - modify on project_objects_instantiated signal
var file_path := "res://ivoyager/CREDITS.md" # change to "res://CREDITS.md"
var scroll_size := Vector2(950, 630)
var autowrap_reduction := 15
var subpanel_reduction := 50
var spacer_size := 10
var block_text_label_prepend := "    "
var line_codes := {
	# match from left - order matters
	"" : PLAIN_TEXT, # not matched
	"## " : SUBSECTION_HEADER,
	"##" : SUBSECTION_HEADER, # empty header is break line
	"# " : MAIN_HEADER,
	"    " : BLOCK_TEXT,
	}

var _main: Main
var _header: Label
var _content: VBoxContainer
var _close_button: Button
var _current_container: Container
var _current_label: Label
var _text := ""


func project_init() -> void:
	connect("ready", self, "_on_ready")
	connect("popup_hide", self, "_on_popup_hide")
	Global.connect("credits_requested", self, "_open")
	_main = Global.program.Main
	var main_menu: MainMenu = Global.program.get("MainMenu")
	if main_menu:
		main_menu.make_button("BUTTON_CREDITS", 400, true, false, self, "_open")

func _on_ready() -> void:
	theme = Global.themes.main
	set_process_unhandled_key_input(false)
	_header = $VBox/Header
	_content = $VBox/Scroll/Content
	_close_button = $VBox/Close
	_close_button.connect("pressed", self, "hide")
	$VBox/Scroll.rect_min_size = scroll_size

func _open() -> void:
	set_process_unhandled_key_input(true)
	_main.require_stop(self)
	if !_build_content():
		_main.allow_run(self)
		return
	popup()
	set_anchors_and_margins_preset(PRESET_CENTER, PRESET_MODE_MINSIZE)

func _on_popup_hide() -> void:
	set_process_unhandled_key_input(false)
	_current_container = null
	_current_label = null
	_text = ""
	for child in _content.get_children():
		child.queue_free()
	_main.allow_run(self)

func _build_content() -> bool:
	var file := File.new()
	if file.open(file_path, File.READ) != OK:
		print("ERROR: Could not open for read: ", file_path)
		return false
	_current_container = _content
	var code := -1
	var need_end := false
	var line := file.get_line()
	while !file.eof_reached():
		if !line:
			line = file.get_line()
			continue
		var markup = _get_markup(line)
		line = line.lstrip(markup)
		var new_code: int = line_codes[markup]
		if new_code != code:
			if need_end:
				_end_markup_type(code)
			code = new_code
			_begin_markup_type(code)
			need_end = true
		_text += line + "\n"
		line = file.get_line()
	if need_end:
		_end_markup_type(code)
	return true

func _begin_markup_type(code: int) -> void:
	match code:
		MAIN_HEADER:
			_header.set("custom_fonts/font", Global.fonts.large)
			_header.size_flags_horizontal = SIZE_SHRINK_CENTER
		SUBSECTION_HEADER:
			_current_container = _content
			_current_label = Label.new()
			_current_label.set("custom_fonts/font", Global.fonts.medium)
			_current_label.size_flags_horizontal = SIZE_SHRINK_CENTER
		PLAIN_TEXT, BOLD_TEXT:
			_current_container = _content
			_current_label = Label.new()
			_current_label.autowrap = true
			_current_label.size_flags_horizontal = SIZE_SHRINK_CENTER
			_current_label.rect_min_size.x = scroll_size.x - subpanel_reduction
		BLOCK_TEXT:
			_current_container = PanelContainer.new()
			_current_container.rect_min_size.x = scroll_size.x - subpanel_reduction
			_current_container.size_flags_horizontal = SIZE_SHRINK_CENTER
			_current_label = Label.new()
			_current_label.autowrap = true
			_current_label.size_flags_horizontal = SIZE_EXPAND_FILL
			_current_label.rect_min_size.x = scroll_size.x - subpanel_reduction - autowrap_reduction

func _end_markup_type(code: int) -> void:
	_text = _text.rstrip("\n")
	match code:
		MAIN_HEADER:
			_header.text = _text
			_text = ""
		SUBSECTION_HEADER:
			var spacer := Control.new()
			spacer.rect_min_size.y = spacer_size
			_content.add_child(spacer)
			if !_text: # empty header
				_current_label.queue_free()
				continue
			_current_label.text = _text
			_text = ""
			_content.add_child(_current_label)
		PLAIN_TEXT, BOLD_TEXT:
			_current_label.text = _text
			_text = ""
			_content.add_child(_current_label)
		BLOCK_TEXT:
			_text = _text.replacen("\n", "\n" + block_text_label_prepend)
			_current_label.text = block_text_label_prepend + _text
			_text = ""
			_current_container.add_child(_current_label)
			_content.add_child(_current_container)
	
func _get_markup(line: String) -> String:
	for markup in line_codes:
		if markup and line.begins_with(markup):
			return markup
	return ""

func _unhandled_key_input(event: InputEventKey) -> void:
	_on_unhandled_key_input(event)
	
func _on_unhandled_key_input(event: InputEventKey) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		hide()

	
	

