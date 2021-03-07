# selection_buttons.gd
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
# To find properites, we search first in SelectionItem, then Body, then
# BodyProperties, then ModelController.
#
# For most applicatios, you'll want to put this widget in a ScrollContainer.
#
# TODO: tooltips.

extends GridContainer

const BodyFlags := Enums.BodyFlags

enum {
	TABLE_ROW,
	ENUM
}

# project vars
var enable_wiki_links := false # Global.enable_wiki must also be set
var max_data_items := 15
var search_body_components := ["body_properties", "model_controller", "orbit"]
var show_data := [
	# [0] property [1] display label [2-4] type-specific (see code)
	# [5] flags test (show) [6] flags test (is approximate value)
	# [7] label as wiki link [8] value as wiki link
	["class_type", "LABEL_CLASSIFICATION", TABLE_ROW, "classes", null, null, null, false, true],
	["apoapsis", "LABEL_APOAPSIS", QtyTxtConverter.LENGTH_KM_AU, "", 4],
	["periapsis", "LABEL_PERIAPSIS", QtyTxtConverter.LENGTH_KM_AU, "", 4],
	["orbital_perioid", "LABEL_ORBITAL_PERIOD", QtyTxtConverter.TIME_D_Y, "", 4],
	["average_orbital_speed", "LABEL_AVERAGE_ORBITAL_SPEED", QtyTxtConverter.VELOCITY_MPS_KMPS, "", 4],
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
	["surf_pres", "LABEL_SURFACE_PRESSURE", QtyTxtConverter.PREFIXED_UNIT, "bar"],
	["surf_t", "LABEL_SURFACE_TEMP", QtyTxtConverter.UNIT, "degC"],
	["min_t", "LABEL_MIN_TEMP", QtyTxtConverter.UNIT, "degC"],
	["max_t", "LABEL_MAX_TEMP", QtyTxtConverter.UNIT, "degC"],
	["one_bar_t", "LABEL_ONE_BAR_TEMP", QtyTxtConverter.UNIT, "degC"],
	["half_bar_t", "LABEL_HALF_BAR_TEMP", QtyTxtConverter.UNIT, "degC"],
	["tenth_bar_t", "LABEL_TENTH_BAR_TEMP", QtyTxtConverter.UNIT, "degC"],
	["n_stars", "LABEL_STARS"],
	["n_planets", "LABEL_PLANETS"],
	["n_dwarf_planets", "LABEL_DWARF_PLANETS"],
	["n_moons", "LABEL_MOONS"],
	["n_asteroids", "LABEL_ASTEROIDS"],
	["n_comets", "LABEL_COMETS"]
]

onready var _qty_txt_converter: QtyTxtConverter = Global.program.QtyTxtConverter
onready var _table_reader: TableReader = Global.program.TableReader
var _enums: Script = Global.enums
var _wiki_titles: Dictionary = Global.wiki_titles
var _selection_manager: SelectionManager
var _labels := []
var _values := []
var _meta_lookup := {}

func _ready():
	Global.connect("about_to_start_simulator", self, "_on_about_to_start_simulator")
	Global.connect("about_to_free_procedural_nodes", self, "_clear")
	Global.connect("setting_changed", self, "_settings_listener")

func _clear() -> void:
	_labels.clear()
	_values.clear()
	_meta_lookup.clear()
	for child in get_children():
		child.queue_free()

func _on_about_to_start_simulator(_is_loaded_game: bool) -> void:
	_selection_manager = GUIUtils.get_selection_manager(self)
	_selection_manager.connect("selection_changed", self, "_on_selection_changed")
	var grid_index := 0
	while grid_index < max_data_items:
		if enable_wiki_links:
			var label_label := RichTextLabel.new()
			label_label.scroll_active = false
			label_label.bbcode_enabled = true
			label_label.size_flags_horizontal = SIZE_EXPAND_FILL
			label_label.connect("meta_clicked", self, "_on_meta_clicked")
			label_label.hide()
			_labels.append(label_label)
			add_child(label_label)
			var value_label := RichTextLabel.new()
			value_label.scroll_active = false
			value_label.bbcode_enabled = true
			value_label.size_flags_horizontal = SIZE_EXPAND_FILL
			value_label.connect("meta_clicked", self, "_on_meta_clicked")
			value_label.hide()
			_values.append(value_label)
			add_child(value_label)
		else:
			var label_label := Label.new()
			label_label.size_flags_horizontal = SIZE_EXPAND_FILL
			label_label.clip_text = true
			label_label.hide()
			_labels.append(label_label)
			add_child(label_label)
			var value_label := Label.new()
			value_label.size_flags_horizontal = SIZE_EXPAND_FILL
			value_label.clip_text = true
			value_label.hide()
			_values.append(value_label)
			add_child(value_label)
		grid_index += 1
	_force_richtextlabel_height()
	_on_selection_changed()

func _on_selection_changed() -> void:
	var selection_item := _selection_manager.selection_item
	if !selection_item:
		return
	var body: Body
	if _selection_manager.is_body():
		body = _selection_manager.get_body()
	var grid_index := 0
	for show_datum in show_data:
		var property: String = show_datum[0]
		var value = selection_item.get(property) # untyped
		if value == null and body:
			for component_name in search_body_components:
				var component: Object = body.get(component_name)
				if component:
					value = component.get(property)
					if value != null:
						break
			if value == null:
				value = body.get(property)
		if value == null:
			continue
		var datum_size: int = show_datum.size()
		if datum_size > 5 and show_datum[5]:
			if !body or not body.flags & show_datum[5]:
				continue
		var value_str: String
		var value_wiki: String
		match typeof(value):
			TYPE_INT:
				if value == -9999:
					value_str = "?"
				elif value == -1:
					pass
				elif datum_size > 2 and show_datum[2] != null:
					var key: String
					match show_datum[2]:
						TABLE_ROW:
							var table_name: String = show_datum[3]
							key = _table_reader.get_row_name(table_name, value)
							value_str = tr(key)
						ENUM:
							var enum_name: String = show_datum[3]
							var enum_dict: Dictionary = _enums.get(enum_name)
							var enum_keys: Array = enum_dict.keys()
							key = enum_keys[value]
							value_str = tr(key)
					if enable_wiki_links and key and datum_size > 8 and show_datum[8]:
						value_wiki = key
				else:
					value_str = str(value)
			TYPE_REAL:
				if is_inf(value):
					value_str = "?"
				elif is_nan(value):
					pass
				elif datum_size > 2 and show_datum[2] != null:
					# expects elements 2, 3, 4
					var option_type: int = show_datum[2]
					var unit: String = show_datum[3] if datum_size > 3 and show_datum[3] != null else ""
					var sig_digits: int = show_datum[4] if datum_size > 4 and show_datum[4] != null else -1
					value_str = _qty_txt_converter.number_option(value, option_type, unit, sig_digits)
				else:
					value_str = str(value)
			TYPE_STRING:
				value_str = tr(value)
				if enable_wiki_links and datum_size > 8 and show_datum[8]:
					value_wiki = value
		if !value_str:
			continue
		var label: String = show_datum[1]
		if body:
			if label == "LABEL_PERIAPSIS":
				var parent := body.get_parent() as Body
				if parent:
					if parent.name == "STAR_SUN":
						label = "LABEL_PERIHELION"
					elif parent.name == "PLANET_EARTH":
						label = "LABEL_PERIGEE"
			elif label == "LABEL_APOAPSIS":
				var parent := body.get_parent() as Body
				if parent:
					if parent.name == "STAR_SUN":
						label = "LABEL_APHELION"
					elif parent.name == "PLANET_EARTH":
						label = "LABEL_APOGEE"
		if enable_wiki_links and datum_size > 7 and show_datum[7] and _wiki_titles.has(label):
			var tr_label := tr(label)
			_meta_lookup[tr_label] = label
			_labels[grid_index].bbcode_text = "[url]" + tr_label + "[/url]"
		else:
			_labels[grid_index].text = tr(label)
		if value_wiki and _wiki_titles.has(value_wiki):
			_meta_lookup[value_str] = value_wiki
			_values[grid_index].bbcode_text = "[url]" + value_str + "[/url]"
		else:
			_values[grid_index].text = value_str
		_labels[grid_index].show()
		_values[grid_index].show()
		grid_index += 1
		if grid_index == max_data_items:
			break
	while grid_index < max_data_items:
		_labels[grid_index].hide()
		_values[grid_index].hide()
		grid_index += 1

func _on_meta_clicked(meta: String) -> void:
	var value_wiki: String = _meta_lookup[meta]
	var url := "https://en.wikipedia.org/wiki/" + tr(_wiki_titles[value_wiki])
	OS.shell_open(url)

func _force_richtextlabel_height() -> void:
	# Arghhh...! As of Godot 3.2.2, RichTextLabel has no height unless min size
	# is specified! Retest using Planetarium to see when we can remove this.
	if !enable_wiki_links:
		return
	yield(get_tree(), "idle_frame") # allows font change before height test
	var font: Font = Global.fonts.gui_main
	var font_height := font.get_height()
	for label_label in _labels:
		label_label.rect_min_size.y = font_height

func _settings_listener(setting: String, _value) -> void:
	match setting:
		"gui_size":
			_force_richtextlabel_height()
