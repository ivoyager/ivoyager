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
const NO_ARGS := []

enum { # data_type
	AS_IS,
	QTY_TXT,
	QTY_TXT_W_PRECISION,
	TABLE_ROW,
	ENUM,
	OBJECT_LABELS_VALUES,
}

# project vars
var test_wiki_labels: bool = Global.enable_wiki # can override to false if needed
var test_wiki_values: bool = Global.enable_wiki # can override to false if needed
var use_kept_precisions := true # set same as BodyBuilder.keep_real_precisions
var labels_stretch_ratio := 0.6
var values_stretch_ratio := 0.4
var interval := 1.0 # seconds; set 0.0 for no periodic updates

var section_headers := ["LABEL_ORBITAL_CHARACTERISTICS", "LABEL_PHYSICAL_CHARACTERISTICS",
	"LABEL_ATMOSPHERE", "LABEL_ATMOSPHERE_BY_VOLUME", "LABEL_TRACE_ATMOSPHERE_BY_VOLUME",
	"LABEL_PHOTOSPHERE_BY_WEIGHT"]
var subsection_of := [-1, -1, -1, 2, 2, -1]
var section_open := [true, true, true, true, true, true]
var section_data := [ # one array element per header
	# In each section array, we have an array for each data line containing:
	# [0] display label [1] path to property or method [2] method_args
	# [3] data_type [4] arg or args specific for data_type
	[ # Orbital Characteristics
		["LABEL_PERIAPSIS", "body/orbit/get_periapsis", NO_ARGS,
				QTY_TXT, [QtyTxtConverter.LENGTH_KM_AU, "", 5]],
		["LABEL_APOAPSIS", "body/orbit/get_apoapsis", NO_ARGS,
				QTY_TXT, [QtyTxtConverter.LENGTH_KM_AU, "", 5]],
		["LABEL_SEMI_MAJOR_AXIS", "body/orbit/get_semimajor_axis", NO_ARGS,
				QTY_TXT, [QtyTxtConverter.LENGTH_KM_AU, "", 5]],
		["LABEL_ECCENTRICITY", "body/orbit/get_eccentricity", NO_ARGS, AS_IS],
		["LABEL_ORBITAL_PERIOD", "body/orbit/get_orbital_perioid", NO_ARGS,
				QTY_TXT, [QtyTxtConverter.TIME_D_Y, "", 5]],
		["LABEL_AVERAGE_ORBITAL_SPEED", "body/orbit/get_average_orbital_speed", NO_ARGS,
				QTY_TXT, [QtyTxtConverter.VELOCITY_MPS_KMPS, "", 5]],
		["LABEL_INCLINATION_TO_ECLIPTIC", "body/orbit/get_inclination_to_ecliptic", NO_ARGS,
				QTY_TXT, [QtyTxtConverter.UNIT, "deg", 3, QtyTxtConverter.NUM_DECIMAL_PL]],
		["LABEL_INCLINATION_TO_EQUATOR", "body/get_orbit_inclination_to_equator", NO_ARGS,
				QTY_TXT, [QtyTxtConverter.UNIT, "deg", 3, QtyTxtConverter.NUM_DECIMAL_PL]],
		["LABEL_DIST_GALACTIC_CORE", "body/characteristics/dist_galactic_core", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.LENGTH_KM_AU]],
		["LABEL_GALACTIC_PERIOD", "body/characteristics/galactic_period", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.UNIT, "yr"]],
		["LABEL_AVERAGE_ORBITAL_SPEED", "body/characteristics/galactic_orbital_speed", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.UNIT, "km/s"]],
		["LABEL_VELOCITY_VS_CMB", "body/characteristics/velocity_vs_cmb", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.UNIT, "km/s"]],
		["LABEL_VELOCITY_VS_NEAR_STARS", "body/characteristics/velocity_vs_near_stars", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.UNIT, "km/s"]],
		
		["LABEL_KN_PLANETS", "body/characteristics/n_kn_planets", NO_ARGS, AS_IS],
		["LABEL_KN_DWF_PLANETS", "body/characteristics/n_kn_dwf_planets", NO_ARGS, AS_IS],
		["LABEL_KN_MINOR_PLANETS", "body/characteristics/n_kn_minor_planets", NO_ARGS, AS_IS],
		["LABEL_KN_COMETS", "body/characteristics/n_kn_comets", NO_ARGS, AS_IS],
		["LABEL_NAT_SATELLITES", "body/characteristics/n_nat_satellites", NO_ARGS, AS_IS],
		["LABEL_KN_NAT_SATELLITES", "body/characteristics/n_kn_nat_satellites", NO_ARGS, AS_IS],
		["LABEL_KN_QUASI_SATELLITES", "body/characteristics/n_kn_quasi_satellites", NO_ARGS, AS_IS],
	],
	[ # Physical Characteristics
		["LABEL_CLASSIFICATION", "body/characteristics/class_type", NO_ARGS,
				TABLE_ROW, "classes"],
		["LABEL_STELLAR_CLASSIFICATION", "body/characteristics/stellar_classification", NO_ARGS, AS_IS],
		["LABEL_MEAN_RADIUS", "body/m_radius", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.UNIT, "km"]],
		["LABEL_EQUATORIAL_RADIUS", "body/characteristics/e_radius", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.UNIT, "km"]],
		["LABEL_POLAR_RADIUS", "body/characteristics/p_radius", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.UNIT, "km"]],
		["LABEL_HYDROSTATIC_EQUILIBRIUM", "body/characteristics/hydrostatic_equilibrium", NO_ARGS,
				ENUM, "ConfidenceType"],
		["LABEL_MASS", "body/characteristics/mass", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.MASS_G_KG]],
		["LABEL_SURFACE_GRAVITY", "body/characteristics/surface_gravity", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.UNIT, "_g"]],
		["LABEL_ESCAPE_VELOCITY", "body/characteristics/esc_vel", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.VELOCITY_MPS_KMPS]],
		["LABEL_MEAN_DENSITY", "body/characteristics/mean_density", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.UNIT, "g/cm^3"]],
		["LABEL_ALBEDO", "body/characteristics/albedo", NO_ARGS,
				QTY_TXT, [QtyTxtConverter.NUMBER]],
		["LABEL_SURFACE_TEMP_MIN", "body/characteristics/min_t", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.UNIT, "degC"]],
		["LABEL_SURFACE_TEMP_MEAN", "body/characteristics/surf_t", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.UNIT, "degC"]],
		["LABEL_SURFACE_TEMP_MAX", "body/characteristics/max_t", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.UNIT, "degC"]],
		["LABEL_TEMP_CENTER", "body/characteristics/temp_center", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.UNIT, "K"]],
		["LABEL_TEMP_PHOTOSPHERE", "body/characteristics/temp_photosphere", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.UNIT, "K"]],
		["LABEL_TEMP_CORONA", "body/characteristics/temp_corona", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.UNIT, "K"]],
		["LABEL_ABSOLUTE_MAGNITUDE", "body/characteristics/absolute_magnitude", NO_ARGS, AS_IS],
		["LABEL_LUMINOSITY", "body/characteristics/luminosity", NO_ARGS,
				QTY_TXT, [QtyTxtConverter.UNIT, "W"]],
		["LABEL_COLOR_B_V", "body/characteristics/color_b_v", NO_ARGS, AS_IS],
		["LABEL_METALLICITY", "body/characteristics/metallicity", NO_ARGS, AS_IS],
		["LABEL_AGE", "body/characteristics/age", NO_ARGS, QTY_TXT, [QtyTxtConverter.UNIT, "yr"]],
		
		
		
		["LABEL_ROTATION_PERIOD", "body/characteristics/rotation_period", NO_ARGS,
				QTY_TXT_W_PRECISION, [QtyTxtConverter.UNIT, "d", 5]],
		["LABEL_AXIAL_TILT_TO_ORBIT", "body/get_axial_tilt_to_orbit", NO_ARGS,
				QTY_TXT, [QtyTxtConverter.UNIT, "deg", 4]],
		["LABEL_AXIAL_TILT_TO_ECLIPTIC", "body/get_axial_tilt_to_ecliptic", NO_ARGS,
				QTY_TXT, [QtyTxtConverter.UNIT, "deg", 4]],
	],
	[ # Atmosphere
		["LABEL_SURFACE_PRESSURE", "body/characteristics/surf_pres", NO_ARGS,
				QTY_TXT, [QtyTxtConverter.PREFIXED_UNIT, "bar"]],
		["LABEL_TRACE_PRESSURE", "body/characteristics/trace_pres", NO_ARGS,
				QTY_TXT, [QtyTxtConverter.PREFIXED_UNIT, "Pa"]],
		["LABEL_TRACE_PRESSURE_HIGH", "body/characteristics/trace_pres_high", NO_ARGS,
				QTY_TXT, [QtyTxtConverter.PREFIXED_UNIT, "Pa"]],
		["LABEL_TRACE_PRESSURE_LOW", "body/characteristics/trace_pres_low", NO_ARGS,
				QTY_TXT, [QtyTxtConverter.PREFIXED_UNIT, "Pa"]],
		["LABEL_TEMP_AT_1_BAR", "body/characteristics/one_bar_t", NO_ARGS,
				QTY_TXT, [QtyTxtConverter.UNIT, "degC"]],
		["LABEL_TEMP_AT_HALF_BAR", "body/characteristics/half_bar_t", NO_ARGS,
				QTY_TXT, [QtyTxtConverter.UNIT, "degC"]],
		["LABEL_TEMP_AT_10TH_BAR", "body/characteristics/tenth_bar_t", NO_ARGS,
				QTY_TXT, [QtyTxtConverter.UNIT, "degC"]],
	],
	[ # Atmosphere composition
		["", "body/components/atmosphere", NO_ARGS, OBJECT_LABELS_VALUES],
	],
	[ # Trace atmosphere composition
		["", "body/components/trace_atmosphere", NO_ARGS, OBJECT_LABELS_VALUES],
	],
	[ # Photosphere composition
		["", "body/components/photosphere", NO_ARGS, OBJECT_LABELS_VALUES],
	],
]

var body_flags_test := { # show criteria
	"body/m_radius" : BodyFlags.DISPLAY_M_RADIUS,
	"body/characteristics/hydrostatic_equilibrium" : BodyFlags.IS_MOON,
}

var special_processing := {
	"body/characteristics/rotation_period" : "_mod_rotation_period",
	"body/get_axial_tilt_to_orbit" : "_mod_axial_tilt_to_orbit",
	"body/get_axial_tilt_to_ecliptic" : "_mod_axial_tilt_to_ecliptic",
	"body/characteristics/n_kn_dwf_planets" : "_mod_n_kn_dwf_planets",
}

onready var _qty_txt_converter: QtyTxtConverter = Global.program.QtyTxtConverter
onready var _table_reader: TableReader = Global.program.TableReader
var _state: Dictionary = Global.state
var _enums: Script = Global.enums
var _wiki_titles: Dictionary = Global.wiki_titles
var _wiki_locale: String = Global.wiki
var _selection_manager: SelectionManager
var _header_buttons := []
var _grids := []
var _meta_lookup := {} # translate link text to wiki key
var _recycled_labels := []
var _recycled_rtlabels := []
# currently processing
var _selection_item: SelectionItem
var _body: Body
var _path: String

func _ready() -> void:
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator")
	Global.connect("about_to_free_procedural_nodes", self, "_clear")
	Global.connect("about_to_stop_before_quit", self, "_clear_recycled")
	_start_interval_updates()

func _clear() -> void:
	if _selection_manager:
		_selection_manager.disconnect("selection_changed", self, "_update_selection")
		_selection_manager = null
	_selection_item = null
	_body = null
	_header_buttons.clear()
	_grids.clear()
	_meta_lookup.clear()
	for child in get_children():
		child.queue_free()
	_clear_recycled()

func _clear_recycled() -> void:
	while _recycled_labels:
		_recycled_labels.pop_back().queue_free()
	while _recycled_rtlabels:
		_recycled_rtlabels.pop_back().queue_free()

func _on_about_to_start_simulator(_is_loaded_game: bool) -> void:
	assert(section_headers.size() == subsection_of.size())
	assert(section_headers.size() == section_data.size())
	assert(section_headers.size() == section_open.size())
	_selection_manager = GUIUtils.get_selection_manager(self)
	_selection_manager.connect("selection_changed", self, "_update_selection")
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
	_update_selection()

func _start_interval_updates() -> void:
	if !interval:
		return
	while true:
		yield(get_tree().create_timer(interval), "timeout")
		if _state.is_running:
			_update_selection()

func _update_selection() -> void:
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
	_path = line_data[1]
	# flags exclusion
	var body_flags: int = body_flags_test.get(_path, 0)
	if body_flags:
		if !_body or not _body.flags & body_flags:
			return NULL_ARRAY
	# get value from SelectionItem or nested object
	var method_args: Array = line_data[2]
	var value = GDUtils.get_path_result(_selection_item, _path, method_args)
	if value == null:
		return NULL_ARRAY # doesn't exist
	# get value text and possibly wiki key
	var data_type: int = line_data[3]
	var value_txt: String
	var value_wiki_key: String
	match typeof(value):
		TYPE_INT:
			var key: String
			if value == -9999:
				value_txt = "?"
			elif value == -1:
				pass # don't display
			elif data_type == TABLE_ROW:
				var table_name: String = line_data[4]
				key = _table_reader.get_row_name(table_name, value)
				value_txt = tr(key)
				if test_wiki_values and _wiki_titles.has(key):
					value_wiki_key = key
			elif data_type == ENUM:
				var enum_name: String = line_data[4]
				var enum_dict: Dictionary = _enums.get(enum_name)
				var enum_keys: Array = enum_dict.keys()
				key = enum_keys[value]
				value_txt = tr(key)
				if test_wiki_values and _wiki_titles.has(key):
					value_wiki_key = key
			else:
				value_txt = str(value)
		TYPE_REAL:
			if is_inf(value):
				value_txt = "?"
			elif is_nan(value):
				pass # don't display
			elif data_type == AS_IS:
				value_txt = str(value)
			elif data_type == QTY_TXT or data_type == QTY_TXT_W_PRECISION:
				var args: Array = line_data[4]
				var n_args: int = args.size()
				var option_type: int = args[0]
				var unit: String = args[1] if n_args > 1 else ""
				var precision: int = args[2] if n_args > 2 else -1
				if use_kept_precisions and data_type == QTY_TXT_W_PRECISION:
					var kept_precision: int = _selection_item.real_precisions.get(_path, -1)
					if kept_precision != -1:
						precision = kept_precision
				var num_type: int = args[3] if n_args > 3 else QtyTxtConverter.NUM_DYNAMIC
				var long_form: bool = args[4] if n_args > 4 else false
				var case_type: int = args[5] if n_args > 5 else QtyTxtConverter.CASE_MIXED
				
#				if _path == "body/characteristics/dist_galactic_core":
#					print("precision = ", precision)
#
				
				value_txt = _qty_txt_converter.number_option(value, option_type, unit, precision,
						num_type, long_form, case_type)
				if precision == 0:
					value_txt = "~" + value_txt
		TYPE_STRING:
			value_txt = tr(value)
			if test_wiki_values and _wiki_titles.has(value):
				value_wiki_key = value
		TYPE_OBJECT:
			if data_type == OBJECT_LABELS_VALUES:
				var labels_values = value.get_labels_values_display(prespace)
				return [labels_values[0], labels_values[1], false, false]
	if !value_txt:
		return NULL_ARRAY # n/a
	var special_process: String = special_processing.get(_path, "")
	if special_process:
		value_txt = call(special_process, value_txt, value)
	# get label text
	var label_key: String = line_data[0]
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
	# wiki links
	var is_label_link := false
	var is_value_link := false
	if test_wiki_labels and _wiki_titles.has(label_key): # label is wiki link
		_meta_lookup[label_txt] = label_key
		label_txt = "[url]" + label_txt + "[/url]"
		is_label_link = true
	if value_wiki_key: # value is wiki link
		_meta_lookup[value_txt] = value_wiki_key
		value_txt = "[url]" + value_txt + "[/url]"
		is_value_link = true
	return [prespace + label_txt, value_txt, is_label_link, is_value_link]

func _add_row(grid: GridContainer, row_info: Array) -> void:
	var label_txt: String = row_info[0]
	var value_txt: String = row_info[1]
	var is_label_link: bool = row_info[2]
	var is_value_link: bool = row_info[3]
	if is_label_link:
		var label_cell := _get_rtlabel(false)
		label_cell.bbcode_text = label_txt
		grid.add_child(label_cell)
	else:
		var label_cell := _get_label(false)
		label_cell.text = label_txt
		grid.add_child(label_cell)
	if is_value_link:
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
	Global.emit_signal("open_wiki_requested", wiki_title)

# special processing functions

func _mod_rotation_period(value_txt: String, value: float) -> String:
	if _body:
		if _body.flags & BodyFlags.IS_TIDALLY_LOCKED:
			value_txt += " (%s)" % tr("TXT_TIDALLY_LOCKED").to_lower()
		elif _body.flags & BodyFlags.TUMBLES_CHAOTICALLY:
			value_txt = "~%s d (%s)" % [round(value / UnitDefs.DAY), tr("TXT_CHAOTIC").to_lower()]
		elif _body.name == "PLANET_MERCURY":
			value_txt += " (3:2 %s)" % tr("TXT_RESONANCE").to_lower()
		elif _body.is_rotation_retrograde():
			value_txt += " (%s)" % tr("TXT_RETROGRADE").to_lower()
	return value_txt

func _mod_axial_tilt_to_orbit(value_txt: String, value: float) -> String:
	if _body:
		if is_zero_approx(value) and _body.flags & BodyFlags.IS_TIDALLY_LOCKED:
			value_txt = "~0\u00B0"
		elif _body.flags & BodyFlags.TUMBLES_CHAOTICALLY:
			value_txt = tr("TXT_VARIABLE")
	return value_txt

func _mod_axial_tilt_to_ecliptic(value_txt: String, _value: float) -> String:
	if _body:
		if _body.flags & BodyFlags.TUMBLES_CHAOTICALLY:
			value_txt = tr("TXT_VARIABLE")
	return value_txt

func _mod_n_kn_dwf_planets(value_txt: String, _value: float) -> String:
	return "%s (%s)" % [value_txt, tr("TXT_POSSIBLE").to_lower()]
