# system_navigator.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2019 Charlie Whitfield
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

extends HBoxContainer
class_name SystemNavigator
const SCENE := "res://ivoyager/gui_widgets/system_navigator.tscn"


const DPRINT := false
const SIZE_PROPORTIONS_EXPONENT := 0.4 # 1.0 is "true" proportions

var _registrar: Registrar
var _selection_manager: SelectionManager # get from ancestor selection_manager
var _h_size := 550.0 # replaced if ancestor has system_navigator_h_size

func _ready():
	_registrar = Global.objects.Registrar
	var ancestor: Node = get_parent()
	while ancestor is Control:
		if "selection_manager" in ancestor:
			_selection_manager = ancestor.selection_manager
			break
		ancestor = ancestor.get_parent()
	assert(_selection_manager)
	ancestor = get_parent()
	while ancestor is Control:
		if "system_navigator_h_size" in ancestor:
			_h_size = ancestor.system_navigator_h_size
			break
		ancestor = ancestor.get_parent()
	set_anchors_and_margins_preset(PRESET_WIDE, PRESET_MODE_KEEP_SIZE, 0)
	Global.connect("system_tree_ready", self, "_build_navigation_tree")

func _build_navigation_tree(_is_loaded_game: bool) -> void:
	assert(DPRINT and prints("_build_navigation_tree") or true)
	# Navigation button/images are built at simulation start (new or loaded game).
	var total_size := 0.0
	# calculate star "slice" relative size
	var star := _registrar.top_body
	var star_slice_size := pow(star.m_radius / 20.0, SIZE_PROPORTIONS_EXPONENT) # slice image has 10% width
	total_size += star_slice_size
	# calcultate planet relative sizes
	var biggest_size := 0.0 # used for planet vertical spacer
	for planet in star.satellites:
		var size := pow(planet.m_radius, SIZE_PROPORTIONS_EXPONENT)
		total_size += size
		if biggest_size < size:
			biggest_size = size
	var expansion := _h_size - (star.satellites.size() * 5)
	var biggest_image_size := floor(biggest_size * expansion / total_size)
	total_size *= 1.09 # TODO: something less ad hoc for procedural
	# build the system button tree
	var image_size := floor(pow(star.m_radius / 20.0, SIZE_PROPORTIONS_EXPONENT) * expansion / total_size)
	_add_nav_button(self, star, image_size, true)
	for planet in star.satellites: # vertical box for each planet w/ its moons
		var planet_vbox := VBoxContainer.new()
		planet_vbox.set_anchors_and_margins_preset(PRESET_WIDE, PRESET_MODE_KEEP_SIZE, 0)
		add_child(planet_vbox)
		image_size = floor(pow(planet.m_radius, SIZE_PROPORTIONS_EXPONENT) * expansion / total_size)
		var v_spacer_size := floor((biggest_image_size - image_size) / 2) + 13 # plus adds space above planets
		var spacer := Control.new()
		spacer.rect_min_size = Vector2(30, v_spacer_size)
		planet_vbox.add_child(spacer)
		_add_nav_button(planet_vbox, planet, image_size, false)
		for moon in planet.satellites:
			if moon.is_minor_moon:
				continue
			image_size = floor(pow(moon.m_radius, SIZE_PROPORTIONS_EXPONENT) * expansion / total_size)
			_add_nav_button(planet_vbox, moon, image_size, false)
	assert(DPRINT and call_deferred("debug_print") or true)
			
func debug_print():
	print("SystemNavigator size = ", rect_size)

func _add_nav_button(control: Control, body: Body, image_size: float,
		is_star_slice: bool) -> void:
	var selection_item := _registrar.get_selection_for_body(body)
	var nav_button := NavButton.new(selection_item, _selection_manager, image_size, is_star_slice)
	control.add_child(nav_button)

# ****************************** INNER CLASS **********************************

class NavButton extends Button:
	
	var _has_mouse := false
	var _selection_item: SelectionItem
	var _selection_manager: SelectionManager
	
	func _init(selection_item: SelectionItem, selection_manager: SelectionManager, image_size: float,
			is_star_slice: bool) -> void:
		_selection_item = selection_item
		_selection_manager = selection_manager
		toggle_mode = true
		if image_size < 5.0: # Doesn't matter??? Engine seems to set min = 8.0.
			image_size = 5.0
		set_anchors_and_margins_preset(PRESET_WIDE, PRESET_MODE_KEEP_SIZE, 0)
		add_constant_override("hseparation", 0)
		set("custom_fonts/font", Global.fonts.two_pt) # hack to allow small button height
		rect_min_size = Vector2(image_size, image_size)
		flat = true
		focus_mode = FOCUS_ALL
		var texture_box := TextureRect.new()
		texture_box.set_anchors_and_margins_preset(PRESET_WIDE, PRESET_MODE_KEEP_SIZE, 0)
		texture_box.expand = true
		if is_star_slice:
			texture_box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			texture_box.texture = selection_item.texture_slice_2d
		else:
			texture_box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_box.texture = selection_item.texture_2d
		texture_box.rect_min_size = Vector2(image_size, image_size)
		texture_box.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(texture_box)
		connect("mouse_entered", self, "_mouse_entered")
		connect("mouse_exited", self, "_mouse_exited")
		
	func _ready():
		_selection_manager.connect("selection_changed", self, "_update_selection")

	func _toggled(_button_pressed: bool) -> void:
		_selection_manager.select(_selection_item)

	func _update_selection() -> void:
		var is_selected := _selection_manager.selection_item == _selection_item
		pressed = is_selected
		flat = !is_selected and !_has_mouse

	func _mouse_entered() -> void:
		_has_mouse = true
		flat = false
		
	func _mouse_exited() -> void:
		_has_mouse = false
		flat = !pressed


