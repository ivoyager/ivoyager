# view_collection.gd
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
class_name IVViewCollection
extends HFlowContainer

# GUI widget that coordinates with IVViewSaveButton and houses the saved view
# buttons. IVViewSaveButton can be added inside this container or elsewhere.
# 
# Call init() to populate the saved view buttons and to init IVViewSaveButton
# and IVViewSaver.

onready var _view_manager: IVViewManager = IVGlobal.program.ViewManager


var default_view_name := "LABEL_CUSTOM1" # will increment if taken
var set_name := ""
var is_cached := true
var show_flags := IVView.ALL


func _ready() -> void:
	IVGlobal.connect("about_to_start_simulator", self, "_build_view_buttons")
	IVGlobal.connect("about_to_free_procedural_nodes", self, "_clear")


func init(view_save_button: IVViewSaveButton, default_view_name_ := "LABEL_CUSTOM1",
		set_name_ := "", is_cached_ := true,
		show_flags_ := IVView.ALL, init_flags := IVView.ALL,
		reserved_names := []) -> void:
	# Call from containing scene.
	# This method calls IVViewSaveButton.init() which calls IVViewSaver.init().
	# Make 'set_name_' unique to not share views with other GUI instances. 
	default_view_name = default_view_name_
	set_name = set_name_
	is_cached = is_cached_
	show_flags = show_flags_
	view_save_button.init(default_view_name, set_name, is_cached, show_flags, init_flags,
			reserved_names)
	view_save_button.connect("view_saved", self, "_on_view_saved")
	if IVGlobal.state.is_started_or_about_to_start:
		_build_view_buttons()


func _clear() -> void:
	for child in get_children():
		if child is ViewButton:
			child.queue_free()


func _build_view_buttons(_dummy := false) -> void:
	var view_names := _view_manager.get_view_names_in_set(set_name, is_cached)
	for view_name in view_names:
		_build_view_button(view_name)


func _build_view_button(view_name: String) -> void:
	var button := ViewButton.new(view_name)
	button.connect("pressed", self, "_on_button_pressed", [button])
	button.connect("right_clicked", self, "_on_button_right_clicked", [button])
	add_child(button)


func _on_view_saved(view_name: String) -> void:
	_build_view_button(view_name)
	

func _on_button_pressed(button: ViewButton) -> void:
	_view_manager.set_view(button.text, set_name, is_cached)


func _on_button_right_clicked(button: ViewButton) -> void:
	_view_manager.remove_view(button.text, set_name, is_cached)
	button.queue_free()



class ViewButton extends Button:
	# Provides right-clicked signal for removal.
	
	signal right_clicked()
	
	func _init(view_name: String) -> void:
		text = view_name
	
	func _gui_input(event: InputEvent) -> void:
		var mouse_button_event := event as InputEventMouseButton
		if mouse_button_event and mouse_button_event.button_index == BUTTON_RIGHT:
			emit_signal("right_clicked")
	
