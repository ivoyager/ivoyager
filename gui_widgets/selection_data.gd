# selection_data.gd
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
# GUI widget. Requires Control ancestor with member "selection_manager".
#
# Typed values interpreted as n/a; widget skips row and doesn't display:
#   NAN
#   -1
#   ""
#
# Typed values interpreted as unknown; widget displays as "?":
#   INF or -INF
#   -9999
#
# For most applicatios, you'll want to put this widget in a ScrollContainer.
#
# TODO: tooltips.


extends VBoxContainer

const BodyFlags := Enums.BodyFlags
const NULL_ARRAY := []

enum {
	TABLE_ROW,
	ENUM
}

# project vars
var enable_wiki: bool = Global.enable_wiki # can override false if needed

var section_headers := ["", "LABEL_ORBITAL_CHARACTERISTICS", "LABEL_PHYSICAL_CHARACTERISTICS",
	"LABEL_ATMOSPHERE", "LABEL_ATMOSPHERE_BY_VOLUME", "LABEL_PHOTOSPHERE_BY_WEIGHT"]
var subsection_of := [-1, -1, -1, -1, 3, -1]
var section_searches := [ # one array element per header
	# object paths relative to SelectionItem 
	["body"],
	["body/orbit", ""],
	["body/body_characteristics"],
	["body/body_characteristics"],
	["body/body_characteristics/compositions"],
	["body/body_characteristics/compositions"],
]

var section_data := [ # one array element per header
	# In each section array, we have an array for each data line containing:
	# [0] property or method [1] display label [2-4] type-specific (see code)
	# [5] flags test (show) [6] flags test (is approximate value)
	# [7] label as wiki link [8] value as wiki link
	#
	# top (no header)
	[
	["class_type", "LABEL_CLASSIFICATION", TABLE_ROW, "classes", null, null, null, false, true],
	],
	# Orbital Characteristics
	[
	["get_periapsis", "LABEL_PERIAPSIS", QtyTxtConverter.LENGTH_KM_AU, "", 4],
	["get_apoapsis", "LABEL_APOAPSIS", QtyTxtConverter.LENGTH_KM_AU, "", 4],
	["get_orbital_perioid", "LABEL_ORBITAL_PERIOD", QtyTxtConverter.TIME_D_Y, "", 4],
	["get_average_orbital_speed", "LABEL_AVERAGE_ORBITAL_SPEED", QtyTxtConverter.VELOCITY_MPS_KMPS, "", 4],
	["n_stars", "LABEL_STARS"],
	["n_planets", "LABEL_PLANETS"],
	["n_dwarf_planets", "LABEL_DWARF_PLANETS"],
	["n_moons", "LABEL_MOONS"],
	["n_asteroids", "LABEL_ASTEROIDS"],
	["n_comets", "LABEL_COMETS"],
	],
	# Physical Characteristics
	[
	["m_radius", "LABEL_MEAN_RADIUS", QtyTxtConverter.UNIT, "km", -1, BodyFlags.DISPLAY_M_RADIUS],
	["e_radius", "LABEL_EQUATORIAL_RADIUS", QtyTxtConverter.UNIT, "km"],
	["p_radius", "LABEL_POLAR_RADIUS", QtyTxtConverter.UNIT, "km"],
	["mass", "LABEL_MASS", QtyTxtConverter.MASS_G_KG],
	["hydrostatic_equilibrium", "LABEL_HYDROSTATIC_EQUILIBRIUM", ENUM, "ConfidenceType", null,
			BodyFlags.IS_MOON, null, true],
	["surface_gravity", "LABEL_SURFACE_GRAVITY", QtyTxtConverter.UNIT, "_g"],
	["esc_vel", "LABEL_ESCAPE_VELOCITY", QtyTxtConverter.VELOCITY_MPS_KMPS],
	["mean_density", "LABEL_MEAN_DENSITY", QtyTxtConverter.UNIT, "g/cm^3"],
	["albedo", "LABEL_ALBEDO", QtyTxtConverter.NUMBER],
	["surf_t", "LABEL_SURFACE_TEMP", QtyTxtConverter.UNIT, "degC"],
	["min_t", "LABEL_MIN_TEMP", QtyTxtConverter.UNIT, "degC"],
	["max_t", "LABEL_MAX_TEMP", QtyTxtConverter.UNIT, "degC"],
	],
	# Atmosphere
	[
	["surf_pres", "LABEL_SURFACE_PRESSURE", QtyTxtConverter.PREFIXED_UNIT, "bar"],
	["one_bar_t", "LABEL_ONE_BAR_TEMP", QtyTxtConverter.UNIT, "degC"],
	["half_bar_t", "LABEL_HALF_BAR_TEMP", QtyTxtConverter.UNIT, "degC"],
	["tenth_bar_t", "LABEL_TENTH_BAR_TEMP", QtyTxtConverter.UNIT, "degC"],
	],
	# Atmosphere composition
	[
	["atmosphere"],
	],
	# Photosphere composition
	[
	["photosphere"],
	],
]
var section_open := [true, true, true, true, true, true]

onready var _qty_txt_converter: QtyTxtConverter = Global.program.QtyTxtConverter
onready var _table_reader: TableReader = Global.program.TableReader
var _enums: Script = Global.enums
var _wiki_titles: Dictionary = Global.wiki_titles
var _selection_manager: SelectionManager
var _header_buttons := []
var _grids := []
var _meta_lookup := {}
var _recycled_labels := []
var _recycled_rtlabels := []

var _selection_item: SelectionItem
var _body: Body

func _ready():
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator")
	Global.connect("about_to_free_procedural_nodes", self, "_clear")
	Global.connect("about_to_quit", self, "_clear")

func _clear() -> void:
	_header_buttons.clear()
	_grids.clear()
	_meta_lookup.clear()
	while _recycled_labels:
		_recycled_labels.pop_back().queue_free()
	while _recycled_rtlabels:
		_recycled_rtlabels.pop_back().queue_free()
	for child in get_children():
		child.queue_free()

func _on_about_to_start_simulator(_is_loaded_game: bool) -> void:
	assert(section_headers.size() == section_searches.size())
	assert(section_headers.size() == subsection_of.size())
	assert(section_headers.size() == section_data.size())
	assert(section_headers.size() == section_open.size())
	_selection_manager = GUIUtils.get_selection_manager(self)
	_selection_manager.connect("selection_changed", self, "_on_selection_changed")
	var n_sections := section_headers.size()
	var section := 0
	while section < n_sections:
		var header: String = section_headers[section]
		if header:
			var header_button := Button.new()
			var prespace := "" if subsection_of[section] == -1 else "   "
			if section_open[section]:
				header_button.text = prespace + "v " + tr(header) # down pointer
			else:
				header_button.text = prespace + "> " + tr(header) # right pointer
			header_button.flat = true
			header_button.size_flags_horizontal = 0
			header_button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
			header_button.connect("pressed", self, "_process_section", [section, true])
			_header_buttons.append(header_button)
			add_child(header_button)
		else:
			_header_buttons.append(null)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = SIZE_EXPAND_FILL
		_grids.append(grid)
		add_child(grid)
		section += 1
	_on_selection_changed()

func _on_selection_changed() -> void:
	_selection_item = _selection_manager.selection_item
	if !_selection_item:
		return
	if _selection_manager.is_body():
		_body = _selection_manager.get_body()
	else:
		_body = null
	var n_sections := section_headers.size()
	var section := 0
	while section < n_sections:
		_process_section(section, false)
		section += 1

func _process_section(section: int, toggle: bool) -> void:
	var is_open: bool = section_open[section]
	var header_button: Button = _header_buttons[section]
	var grid: GridContainer = _grids[section]
	var supersection: int = subsection_of[section]
	if supersection != -1:
		if !section_open[supersection]:
			if header_button:
				header_button.hide()
			grid.hide()
			return
	var prespace := "" if subsection_of[section] == -1 else "   "
	if toggle:
		is_open = !is_open
		section_open[section] = is_open
		var header: String = section_headers[section]
		if section_open[section]:
			header_button.text = prespace + "v " + tr(header) # down pointer
		else:
			header_button.text = prespace + "> " + tr(header) # right pointer
		var n_sections := section_headers.size()
		var subsection := 0
		while subsection < n_sections:
			if section == subsection_of[subsection]:
				_process_section(subsection, false)
			subsection += 1
	_clear_grid(grid)
	var has_content := false
	var n_data: int = section_data[section].size()
	var data_index := 0
	while data_index < n_data:
		var row_info := _get_row_info(section, data_index, prespace)
		if row_info:
			if !is_open: # closed but has content - keep header visible
				if header_button:
					header_button.show()
				grid.hide()
				return
			_add_row(grid, row_info)
			has_content = true
		data_index += 1
	if !has_content: # no content - hide header and grid
		if header_button:
			header_button.hide()
		grid.hide()
		return
	if header_button:
		header_button.show()
	grid.show()

func _get_row_info(section: int, data_index: int, prespace: String) -> Array:
	# Returns [label_txt, value_txt, is_label_link, is_value_link], or empty array if n/a (skip)
	var line_data: Array = section_data[section][data_index]
	# flags exclusion
	var data_size: int = line_data.size()
	if data_size > 5 and line_data[5]:
		if !_body or not _body.flags & line_data[5]:
			return NULL_ARRAY
	# get value from SelectionItem or nested object
	var value # untyped
	var property_or_method: String = line_data[0]
	var search: Array = section_searches[section]
	for search_str in search:
		var target = GDUtils.get_deep(_selection_item, search_str) # Object or dict
		if target:
			value = _get_property_or_method_result(target, property_or_method)
			if value != null:
				break
	if value == null:
		return NULL_ARRAY # doesn't exist
	# get value text (& possibly wiki key)
	var value_txt: String
	var wiki_key: String
	match typeof(value):
		TYPE_INT:
			if value == -9999:
				value_txt = "?"
			elif value == -1:
				pass
			elif data_size > 2 and line_data[2] != null:
				var key: String
				match line_data[2]:
					TABLE_ROW:
						var table_name: String = line_data[3]
						key = _table_reader.get_row_name(table_name, value)
						value_txt = tr(key)
					ENUM:
						var enum_name: String = line_data[3]
						var enum_dict: Dictionary = _enums.get(enum_name)
						var enum_keys: Array = enum_dict.keys()
						key = enum_keys[value]
						value_txt = tr(key)
				if enable_wiki and key and data_size > 8 and line_data[8]:
					wiki_key = key
			else:
				value_txt = str(value)
		TYPE_REAL:
			if is_inf(value):
				value_txt = "?"
			elif is_nan(value):
				pass
			elif data_size > 2 and line_data[2] != null:
				# expects elements 2, 3, 4
				var option_type: int = line_data[2]
				var unit: String = line_data[3] if data_size > 3 and line_data[3] != null else ""
				var sig_digits: int = line_data[4] if data_size > 4 and line_data[4] != null else -1
				value_txt = _qty_txt_converter.number_option(value, option_type, unit, sig_digits)
			else:
				value_txt = str(value)
		TYPE_STRING:
			value_txt = tr(value)
			if enable_wiki and data_size > 8 and line_data[8]:
				wiki_key = value # may be used as wiki link (if valid key)
		TYPE_OBJECT:
			if value is Composition:
				var display: Array = value.get_display(prespace)
				var components: String = display[0]
				var amounts: String = display[1]
				return [components, amounts, false, false]
	if !value_txt:
		return NULL_ARRAY # n/a
	# get label text
	var label_key: String = line_data[1]
	if _body:
		if label_key == "LABEL_PERIAPSIS":
			var parent := _body.get_parent() as Body
			if parent:
				if parent.name == "STAR_SUN":
					label_key = "LABEL_PERIHELION"
				elif parent.name == "PLANET_EARTH":
					label_key = "LABEL_PERIGEE"
		elif label_key == "LABEL_APOAPSIS":
			var parent := _body.get_parent() as Body
			if parent:
				if parent.name == "STAR_SUN":
					label_key = "LABEL_APHELION"
				elif parent.name == "PLANET_EARTH":
					label_key = "LABEL_APOGEE"
	var label_txt := tr(label_key)
	if !enable_wiki:
		return [prespace + label_txt, value_txt, false, false]
	# wiki links
	var label_link := false
	var value_link := false
	if data_size > 7 and line_data[7] and _wiki_titles.has(label_key): # label is wiki link
		_meta_lookup[label_txt] = label_key
		label_txt = "[url]" + label_txt + "[/url]"
		label_link = true
	if wiki_key and _wiki_titles.has(wiki_key): # value is wiki link
		_meta_lookup[value_txt] = wiki_key
		value_txt = "[url]" + value_txt + "[/url]"
		value_link = true
	return [prespace + label_txt, value_txt, label_link, value_link]

func _add_row(grid: GridContainer, row_info: Array) -> void:
	var label_txt: String = row_info[0]
	var value_txt: String = row_info[1]
	var label_link: bool = row_info[2]
	var value_link: bool = row_info[3]
	if label_link:
		var label_cell := _get_rtlabel()
		label_cell.bbcode_text = label_txt
		grid.add_child(label_cell)
	else:
		var label_cell := _get_label()
		label_cell.text = label_txt
		grid.add_child(label_cell)
	if value_link:
		var value_cell := _get_rtlabel()
		value_cell.bbcode_text = value_txt
		grid.add_child(value_cell)
	else:
		var value_cell := _get_label()
		value_cell.text = value_txt
		grid.add_child(value_cell)

func _get_property_or_method_result(target, key: String): # untyped
	if target is Object and target.has_method(key):
		return target.call(key)
	return target.get(key) # property value or null

func _clear_grid(grid: GridContainer) -> void:
	var children := grid.get_children()
	children.invert()
	for child in children:
		grid.remove_child(child)
		if child is Label:
			_recycled_labels.append(child)
		else:
			_recycled_rtlabels.append(child)

func _get_label() -> Label:
	if _recycled_labels:
		return _recycled_labels.pop_back()
	var label := Label.new()
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	return label

func _get_rtlabel() -> RichTextLabel:
	if _recycled_rtlabels:
		return _recycled_rtlabels.pop_back()
	var rtlabel := RichTextLabel.new()
	rtlabel.bbcode_enabled = true
	rtlabel.fit_content_height = true
	rtlabel.scroll_active = false
	rtlabel.size_flags_horizontal = SIZE_EXPAND_FILL
	rtlabel.connect("meta_clicked", self, "_on_meta_clicked")
	return rtlabel

func _on_meta_clicked(meta: String) -> void:
	var wiki_key: String = _meta_lookup[meta]
	var wiki_title: String = _wiki_titles[wiki_key]
	var url: String = "https://en.wikipedia.org/wiki/" + wiki_title
	OS.shell_open(url)
