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

const IS_PLANET := Enums.BodyFlags.IS_TRUE_PLANET | Enums.BodyFlags.IS_DWARF_PLANET
const IS_NAVIGATOR_MOON := Enums.BodyFlags.IS_NAVIGATOR_MOON
const STAR_SLICE_MULTIPLIER := 0.05 # what fraction of star is in image "slice"?

# project vars
var size_exponent := 0.4 # smaller values reduce differences in object sizes
var min_button_width_proportion := 0.05 # as proportion of total (roughly)
# Triplets below for GUI_SMALL, GUI_MEDIUM & GUI_LARGE.
var widget_widths := [420.0, 560.0, 700.0] # within a pixel or so for values 300 - 700
var widget_min_heights := [277.0, 340.0, 407.0]
var over_planet_spacers := [18.0, 24.0, 30.0] # space above the largest planet
var min_body_sizes := [4.0, 5.0, 6.0] # Godot forces min size, but here in case that changes
var column_separations := [3, 4, 5]

# private
var _registrar: Registrar
var _selection_manager: SelectionManager # get from ancestor selection_manager

func _ready():
	_registrar = Global.program.Registrar
	Global.connect("system_tree_ready", self, "_on_system_tree_ready")
	Global.connect("about_to_free_procedural_nodes", self, "_clear")
	Global.connect("setting_changed", self, "_settings_listener")

func _on_system_tree_ready(_is_loaded_game: bool) -> void:
	var gui_size: int = Global.settings.gui_size
	_build(gui_size)

func _clear() -> void: # on exit or game load
	_selection_manager = null
	for child in get_children():
		child.queue_free()

func _settings_listener(setting: String, value) -> void:
	match setting:
		"gui_size":
			if Global.state.is_system_built:
				_clear()
				_build(value)

func _build(gui_size: int) -> void:
	_selection_manager = GUIUtils.get_selection_manager(self)
	assert(_selection_manager)
	var separation: int = column_separations[gui_size]
	set("custom_constants/separation", separation)
	rect_min_size.y = widget_min_heights[gui_size]
	# calculate star "slice" relative size
	var star: Body = _registrar.top_bodies[0]
	var size := pow(star.properties.m_radius * STAR_SLICE_MULTIPLIER, size_exponent)
	var column_widths := [size] # index 1, 2,... will be planet/moon columns
	var total_width := size
	# count & calcultate planet relative sizes
	var planet_sizes := [0.0] # index 0 is not used
	var n_planets := 0
	for planet in star.satellites:
		if not planet.flags & IS_PLANET:
			continue
		n_planets += 1
		size = pow(planet.properties.m_radius, size_exponent)
		planet_sizes.append(size)
		column_widths.append(size)
		total_width += size
	var min_width := min_button_width_proportion * total_width
	for column in range(n_planets + 1):
		if column_widths[column] < min_width:
			total_width += min_width - column_widths[column]
			column_widths[column] = min_width
	# scale everything to fit specified widget width
	var scale: float = (widget_widths[gui_size] - (separation * n_planets)) / total_width
	var min_body_size: float = min_body_sizes[gui_size]
	var max_planet_size := 0.0
	for column in range(n_planets + 1):
		column_widths[column] = round(column_widths[column] * scale)
		if column == 0:
			continue
		planet_sizes[column] = round(planet_sizes[column] * scale)
		if planet_sizes[column] < min_body_size:
			planet_sizes[column] = min_body_size
		if max_planet_size < planet_sizes[column]:
			max_planet_size = planet_sizes[column]
	# build the system button tree
	# For the star "slice", column_widths[0] sets the button and image width.
	_add_nav_button(self, star, column_widths[0], true)
	# For each planet column, column_widths[column] sets the top Spacer width (and
	# therefore the column width) and planet_sizes[column] sets the planet image size.
	var column := 0
	for planet in star.satellites: # vertical box for each planet w/ its moons
		if not planet.flags & IS_PLANET:
			continue
		column += 1
		var planet_vbox := VBoxContainer.new()
		planet_vbox.set_anchors_and_margins_preset(PRESET_WIDE, PRESET_MODE_KEEP_SIZE, 0)
		add_child(planet_vbox)
		var spacer := Control.new()
		var spacer_height := round((max_planet_size - planet_sizes[column]) / 2.0 \
				+ over_planet_spacers[gui_size])
		spacer.rect_min_size = Vector2(column_widths[column], spacer_height)
		planet_vbox.add_child(spacer)
		_add_nav_button(planet_vbox, planet, planet_sizes[column], false)
		for moon in planet.satellites:
			if not moon.flags & IS_NAVIGATOR_MOON:
				continue
			size = round(pow(moon.properties.m_radius, size_exponent) * scale)
			if size < min_body_size:
				size = min_body_size
			_add_nav_button(planet_vbox, moon, size, false)

func _add_nav_button(box_container: BoxContainer, body: Body, image_size: float, is_star_slice: bool) -> void:
	var selection_item := _registrar.get_selection_for_body(body)
	var nav_button := NavButton.new(selection_item, _selection_manager, image_size, is_star_slice)
	box_container.add_child(nav_button)

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
		set("custom_fonts/font", Global.fonts.two_pt) # hack to allow smaller button height
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
