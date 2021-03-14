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
	AS_IS = 10000,
	TABLE_ROW,
	ENUM,
	OBJECT_SPECIAL,
}

# project vars
var enable_wiki: bool = Global.enable_wiki # can override false if needed
var labels_stretch_ratio := 0.6
var values_stretch_ratio := 0.4


var section_headers := ["LABEL_ORBITAL_CHARACTERISTICS", "LABEL_PHYSICAL_CHARACTERISTICS",
	"LABEL_ATMOSPHERE", "LABEL_ATMOSPHERE_BY_VOLUME", "LABEL_TRACE_ATMOSPHERE_BY_VOLUME",
	"LABEL_PHOTOSPHERE_BY_WEIGHT"]
var subsection_of := [-1, -1, -1, 2, 2, -1]
var section_open := [true, true, true, true, true, true]

var section_data := [ # one array element per header
	# In each section array, we have an array for each data line containing:
	# [0] path to property or method [1] display label [2-4] type-specific (see code)

	# Orbital Characteristics
	[
	["body/orbit/get_periapsis", "LABEL_PERIAPSIS", QtyTxtConverter.LENGTH_KM_AU, "", 4],
	["body/orbit/get_apoapsis", "LABEL_APOAPSIS", QtyTxtConverter.LENGTH_KM_AU, "", 4],
	["body/orbit/get_semimajor_axis", "LABEL_SEMI_MAJOR_AXIS", QtyTxtConverter.LENGTH_KM_AU, "", 4],
	["body/orbit/get_eccentricity", "LABEL_ECCENTRICITY", AS_IS],
	["body/orbit/get_orbital_perioid", "LABEL_ORBITAL_PERIOD", QtyTxtConverter.TIME_D_Y, "", 4],
	["body/orbit/get_average_orbital_speed", "LABEL_AVERAGE_ORBITAL_SPEED",
			QtyTxtConverter.VELOCITY_MPS_KMPS, "", 4],
	["body/orbit/get_inclination_to_ecliptic", "LABEL_INCLINATION_TO_ECLIPTIC",
			QtyTxtConverter.UNIT, "deg", 2, QtyTxtConverter.NUM_DECIMAL_PL],
	["body/get_orbit_inclination_to_equator", "LABEL_INCLINATION_TO_EQUATOR",
			QtyTxtConverter.UNIT, "deg", 2, QtyTxtConverter.NUM_DECIMAL_PL],
	["n_stars", "LABEL_STARS", AS_IS],
	["n_planets", "LABEL_PLANETS", AS_IS],
	["n_dwarf_planets", "LABEL_DWARF_PLANETS", AS_IS],
	["n_moons", "LABEL_MOONS", AS_IS],
	["n_asteroids", "LABEL_ASTEROIDS", AS_IS],
	["n_comets", "LABEL_COMETS", AS_IS],
	],
	# Physical Characteristics
	[
	["body/class_type", "LABEL_CLASSIFICATION", TABLE_ROW, "classes"],
	["body/m_radius", "LABEL_MEAN_RADIUS", QtyTxtConverter.UNIT, "km"],
	["body/body_characteristics/e_radius", "LABEL_EQUATORIAL_RADIUS", QtyTxtConverter.UNIT, "km"],
	["body/body_characteristics/p_radius", "LABEL_POLAR_RADIUS", QtyTxtConverter.UNIT, "km"],
	["body/body_characteristics/mass", "LABEL_MASS", QtyTxtConverter.MASS_G_KG],
	["body/body_characteristics/hydrostatic_equilibrium", "LABEL_HYDROSTATIC_EQUILIBRIUM", ENUM, "ConfidenceType"],
	["body/body_characteristics/surface_gravity", "LABEL_SURFACE_GRAVITY", QtyTxtConverter.UNIT, "_g"],
	["body/body_characteristics/esc_vel", "LABEL_ESCAPE_VELOCITY", QtyTxtConverter.VELOCITY_MPS_KMPS],
	["body/body_characteristics/mean_density", "LABEL_MEAN_DENSITY", QtyTxtConverter.UNIT, "g/cm^3"],
	["body/body_characteristics/albedo", "LABEL_ALBEDO", QtyTxtConverter.NUMBER],
	["body/body_characteristics/min_t", "LABEL_SURFACE_TEMP_MIN", QtyTxtConverter.UNIT, "degC"],
	["body/body_characteristics/surf_t", "LABEL_SURFACE_TEMP_MEAN", QtyTxtConverter.UNIT, "degC"],
	["body/body_characteristics/max_t", "LABEL_SURFACE_TEMP_MAX", QtyTxtConverter.UNIT, "degC"],
	],
	# Atmosphere
	[
	["body/body_characteristics/surf_pres", "LABEL_SURFACE_PRESSURE", QtyTxtConverter.PREFIXED_UNIT, "bar"],
	["body/body_characteristics/trace_pres", "LABEL_TRACE_PRESSURE", QtyTxtConverter.PREFIXED_UNIT, "Pa"],
	["body/body_characteristics/trace_pres_high", "LABEL_TRACE_PRESSURE_HIGH", QtyTxtConverter.PREFIXED_UNIT, "Pa"],
	["body/body_characteristics/trace_pres_low", "LABEL_TRACE_PRESSURE_LOW", QtyTxtConverter.PREFIXED_UNIT, "Pa"],
	["body/body_characteristics/one_bar_t", "LABEL_TEMP_AT_1_BAR", QtyTxtConverter.UNIT, "degC"],
	["body/body_characteristics/half_bar_t", "LABEL_TEMP_AT_HALF_BAR", QtyTxtConverter.UNIT, "degC"],
	["body/body_characteristics/tenth_bar_t", "LABEL_TEMP_AT_10TH_BAR", QtyTxtConverter.UNIT, "degC"],
	],
	# Atmosphere composition
	[
	["body/body_characteristics/compositions/atmosphere", "", OBJECT_SPECIAL],
	],
	# Trace atmosphere composition
	[
	["body/body_characteristics/compositions/trace_atmosphere", "", OBJECT_SPECIAL],
	],
	# Photosphere composition
	[
	["body/body_characteristics/compositions/photosphere", "", OBJECT_SPECIAL],
	],
]

var label_is_wiki_link := ["body/body_characteristics/hydrostatic_equilibrium"]
var value_is_wiki_link := ["body/class_type"]
var body_flags_test := {
	"body/m_radius" : BodyFlags.DISPLAY_M_RADIUS,
	"body/body_characteristics/hydrostatic_equilibrium" : BodyFlags.IS_MOON,
}

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
	var grid: GridContainer = _grids[section]
	_clear_grid(grid)
	var is_open: bool = section_open[section]
	var header_button: Button = _header_buttons[section]
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
	var has_content := false
	var n_data: int = section_data[section].size()
	var data_index := 0
	while data_index < n_data:
		var row_info := _get_row_info(section, data_index, prespace)
		if row_info:
			if !is_open: # keep header visible but don't add content
				if header_button:
					header_button.show()
				grid.hide()
				return
			_add_row(grid, row_info)
			has_content = true
		data_index += 1
	if !has_content: # no content - hide header
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
	var path: String = line_data[0]
	
	# flags exclusion
	var body_flags: int = body_flags_test.get(path, 0)
	if body_flags:
		if !_body or not _body.flags & body_flags:
			return NULL_ARRAY
	# get value from SelectionItem or nested object
	var value = GDUtils.get_path_result(_selection_item, path)
	if value == null:
		return NULL_ARRAY # doesn't exist
	# get value text (& possibly wiki key)
	
	var enum_value: int = line_data[2]
	
	var value_txt: String
	var wiki_key: String
	match typeof(value):
		TYPE_INT:
			var key: String
			if value == -9999:
				value_txt = "?"
			elif value == -1:
				pass # don't display
			elif enum_value == TABLE_ROW:
				var table_name: String = line_data[3]
				key = _table_reader.get_row_name(table_name, value)
				value_txt = tr(key)
			elif enum_value == ENUM:
				var enum_name: String = line_data[3]
				var enum_dict: Dictionary = _enums.get(enum_name)
				var enum_keys: Array = enum_dict.keys()
				key = enum_keys[value]
				value_txt = tr(key)
			else:
				value_txt = str(value)
			if enable_wiki and key and value_is_wiki_link.has(path):
				wiki_key = key
		TYPE_REAL:
			if is_inf(value):
				value_txt = "?"
			elif is_nan(value):
				pass # don't display
			elif enum_value == AS_IS:
				value_txt = str(value)
			else: # call with args to QtyTxtConverter.number_option()
				# expects elements 2, 3, 4
				var data_size: int = line_data.size()
				var unit: String = line_data[3] if data_size > 3 else ""
				var sig_digits: int = line_data[4] if data_size > 4 else -1
				var num_type: int = line_data[5] if data_size > 5 else QtyTxtConverter.NUM_DYNAMIC
				value_txt = _qty_txt_converter.number_option(value, enum_value, unit, sig_digits, num_type)
		TYPE_STRING:
			value_txt = tr(value)
			if enable_wiki and value_is_wiki_link.has(path):
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
	if label_is_wiki_link.has(path) and _wiki_titles.has(label_key): # label is wiki link
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
		var label_cell := _get_rtlabel(false)
		label_cell.bbcode_text = label_txt
		grid.add_child(label_cell)
	else:
		var label_cell := _get_label(false)
		label_cell.text = label_txt
		grid.add_child(label_cell)
	if value_link:
		var value_cell := _get_rtlabel(true)
		value_cell.bbcode_text = value_txt
		grid.add_child(value_cell)
	else:
		var value_cell := _get_label(true)
		value_cell.text = value_txt
		grid.add_child(value_cell)

func _clear_grid(grid: GridContainer) -> void:
	if grid.get_child_count() == 0:
		return
	var children := grid.get_children()
	children.invert()
	for child in children:
		grid.remove_child(child)
		if child is Label:
			_recycled_labels.append(child)
		else:
			_recycled_rtlabels.append(child)

func _get_label(is_value: bool) -> Label:
	var label: Label
	if _recycled_labels:
		label = _recycled_labels.pop_back()
	else:
		label = Label.new()
		label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = values_stretch_ratio if is_value else labels_stretch_ratio
	return label

func _get_rtlabel(is_value: bool) -> RichTextLabel:
	var rtlabel: RichTextLabel
	if _recycled_rtlabels:
		rtlabel = _recycled_rtlabels.pop_back()
	else:
		rtlabel = RichTextLabel.new()
		rtlabel.connect("meta_clicked", self, "_on_meta_clicked")
		rtlabel.bbcode_enabled = true
		rtlabel.fit_content_height = true
		rtlabel.scroll_active = false
		rtlabel.size_flags_horizontal = SIZE_EXPAND_FILL
	rtlabel.size_flags_stretch_ratio = values_stretch_ratio if is_value else labels_stretch_ratio
	return rtlabel

func _on_meta_clicked(meta: String) -> void:
	var wiki_key: String = _meta_lookup[meta]
	var wiki_title: String = _wiki_titles[wiki_key]
	var url: String = "https://en.wikipedia.org/wiki/" + wiki_title
	OS.shell_open(url)
