# planet_moon_buttons.gd
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
# GUI widget. Builds itself from an existing solar system!
#
# To use in conjuction with SunSliceButton, make both SIZE_FILL_EXPAND and give
# strech ratios: 1.0 (SunSliceButton) and 10.0 (this widget or container that
# contains this widget).
#

extends HBoxContainer


const IS_PLANET := Enums.BodyFlags.IS_TRUE_PLANET | Enums.BodyFlags.IS_DWARF_PLANET
const IS_NAVIGATOR_MOON := Enums.BodyFlags.IS_NAVIGATOR_MOON
const STAR_SLICE_MULTIPLIER := 0.05 # what fraction of star is in image "slice"?
const INIT_WIDTH := 560.0

# project vars
var grab_focus := true # if no GUI has focus, grabs currently selected on ui_ actions
var size_exponent := 0.4 # smaller values reduce differences in object sizes
var min_button_width_proportion := 0.05 # as proportion of total (roughly)
var min_body_size_ratio := 0.008929 # proportion of widget width, rounded
var column_separation_ratio := 0.007143 # proportion of widget width, rounded

# private
onready var _body_registry: BodyRegistry = Global.program.BodyRegistry
onready var _mouse_only_gui_nav: bool = Global.settings.mouse_only_gui_nav
var _selection_manager: SelectionManager # get from ancestor selection_manager
var _currently_selected: Button
var _resize_control_multipliers := {}

func _ready():
	Global.connect("about_to_start_simulator", self, "_build")
	Global.connect("about_to_free_procedural_nodes", self, "_clear")
	Global.connect("setting_changed", self, "_settings_listener")
	connect("resized", self, "_resize")

func _clear() -> void:
	_selection_manager = null
	_currently_selected = null
	_resize_control_multipliers.clear()
	for child in get_children():
		child.queue_free()

func _resize() -> void:
	# Column widths are mostly controled by size_flags_stretch_ratio. However,
	# some planets are smaller than the minimum button width so we can't depend
	# on that for image sizing. We also need to resize the vertical spacer
	# above planets.
	# WARNING: Shrinking by user mouse drag works, but I think it is a little
	# iffy. We have a few images already smaller than their bounding buttons
	# (Ceres & Pluto, depending on min_button_width_proportion) and this is why
	# it is possible to shrink the widget before image resizing.
	var widget_width := rect_size.x
	var column_separation := int(widget_width * column_separation_ratio + 0.5)
	set("custom_constants/separation", column_separation)
	for key in _resize_control_multipliers:
		var control := key as Control
		var multipliers: Vector2 = _resize_control_multipliers[control]
		control.rect_min_size = multipliers * widget_width

func _settings_resize() -> void:
	# It's a hack, but but we hide our content so the widget can shrink with
	# its bounding container. The _resize() function then resizes images to fit
	# the widget.
	for child in get_children():
		child.hide()
	yield(get_tree(), "idle_frame")
	_resize()
	for child in get_children():
		child.show()

func _build(_is_new_game: bool) -> void:
	_clear()
	_selection_manager = GUIUtils.get_selection_manager(self)
	assert(_selection_manager)
	var column_separation := int(INIT_WIDTH * column_separation_ratio + 0.5)
	set("custom_constants/separation", column_separation)
	# calculate star "slice" relative size
	var star: Body = _body_registry.top_bodies[0]
	var min_body_size := round(INIT_WIDTH * min_body_size_ratio)
	# count & calcultate planet relative sizes
	var size := 0.0
	var total_width := 0.0
	var column_widths := [] # index 0, 1, 2,... will be planet/moon columns
	var planet_sizes := []
	var n_planets := 0
	for planet in star.satellites:
		if not planet.flags & IS_PLANET:
			continue
		size = pow(planet.body_properties.m_radius, size_exponent)
		planet_sizes.append(size)
		column_widths.append(size)
		total_width += size
		n_planets += 1
	var min_width := min_button_width_proportion * total_width
	for column in range(n_planets):
		if column_widths[column] < min_width:
			total_width += min_width - column_widths[column]
			column_widths[column] = min_width
	# scale everything to fit specified widget width
	var scale: float = (INIT_WIDTH - (column_separation * n_planets)) / total_width
	var max_planet_size := 0.0
	for column in range(n_planets):
		column_widths[column] = round(column_widths[column] * scale)
		planet_sizes[column] = round(planet_sizes[column] * scale)
		if planet_sizes[column] < min_body_size:
			planet_sizes[column] = min_body_size
		if max_planet_size < planet_sizes[column]:
			max_planet_size = planet_sizes[column]
	# build the system button tree
	var column := 0
	for planet in star.satellites: # vertical box for each planet w/ its moons
		if not planet.flags & IS_PLANET:
			continue
		# For each planet column, column_widths[column] sets the top Spacer
		# width (and therefore the column width) and planet_sizes[column] sets
		# the planet image size (which is sometimes smaller).
		var planet_vbox := VBoxContainer.new()
		planet_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		planet_vbox.size_flags_stretch_ratio = column_widths[column]
		add_child(planet_vbox)
		var spacer := Control.new()
		var spacer_height := round((max_planet_size - planet_sizes[column]) / 2.0)
		spacer.rect_min_size.y = spacer_height
		spacer.mouse_filter = MOUSE_FILTER_IGNORE
		_resize_control_multipliers[spacer] = Vector2(0.0, spacer_height / INIT_WIDTH)
		planet_vbox.add_child(spacer)
		_add_nav_button(planet_vbox, planet, planet_sizes[column])
		for moon in planet.satellites:
			if not moon.flags & IS_NAVIGATOR_MOON:
				continue
			size = round(pow(moon.body_properties.m_radius, size_exponent) * scale)
			if size < min_body_size:
				size = min_body_size
			_add_nav_button(planet_vbox, moon, size)
		column += 1

func _add_nav_button(box_container: BoxContainer, body: Body, image_size: float) -> void:
	var selection_item := _body_registry.get_selection_for_body(body)
	var button := NavButton.new(selection_item, _selection_manager, image_size)
	button.connect("selected", self, "_change_selection", [button])
	button.size_flags_horizontal = SIZE_FILL
	box_container.add_child(button)
	var size_multiplier := image_size / INIT_WIDTH
	_resize_control_multipliers[button] = Vector2(size_multiplier, size_multiplier)

func _change_selection(selected: Button) -> void:
	_currently_selected = selected
	if !_mouse_only_gui_nav and !get_focus_owner():
		if selected.focus_mode != FOCUS_NONE:
			selected.grab_focus()

func _settings_listener(setting: String, value) -> void:
	match setting:
		"gui_size":
			if Global.state.is_system_built:
				_settings_resize()
		"mouse_only_gui_nav":
			_mouse_only_gui_nav = value
			if !_mouse_only_gui_nav and _currently_selected:
				yield(get_tree(), "idle_frame") # wait for _mouse_only_gui_nav.gd
				if _currently_selected.focus_mode != FOCUS_NONE:
					_currently_selected.grab_focus()

# ****************************** INNER CLASS **********************************

class NavButton extends Button:
	
	signal selected()
	
	var _has_mouse := false
	var _selection_item: SelectionItem
	var _selection_manager: SelectionManager
	
	func _init(selection_item: SelectionItem, selection_manager: SelectionManager,
			image_size: float) -> void:
		_selection_item = selection_item
		_selection_manager = selection_manager
		toggle_mode = true
		hint_tooltip = selection_item.name
		set("custom_fonts/font", Global.fonts.two_pt) # hack to allow smaller button height
		rect_min_size = Vector2(image_size, image_size)
		flat = true
		focus_mode = FOCUS_ALL
		var texture_box := TextureRect.new()
		texture_box.set_anchors_and_margins_preset(PRESET_WIDE, PRESET_MODE_KEEP_SIZE, 0)
		texture_box.expand = true
		texture_box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_box.texture = selection_item.texture_2d
		texture_box.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(texture_box)
		connect("mouse_entered", self, "_on_mouse_entered")
		connect("mouse_exited", self, "_on_mouse_exited")

	func _ready():
		Global.connect("update_gui_needed", self, "_update_selection")
		_selection_manager.connect("selection_changed", self, "_update_selection")
		action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		set_default_cursor_shape(CURSOR_POINTING_HAND)

	func _pressed() -> void:
		_selection_manager.select(_selection_item)

	func _update_selection() -> void:
		var is_selected := _selection_manager.selection_item == _selection_item
		pressed = is_selected
		if is_selected:
			emit_signal("selected")
		flat = !is_selected and !_has_mouse

	func _on_mouse_entered() -> void:
		_has_mouse = true
		flat = false

	func _on_mouse_exited() -> void:
		_has_mouse = false
		flat = !pressed
