# navigation_panel.gd
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
# We have a mix of procedural and hard-coded generation here. TODO: make this
# fully procedural (from data tables). That's going to be hard!

extends DraggablePanel
class_name NavigationPanel
const SCENE := "res://ivoyager/gui_in_game/navigation_panel.tscn"

const DDPRINT := false
const SIZE_PROPORTIONS_EXPONENT := 0.4 # 1 is true; 0 is all same size

var _asteroid_buttons := {}
var _registrar: Registrar
var _points_manager: PointsManager
var _connected_camera: VoyagerCamera


func _on_ready() -> void:
	._on_ready()
	_registrar = Global.objects.Registrar
	_points_manager = Global.objects.PointsManager
	_asteroid_buttons.all_asteroids = $BottomVBox/AstGroupBox/AllAsteroids
	_asteroid_buttons.NE = $BottomVBox/AstGroupBox/NearEarth
	_asteroid_buttons.MC = $BottomVBox/AstGroupBox/MarsCros
	_asteroid_buttons.MB = $BottomVBox/AstGroupBox/MainBelt
	_asteroid_buttons.JT4 = $BottomVBox/AstGroupBox/Trojans/L4
	_asteroid_buttons.JT5 = $BottomVBox/AstGroupBox/Trojans/L5
	_asteroid_buttons.CE = $BottomVBox/AstGroupBox/Centaurs
	_asteroid_buttons.TN = $BottomVBox/AstGroupBox/TransNeptune
	Global.connect("system_tree_ready", self, "_build_navigation_tree")
	Global.connect("camera_ready", self, "_connect_camera")
	_connect_camera(get_viewport().get_camera())
	$PlanetsHBox.set_anchors_and_margins_preset(PRESET_WIDE, PRESET_MODE_KEEP_SIZE, 0)
	$CameraLock.toggle_mode = true
	$CameraLock.connect("toggled", self, "_toggle_camera_lock")
	$BottomVBox/BottomHBox/MainMenu.connect("pressed", Global, "emit_signal", ["open_main_menu_requested"])
	$BottomVBox/BottomHBox/Hotkeys.connect("pressed", Global, "emit_signal", ["hotkeys_requested"])
	for key in _asteroid_buttons:
		_asteroid_buttons[key].connect("toggled", self, "_select_asteroids", [key])
	_points_manager.connect("show_points_changed", self, "_update_asteroids_selected")
	
func _prepare_for_deletion() -> void:
	._prepare_for_deletion()
	Global.disconnect("system_tree_ready", self, "_build_navigation_tree")
	Global.disconnect("camera_ready", self, "_connect_camera")
	_disconnect_camera()
	_points_manager.disconnect("show_points_changed", self, "_update_asteroids_selected")

func _connect_camera(camera: Camera) -> void:
	if _connected_camera != camera:
		_disconnect_camera()
		_connected_camera = camera
		_connected_camera.connect("camera_lock_changed", self, "_update_camera_lock")

func _disconnect_camera() -> void:
	if _connected_camera:
		_connected_camera.disconnect("camera_lock_changed", self, "_update_camera_lock")
		_connected_camera = null

func _select_asteroids(pressed: bool, group_or_category: String) -> void:
	# only select one group or all groups or none
	if group_or_category == "all_asteroids":
		_points_manager.show_points("all_asteroids", pressed)
	else:
		var is_show: bool = pressed or _asteroid_buttons.all_asteroids.pressed
		if is_show:
			for key in _asteroid_buttons:
				_points_manager.show_points(key, key == group_or_category)
		else:
			_points_manager.show_points(group_or_category, false)
		
func _update_asteroids_selected(group_or_category: String, is_show: bool) -> void:
	_asteroid_buttons[group_or_category].pressed = is_show
	if !is_show:
		_asteroid_buttons.all_asteroids.pressed = false
	
func _update_camera_lock(is_locked: bool) -> void:
	$CameraLock.pressed = is_locked
	
func _toggle_camera_lock(button_pressed: bool) -> void:
	_connected_camera.change_camera_lock(button_pressed)

func _build_navigation_tree(_is_loaded_game: bool) -> void:
	assert(DDPRINT and prints("_build_navigation_tree") or true)
	var selection_manager: SelectionManager = get_parent().selection_manager
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
	var expansion := rect_min_size.x - (star.satellites.size() * 5)
	var biggest_image_size := floor(biggest_size * expansion / total_size)
	total_size *= 1.09 # TODO: something less ad hoc for procedural
	# build the system button tree
	var image_size := floor(pow(star.m_radius / 20.0, SIZE_PROPORTIONS_EXPONENT) * expansion / total_size)
	_add_nav_button($PlanetsHBox, star, selection_manager, image_size, true)
	for planet in star.satellites: # vertical box for each planet w/ its moons
		var planet_vbox := VBoxContainer.new()
		planet_vbox.set_anchors_and_margins_preset(PRESET_WIDE, PRESET_MODE_KEEP_SIZE, 0)
		$PlanetsHBox.add_child(planet_vbox)
		image_size = floor(pow(planet.m_radius, SIZE_PROPORTIONS_EXPONENT) * expansion / total_size)
		var v_spacer_size := floor((biggest_image_size - image_size) / 2) + 13 # plus adds space above planets
		var spacer := Control.new()
		spacer.rect_min_size = Vector2(30, v_spacer_size)
		planet_vbox.add_child(spacer)
		_add_nav_button(planet_vbox, planet, selection_manager, image_size, false)
		for moon in planet.satellites:
			if moon.is_minor_moon:
				continue
			image_size = floor(pow(moon.m_radius, SIZE_PROPORTIONS_EXPONENT) * expansion / total_size)
			_add_nav_button(planet_vbox, moon, selection_manager, image_size, false)

func _add_nav_button(control: Control, body: Body, selection_manager: SelectionManager, image_size: float,
		is_star_slice: bool) -> void:
	var selection_item := _registrar.get_selection_for_body(body)
	var nav_button := NavButton.new(selection_item, selection_manager, image_size, is_star_slice)
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
