# system_navigator.gd
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
# GUI widget

extends HBoxContainer

const DPRINT := false
const NULL_ROTATION := Vector3(-INF, -INF, -INF)
const IS_NAVIGATOR_MOON := Enums.BodyFlags.IS_NAVIGATOR_MOON

var size_proportions_exponent := 0.4 # 1.0 is "true" proportions
var horizontal_expansion := 550.0 # affects growth to right
var min_width := 30.0

var _registrar: Registrar
var _selection_manager: SelectionManager # get from ancestor selection_manager

func _ready():
	_registrar = Global.program.Registrar
	set_anchors_and_margins_preset(PRESET_WIDE, PRESET_MODE_KEEP_SIZE, 0)
	Global.connect("system_tree_ready", self, "_on_system_tree_ready", [], CONNECT_ONESHOT)

func _on_system_tree_ready(_is_loaded_game: bool) -> void:
	_selection_manager = GUIUtils.get_selection_manager(self)
	assert(_selection_manager)
	_build_navigation_tree()

func _build_navigation_tree() -> void:
	assert(DPRINT and prints("_build_navigation_tree") or true)
	# Navigation button/images are built at simulation start (new or loaded game).
#	_button_group = ButtonGroup.new()
	var total_size := 0.0
	# calculate star "slice" relative size
	var star: Body = _registrar.top_bodies[0]
	var star_slice_size := pow(star.m_radius / 20.0, size_proportions_exponent) # slice image has 10% width
	total_size += star_slice_size
	# calcultate planet relative sizes
	var biggest_size := 0.0 # used for planet vertical spacer
	for planet in star.satellites:
		var size := pow(planet.m_radius, size_proportions_exponent)
		total_size += size
		if biggest_size < size:
			biggest_size = size
	var expansion := horizontal_expansion - (star.satellites.size() * 5)
	var biggest_image_size := floor(biggest_size * expansion / total_size)
	total_size *= 1.09 # TODO: something less ad hoc for procedural
	# build the system button tree
	var image_size := floor(pow(star.m_radius / 20.0, size_proportions_exponent) * expansion / total_size)
	_add_nav_button(self, star, image_size, true)
	for planet in star.satellites: # vertical box for each planet w/ its moons
		var planet_vbox := VBoxContainer.new()
		planet_vbox.set_anchors_and_margins_preset(PRESET_WIDE, PRESET_MODE_KEEP_SIZE, 0)
		add_child(planet_vbox)
		image_size = floor(pow(planet.m_radius, size_proportions_exponent) * expansion / total_size)
		var v_spacer_size := floor((biggest_image_size - image_size) / 2) + 13 # plus adds space above planets
		var spacer := Control.new()
		spacer.rect_min_size = Vector2(min_width, v_spacer_size)
		planet_vbox.add_child(spacer)
		_add_nav_button(planet_vbox, planet, image_size, false)
		for moon in planet.satellites:
			if not moon.flags & IS_NAVIGATOR_MOON:
				continue
			image_size = floor(pow(moon.m_radius, size_proportions_exponent) * expansion / total_size)
			_add_nav_button(planet_vbox, moon, image_size, false)
	assert(DPRINT and call_deferred("debug_print") or true)
			
func debug_print():
	print("SystemNavigator size = ", rect_size)

func _add_nav_button(control: Control, body: Body, image_size: float, is_star_slice: bool) -> void:
	assert(DPRINT and prints("NavButton", tr(body.name), image_size) or true)
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
		set_anchors_and_margins_preset(PRESET_WIDE, PRESET_MODE_KEEP_SIZE, 0)
		add_constant_override("hseparation", 0)
		set("custom_fonts/font", Global.fonts.two_pt) # hack to allow smaller button height
		rect_min_size = Vector2(image_size, image_size) # smallest is really >>1 (~5?)
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
		connect("mouse_entered", self, "_on_mouse_entered")
		connect("mouse_exited", self, "_on_mouse_exited")

	func _ready():
		Global.connect("gui_refresh_requested", self, "_update_selection")
		_selection_manager.connect("selection_changed", self, "_update_selection")
		action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS

	func _pressed() -> void:
		_selection_manager.select(_selection_item)

	func _update_selection() -> void:
		var is_selected := _selection_manager.selection_item == _selection_item
		pressed = is_selected
		flat = !is_selected and !_has_mouse

	func _on_mouse_entered() -> void:
		_has_mouse = true
		flat = false

	func _on_mouse_exited() -> void:
		_has_mouse = false
		flat = !pressed
