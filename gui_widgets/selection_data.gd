# selection_buttons.gd
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
# GUI widget. Requires Control ancestor with member "selection_manager".
# Certain property values are interpreted as unknown (dispay "?") or not
# applicable (don't display label or value). For floats, these are INF and
# -INF, respectively. For ints: -99 and -1. For strings: "?" and "".
# To find properites, we search first in SelectionItem, then Body, then
# Properties, then Rotations.

# TODO: Mouse-over array.
# TODO: A wiki option for Planetarium (we have wiki_en for classes).

extends GridContainer

# modify these (and rect_min_size) before "system_tree_ready"
var enable_wiki_links := false
var max_data_items := 15
var labels_width := 120
var values_width := 120
var show_data := [
	# [property, label [, modifiers...]]; see code for modifiers
	# displayed as "?".
	["class_type", "LABEL_CLASSIFICATION", "classes", true],
	["m_radius", "LABEL_MEAN_RADIUS", QtyStrings.UNIT, "km"],
	["mass", "LABEL_MASS", QtyStrings.MASS_G_KG],
	["surface_gravity", "LABEL_SURFACE_GRAVITY", QtyStrings.UNIT, "_g"],
	["esc_vel", "LABEL_ESCAPE_VELOCITY", QtyStrings.VELOCITY_MPS_KMPS],
	["density", "LABEL_DENSITY", QtyStrings.UNIT, "g/cm^3"],
	["albedo", "LABEL_ALBEDO", QtyStrings.NUMBER],
	["surf_pres", "LABEL_SURFACE_PRESSURE", QtyStrings.PREFIXED_UNIT, "bar"],
	["surf_t", "LABEL_SURFACE_TEMP", QtyStrings.UNIT, "degC"],
	["min_t", "LABEL_MIN_TEMP", QtyStrings.UNIT, "degC"],
	["max_t", "LABEL_MAX_TEMP", QtyStrings.UNIT, "degC"],
	["one_bar_t", "LABEL_ONE_BAR_TEMP", QtyStrings.UNIT, "degC"],
	["half_bar_t", "LABEL_HALF_BAR_TEMP", QtyStrings.UNIT, "degC"],
	["tenth_bar_t", "LABEL_TENTH_BAR_TEMP", QtyStrings.UNIT, "degC"],
	["n_stars", "LABEL_STARS"],
	["n_planets", "LABEL_PLANETS"],
	["n_dwarf_planets", "LABEL_DWARF_PLANETS"],
	["n_moons", "LABEL_MOONS"],
	["n_asteroids", "LABEL_ASTEROIDS"],
	["n_comets", "LABEL_COMETS"]
]

onready var _qty_strings: QtyStrings = Global.program.QtyStrings
var _table_data: Dictionary = Global.table_data
var _wiki_titles: Dictionary = Global.wiki_titles
var _selection_manager: SelectionManager
var _labels := []
var _values := []
var _meta_lookup := {}

func _ready():
	Global.connect("system_tree_ready", self, "_on_system_tree_ready", [], CONNECT_ONESHOT)

func _on_system_tree_ready(_is_loaded_game: bool) -> void:
	_selection_manager = GUIUtils.get_selection_manager(self)
	_selection_manager.connect("selection_changed", self, "_on_selection_changed")
	var grid_index := 0
	while grid_index < max_data_items:
		var label_label := Label.new()
		label_label.rect_min_size.x = labels_width
		label_label.clip_text = true
		label_label.hide()
		_labels.append(label_label)
		add_child(label_label)
		if enable_wiki_links:
			var value_label := RichTextLabel.new()
			value_label.rect_min_size.x = values_width
			value_label.scroll_active = false
			value_label.bbcode_enabled = true
			value_label.connect("meta_clicked", self, "_on_meta_clicked")
			value_label.hide()
			_values.append(value_label)
			add_child(value_label)
		else:
			var value_label := Label.new()
			value_label.rect_min_size.x = values_width
			value_label.clip_text = true
			value_label.hide()
			_values.append(value_label)
			add_child(value_label)
		grid_index += 1
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
		var is_value := true
		var value # untyped!
		if property in selection_item:
			value = selection_item.get(property)
		elif body and property in body:
			value = body.get(property)
		else:
			is_value = false
		if !is_value:
			continue
		var display_str: String
		var wiki_key := ""
		match typeof(value):
			TYPE_INT:
				if value == -99:
					display_str = "?"
				elif value == -1:
					pass
				elif show_datum.size() > 2:
					var table_name: String = show_datum[2]
					var data: Array = _table_data[table_name]
					var row_key: String = data[value][0]
					display_str = tr(row_key)
					if enable_wiki_links and show_datum.size() > 3 and show_datum[3]:
						wiki_key = row_key
				else:
					display_str = str(value)
			TYPE_REAL:
				if value == INF:
					display_str = "?"
				elif value == -INF:
					pass
				elif show_datum.size() < 3:
					display_str = str(value)
				else:
					var option_type: int = show_datum[2]
					var unit: String = show_datum[3] if show_datum.size() > 3 else ""
					display_str = _qty_strings.number_option(value, option_type, unit)
			TYPE_STRING:
				display_str = tr(value)
		if !display_str:
			continue
		var label: String = show_datum[1]
		_labels[grid_index].text = tr(label)
		if wiki_key and _wiki_titles.has(wiki_key):
			_meta_lookup[display_str] = wiki_key
			_values[grid_index].bbcode_text = "[url]" + display_str + "[/url]"
		else:
			_values[grid_index].text = display_str
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
	var wiki_key: String = _meta_lookup[meta]
	var url := "https://en.wikipedia.org/wiki/" + tr(_wiki_titles[wiki_key])
	OS.shell_open(url)
