# selection_data.gd
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
class_name IVSelectionData
extends VBoxContainer

# GUI widget.
# An ancestor Control node must have property 'selection_manager'
# set to an IVSelectionManager before signal IVGlobal.about_to_start_simulator.
#
# Typed values interpreted as n/a; widget skips row and doesn't display:
#   NAN
#   -1
#   ""
#
# Typed values interpreted as unknown; widget displays as "?":
#   INF or -INF
#   -99999999
#
# For most applicatios, you'll want to put this widget in a ScrollContainer.
#
# TODO: tooltips.

enum { # data_type
	AS_IS,
	QTY_TXT,
	QTY_TXT_W_PRECISION,
	TABLE_ROW,
	ENUM,
	OBJECT_LABELS_VALUES,
}

const BodyFlags := IVEnums.BodyFlags
const NULL_ARRAY := []

# project vars
var enable_wiki_labels: bool = IVGlobal.enable_wiki # can override to false if needed
var enable_wiki_values: bool = IVGlobal.enable_wiki # can override to false if needed
var enable_precisions := IVGlobal.enable_precisions
var labels_stretch_ratio := 0.6
var values_stretch_ratio := 0.4
var interval := 0.0 # seconds; set 0.0 for no periodic updates
var section_headers := [&"LABEL_ORBITAL_CHARACTERISTICS", &"LABEL_PHYSICAL_CHARACTERISTICS",
	&"LABEL_ATMOSPHERE", &"LABEL_ATMOSPHERE_BY_VOLUME", &"LABEL_TRACE_ATMOSPHERE_BY_VOLUME",
	&"LABEL_PHOTOSPHERE_BY_WEIGHT"]
var subsection_of: Array[int] = [-1, -1, -1, 2, 2, -1]
var section_open: Array[bool] = [true, true, true, true, true, true]



var section_content: Array[Array] = [
	# In each section array, we have an array for each data line containing:
	#   [0] display label, [1] path to property or method, [2] path args,
	#   [3] format callable
	
	[ # Orbital Characteristics
		[&"LABEL_PERIAPSIS", "body/orbit/get_periapsis", NULL_ARRAY,
			dynamic_unit.bind(IVQFormat.LENGTH_KM_AU, true, 5)],
		[&"LABEL_APOAPSIS", "body/orbit/get_apoapsis", NULL_ARRAY,
			dynamic_unit.bind(IVQFormat.LENGTH_KM_AU, true, 5)],
		[&"LABEL_SEMI_MAJOR_AXIS", "body/orbit/get_semimajor_axis", NULL_ARRAY,
			dynamic_unit.bind(IVQFormat.LENGTH_KM_AU, true, 5)],
		[&"LABEL_ECCENTRICITY", "body/orbit/get_eccentricity", NULL_ARRAY,
			as_float.bind(true, 5)],
		[&"LABEL_ORBITAL_PERIOD", "body/orbit/get_orbital_perioid", NULL_ARRAY,
			dynamic_unit.bind(IVQFormat.TIME_D_Y, true, 5)],
		[&"LABEL_AVERAGE_ORBITAL_SPEED", "body/orbit/get_average_orbital_speed", NULL_ARRAY,
			dynamic_unit.bind(IVQFormat.VELOCITY_MPS_KMPS, true, 5)],
		[&"LABEL_INCLINATION_TO_ECLIPTIC", "body/orbit/get_inclination_to_ecliptic", NULL_ARRAY,
			fixed_unit.bind(&"deg", true, 3, IVQFormat.NUM_DECIMAL_PL)],
		[&"LABEL_INCLINATION_TO_EQUATOR", "body/get_orbit_inclination_to_equator", NULL_ARRAY,
			fixed_unit.bind(&"deg", true, 3, IVQFormat.NUM_DECIMAL_PL)],
		[&"LABEL_DIST_GALACTIC_CORE", "body/characteristics/dist_galactic_core", NULL_ARRAY,
			dynamic_unit.bind(IVQFormat.LENGTH_KM_AU)],
		[&"LABEL_GALACTIC_PERIOD", "body/characteristics/galactic_period", NULL_ARRAY,
			fixed_unit.bind(&"yr")],
		[&"LABEL_AVERAGE_ORBITAL_SPEED", "body/characteristics/galactic_orbital_speed", NULL_ARRAY,
			fixed_unit.bind(&"km/s")],
		[&"LABEL_VELOCITY_VS_CMB", "body/characteristics/velocity_vs_cmb", NULL_ARRAY,
			fixed_unit.bind(&"km/s")],
		[&"LABEL_VELOCITY_VS_NEAR_STARS", "body/characteristics/velocity_vs_near_stars", NULL_ARRAY,
			fixed_unit.bind(&"km/s")],
		[&"LABEL_KN_PLANETS", "body/characteristics/n_kn_planets", NULL_ARRAY,
			as_integer],
		[&"LABEL_KN_DWF_PLANETS", "body/characteristics/n_kn_dwf_planets", NULL_ARRAY,
			as_integer],
		[&"LABEL_KN_MINOR_PLANETS", "body/characteristics/n_kn_minor_planets", NULL_ARRAY,
			as_integer],
		[&"LABEL_KN_COMETS", "body/characteristics/n_kn_comets", NULL_ARRAY,
			as_integer],
		[&"LABEL_NAT_SATELLITES", "body/characteristics/n_nat_satellites", NULL_ARRAY,
			as_integer],
		[&"LABEL_KN_NAT_SATELLITES", "body/characteristics/n_kn_nat_satellites", NULL_ARRAY,
			as_integer],
		[&"LABEL_KN_QUASI_SATELLITES", "body/characteristics/n_kn_quasi_satellites", NULL_ARRAY,
			as_integer],
	],
	
	[ # Physical Characteristics
		[&"LABEL_CLASSIFICATION", "body/characteristics/body_class", NULL_ARRAY,
			table_entity.bind(&"body_classes")],
		[&"LABEL_STELLAR_CLASSIFICATION", "body/characteristics/stellar_classification", NULL_ARRAY,
			as_text],
		[&"LABEL_MEAN_RADIUS", "body/m_radius", NULL_ARRAY,
			fixed_unit.bind(&"km")],
		[&"LABEL_EQUATORIAL_RADIUS", "body/characteristics/e_radius", NULL_ARRAY,
			fixed_unit.bind(&"km")],
		[&"LABEL_POLAR_RADIUS", "body/characteristics/p_radius", NULL_ARRAY,
			fixed_unit.bind(&"km")],
		[&"LABEL_HYDROSTATIC_EQUILIBRIUM", "body/characteristics/hydrostatic_equilibrium", NULL_ARRAY,
			enum_item.bind(IVEnums.Confidence)],
		[&"LABEL_MASS", "body/characteristics/mass", NULL_ARRAY,
			fixed_unit.bind(&"kg")],
		[&"LABEL_SURFACE_GRAVITY", "body/characteristics/surface_gravity", NULL_ARRAY,
			fixed_unit.bind(&"_g")],
		[&"LABEL_ESCAPE_VELOCITY", "body/characteristics/esc_vel", NULL_ARRAY,
			dynamic_unit.bind(IVQFormat.VELOCITY_MPS_KMPS)],
		[&"LABEL_MEAN_DENSITY", "body/characteristics/mean_density", NULL_ARRAY,
			fixed_unit.bind(&"g/cm^3")],
		[&"LABEL_ALBEDO", "body/characteristics/albedo", NULL_ARRAY,
			as_float],
		[&"LABEL_SURFACE_TEMP_MIN", "body/characteristics/min_t", NULL_ARRAY,
			fixed_unit.bind(&"degC")],
		[&"LABEL_SURFACE_TEMP_MEAN", "body/characteristics/surf_t", NULL_ARRAY,
			fixed_unit.bind(&"degC")],
		[&"LABEL_SURFACE_TEMP_MAX", "body/characteristics/max_t", NULL_ARRAY,
			fixed_unit.bind(&"degC")],
		[&"LABEL_TEMP_CENTER", "body/characteristics/temp_center", NULL_ARRAY,
			fixed_unit.bind(&"K")],
		[&"LABEL_TEMP_PHOTOSPHERE", "body/characteristics/temp_photosphere", NULL_ARRAY,
			fixed_unit.bind(&"K")],
		[&"LABEL_TEMP_CORONA", "body/characteristics/temp_corona", NULL_ARRAY,
			fixed_unit.bind(&"K")],
		[&"LABEL_ABSOLUTE_MAGNITUDE", "body/characteristics/absolute_magnitude", NULL_ARRAY,
			as_float],
		[&"LABEL_LUMINOSITY", "body/characteristics/luminosity", NULL_ARRAY,
			fixed_unit.bind(&"W")],
		[&"LABEL_COLOR_B_V", "body/characteristics/color_b_v", NULL_ARRAY,
			as_float],
		[&"LABEL_METALLICITY", "body/characteristics/metallicity", NULL_ARRAY,
			as_float],
		[&"LABEL_AGE", "body/characteristics/age", NULL_ARRAY,
			fixed_unit.bind(&"yr")],
		[&"LABEL_ROTATION_PERIOD", "body/characteristics/rotation_period", NULL_ARRAY,
			fixed_unit.bind(&"d", true, 5)],
		[&"LABEL_AXIAL_TILT_TO_ORBIT", "body/get_axial_tilt_to_orbit", NULL_ARRAY,
			fixed_unit.bind(&"deg", true, 4)],
		[&"LABEL_AXIAL_TILT_TO_ECLIPTIC", "body/get_axial_tilt_to_ecliptic", NULL_ARRAY,
			fixed_unit.bind(&"deg", true, 4)],
	],


	[ # Atmosphere
		[&"LABEL_SURFACE_PRESSURE", "body/characteristics/surf_pres", NULL_ARRAY,
			prefixed_unit.bind(&"bar")],
		[&"LABEL_TRACE_PRESSURE", "body/characteristics/trace_pres", NULL_ARRAY,
			prefixed_unit.bind(&"Pa")],
		[&"LABEL_TRACE_PRESSURE_HIGH", "body/characteristics/trace_pres_high", NULL_ARRAY,
			prefixed_unit.bind(&"Pa")],
		[&"LABEL_TRACE_PRESSURE_LOW", "body/characteristics/trace_pres_low", NULL_ARRAY,
			prefixed_unit.bind(&"Pa")],
		[&"LABEL_TEMP_AT_1_BAR", "body/characteristics/one_bar_t", NULL_ARRAY,
			fixed_unit.bind(&"degC")],
		[&"LABEL_TEMP_AT_HALF_BAR", "body/characteristics/half_bar_t", NULL_ARRAY,
			fixed_unit.bind(&"degC")],
		[&"LABEL_TEMP_AT_10TH_BAR", "body/characteristics/tenth_bar_t", NULL_ARRAY,
			fixed_unit.bind(&"degC")],
	],
	
	[ # Atmosphere composition
		[&"", "body/components/atmosphere", NULL_ARRAY, object_labels_values_display],
	],
	[ # Trace atmosphere composition
		[&"", "body/components/trace_atmosphere", NULL_ARRAY, object_labels_values_display],
	],
	[ # Photosphere composition
		[&"", "body/components/photosphere", NULL_ARRAY, object_labels_values_display],
	],
]

var body_flags_test := { # show criteria
	"body/m_radius" : BodyFlags.DISPLAY_M_RADIUS,
	"body/characteristics/hydrostatic_equilibrium" : BodyFlags.IS_MOON,
}

var value_postprocessors := {
	"body/characteristics/rotation_period" : mod_rotation_period,
	"body/get_axial_tilt_to_orbit" : mod_axial_tilt_to_orbit,
	"body/get_axial_tilt_to_ecliptic" : mod_axial_tilt_to_ecliptic,
	"body/characteristics/n_kn_dwf_planets" : mod_n_kn_dwf_planets,
}

var _state: Dictionary = IVGlobal.state
var _wiki_titles: Dictionary = IVTableData.wiki_lookup
var _header_buttons: Array[Button] = []
var _grids: Array[GridContainer] = []
var _meta_lookup := {} # translate link text to wiki key
var _recycled_labels: Array[Label] = []
var _recycled_rtlabels: Array[RichTextLabel] = []
var _selection_manager: IVSelectionManager
var _selection: IVSelection
var _body: IVBody
#var path: String
var _is_running := false

@onready var _timer: Timer = $Timer


func _ready() -> void:
	IVGlobal.about_to_start_simulator.connect(_configure)
	IVGlobal.update_gui_requested.connect(_update_selection)
	IVGlobal.about_to_free_procedural_nodes.connect(_clear)
	IVGlobal.about_to_stop_before_quit.connect(_clear_recycled)
	_configure()
	_start_timer_coroutine()


# *****************************************************************************
# Format callables

func dynamic_unit(x: float, internal_precision: int, dynamic_unit_type: int,
		override_internal_precision := false, precision := 3,
		num_type := IVQFormat.NUM_DYNAMIC) -> String:
	# args 0, 1 from loop code
	# args 2, ... are binds from section_content
	if is_inf(x):
		return "?"
	if !override_internal_precision and internal_precision != -1:
		precision = internal_precision
	return IVQFormat.dynamic_unit(x, dynamic_unit_type, precision, num_type)


func fixed_unit(x: float, internal_precision: int, unit: StringName,
		override_internal_precision := false, precision := 3,
		num_type := IVQFormat.NUM_DYNAMIC) -> String:
	if is_inf(x):
		return "?"
	if !override_internal_precision and internal_precision != -1:
		precision = internal_precision
	return IVQFormat.fixed_unit(x, unit, precision, num_type)


func prefixed_unit(x: float, internal_precision: int, unit: StringName,
		override_internal_precision := false, precision := 3,
		num_type := IVQFormat.NUM_DYNAMIC) -> String:
	if is_inf(x):
		return "?"
	if !override_internal_precision and internal_precision != -1:
		precision = internal_precision
	return IVQFormat.prefixed_unit(x, unit, precision, num_type)


func as_float(x: float, internal_precision: int,
		override_internal_precision := false, precision := 3,
		num_type := IVQFormat.NUM_DYNAMIC) -> String:
	if is_inf(x):
		return "?"
	if !override_internal_precision and internal_precision != -1:
		precision = internal_precision
	return IVQFormat.number(x, precision, num_type)


func as_text(text: String) -> Array[String]:
	# StringName ok
	if enable_wiki_values and _wiki_titles.has(text):
		return [tr(text), text]
	return [tr(text)]


func as_integer(integer: int) -> Array[String]:
	if integer == -99999999:
		return ["?"]
	return [str(integer)]


func table_entity(row: int, table_name: StringName) -> Array[String]:
	var entity_name := IVTableData.get_db_entity_name(table_name, row)
	if enable_wiki_values and _wiki_titles.has(entity_name):
		return [tr(entity_name), entity_name]
	return [tr(entity_name)]


func enum_item(enum_int: int, enum_dict: Dictionary) -> Array[String]:
	# Assumes standard [0, 1, 2, 3, ..., enum.size()-1] enumeration.
	var enum_keys := enum_dict.keys()
	var enum_name: String = enum_keys[enum_int]
	if enable_wiki_values and _wiki_titles.has(enum_name):
		return [tr(enum_name), enum_name]
	return [tr(enum_name)]


func object_labels_values_display(object: Object, prespace: String) -> Array:
	# Object must create a data subsection w/ lables & values
	assert(object.has_method(&"get_labels_values_display"))
	@warning_ignore("unsafe_method_access")
	return object.get_labels_values_display(prespace) # [labels, values]


# *****************************************************************************
# Value postprocessors

func mod_rotation_period(value_txt: String, value: float) -> String:
	if _body:
		if _body.flags & BodyFlags.IS_TIDALLY_LOCKED:
			value_txt += " (%s)" % tr(&"TXT_TIDALLY_LOCKED").to_lower()
		elif _body.flags & BodyFlags.TUMBLES_CHAOTICALLY:
			value_txt = "~%s d (%s)" % [round(value / IVUnits.DAY), tr(&"TXT_CHAOTIC").to_lower()]
		elif _body.name == &"PLANET_MERCURY":
			value_txt += " (3:2 %s)" % tr(&"TXT_RESONANCE").to_lower()
		elif _body.is_rotation_retrograde():
			value_txt += " (%s)" % tr(&"TXT_RETROGRADE").to_lower()
	return value_txt


func mod_axial_tilt_to_orbit(value_txt: String, value: float) -> String:
	if _body:
		if is_zero_approx(value) and _body.flags & BodyFlags.IS_TIDALLY_LOCKED:
			value_txt = "~0\u00B0"
		elif _body.flags & BodyFlags.TUMBLES_CHAOTICALLY:
			value_txt = tr(&"TXT_VARIABLE")
	return value_txt


func mod_axial_tilt_to_ecliptic(value_txt: String, _value: float) -> String:
	if _body:
		if _body.flags & BodyFlags.TUMBLES_CHAOTICALLY:
			value_txt = tr(&"TXT_VARIABLE")
	return value_txt


func mod_n_kn_dwf_planets(value_txt: String, _value: float) -> String:
	return "%s (%s)" % [value_txt, tr(&"TXT_POSSIBLE").to_lower()]


# *****************************************************************************
# Label substitution

func substitute_label(label_key: StringName, body: IVBody) -> StringName:
	if !body:
		return label_key
	if label_key == &"LABEL_PERIAPSIS":
		var parent := _body.get_parent() as IVBody
		if parent:
			if parent.name == &"STAR_SUN":
				return &"LABEL_PERIHELION"
			elif parent.name == &"PLANET_EARTH":
				return &"LABEL_PERIGEE"
	elif label_key == &"LABEL_APOAPSIS":
		var parent := _body.get_parent() as IVBody
		if parent:
			if parent.name == &"STAR_SUN":
				return &"LABEL_APHELION"
			elif parent.name == &"PLANET_EARTH":
				return &"LABEL_APOGEE"
	return label_key


# *****************************************************************************

func _configure(_dummy := false) -> void:
	if _selection_manager:
		return
	_selection_manager = IVSelectionManager.get_selection_manager(self)
	if !_selection_manager:
		return
	_selection_manager.selection_changed.connect(_update_selection)
	assert(section_headers.size() == subsection_of.size())
	assert(section_headers.size() == section_content.size())
	assert(section_headers.size() == section_open.size())
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
			header_button.pressed.connect(_process_section.bind(section, true))
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


func _clear() -> void:
	if _selection_manager:
		_selection_manager.selection_changed.disconnect(_update_selection)
		_selection_manager = null
	_selection = null
	_body = null
	_header_buttons.clear()
	_grids.clear()
	_meta_lookup.clear()
	for child in get_children():
		child.queue_free()
	_clear_recycled()


func _clear_recycled() -> void:
	while _recycled_labels:
		var label: Label = _recycled_labels.pop_back()
		label.queue_free()
	while _recycled_rtlabels:
		var rtlabel: RichTextLabel = _recycled_rtlabels.pop_back()
		rtlabel.queue_free()


func _start_timer_coroutine() -> void:
	if !interval:
		return
	if _is_running:
		return
	_is_running = true
	_timer.wait_time = interval
	_timer.start()
	while true:
		await _timer.timeout
		if _state.is_running:
			_update_selection()


func _update_selection(_dummy := false) -> void:
	_selection = _selection_manager.selection
	if !_selection:
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
	var n_data: int = section_content[section].size()
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
	
	var line_content: Array = section_content[section][data_index]
	var path: String = line_content[1]
	# flags exclusion
	var body_flags: int = body_flags_test.get(path, 0)
	if body_flags:
		if !_body or not _body.flags & body_flags:
			return NULL_ARRAY
	# get value from IVSelection or nested object
	var method_args: Array = line_content[2]
	var value: Variant = IVUtils.get_path_result(_selection, path, method_args)
	if value == null:
		return NULL_ARRAY # doesn't exist
	
	var value_txt: String
	var value_wiki_key: StringName
	
	# get value text and possibly wiki key by value type
	var format_callable: Callable = line_content[3]
	var value_type := typeof(value)
	if value_type == TYPE_FLOAT:
		if is_nan(value):
			return NULL_ARRAY
		var internal_precision := -1
		if enable_precisions:
			internal_precision = _selection.get_float_precision(path) # -1 if path fails
		value_txt = format_callable.call(value, internal_precision)
	elif value_type == TYPE_INT:
		if value == -1:
			return NULL_ARRAY
		var result: Array = format_callable.call(value)
		value_txt = result[0]
		if result.size() > 1:
			value_wiki_key = result[1]
	elif value_type == TYPE_OBJECT:
		var result: Array = format_callable.call(value, prespace)
		return [result[0], result[1], false, false]
	else: # String or StringName
		var result: Array = format_callable.call(value)
		value_txt = result[0]
		if result.size() > 1:
			value_wiki_key = result[1]
	
	if !value_txt:
		return NULL_ARRAY # n/a
	
	# value postprocessing
	if value_postprocessors.has(path):
		var value_postprocessor: Callable = value_postprocessors[path]
		value_txt = value_postprocessor.call(value_txt, value)
		
	# label substitution
	var label_key := substitute_label(line_content[0], _body)
	var label_txt := tr(label_key)
	
	# wiki links
	var is_label_link := false
	var is_value_link := false
	if enable_wiki_labels and _wiki_titles.has(label_key): # label is wiki link
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
		label_cell.text = label_txt
		grid.add_child(label_cell)
	else:
		var label_cell := _get_label(false)
		label_cell.text = label_txt
		grid.add_child(label_cell)
	if is_value_link:
		var value_cell := _get_rtlabel(true)
		value_cell.text = value_txt
		grid.add_child(value_cell)
	else:
		var value_cell := _get_label(true)
		value_cell.text = value_txt
		grid.add_child(value_cell)


func _clear_grid(grid: GridContainer) -> void:
	if grid.get_child_count() == 0:
		return
	var children := grid.get_children()
	children.reverse()
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
		rtlabel.meta_clicked.connect(_on_meta_clicked)
		rtlabel.bbcode_enabled = true
		rtlabel.fit_content = true
		rtlabel.scroll_active = false
		rtlabel.size_flags_horizontal = SIZE_EXPAND_FILL
	rtlabel.size_flags_stretch_ratio = values_stretch_ratio if is_value else labels_stretch_ratio
	return rtlabel


func _on_meta_clicked(meta: String) -> void:
	var wiki_key: String = _meta_lookup[meta]
	var wiki_title: String = _wiki_titles[wiki_key]
	IVGlobal.open_wiki_requested.emit(wiki_title)


