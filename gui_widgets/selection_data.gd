# selection_buttons.gd
# This file is part of I, Voyager
# https://ivoyager.dev
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

extends GridContainer

var col1_width := 100
var col2_width := 100

var show_data := [
	# [property, label, option_type]; only REAL values use [2], [3] elements
	# We look first in SelectionItem, then Body if SelectionItem.is_body
	# Integer value -1 and float value -INF are not displayed; float value INF
	# displayed as "?".
	["classification", "LABEL_CLASSIFICATION"],
	["mass", "LABEL_MASS", QtyStrings.MASS_G_KG],
	["esc_vel", "LABEL_ESCAPE_VELOCITY", QtyStrings.VELOCITY_MPS_KMPS],
	["density", "LABEL_DENSITY", QtyStrings.UNIT, "g/cm^3"],
	["albedo", "LABEL_ALBEDO"],
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
onready var _labels: Label = $Labels
onready var _values: Label = $Values
var _selection_manager: SelectionManager

func _ready():
	Global.connect("system_tree_ready", self, "_on_system_tree_ready", [], CONNECT_ONESHOT)

func _on_system_tree_ready(_is_loaded_game: bool) -> void:
	_selection_manager = GUIUtils.get_selection_manager(self)
	_selection_manager.connect("selection_changed", self, "_on_selection_changed")
	_labels.rect_min_size.x = col1_width
	_values.rect_min_size.x = col2_width
	_on_selection_changed()

func _on_selection_changed() -> void:
	var selection_item := _selection_manager.selection_item
	if !selection_item:
		return
	var body: Body
	if _selection_manager.is_body():
		body = _selection_manager.get_body()
	var labels := ""
	var values := ""
	for show_datum in show_data:
		var property: String = show_datum[0]
		var is_value := true
		var value_variant
		if property in selection_item:
			value_variant = selection_item.get(property)
		elif body and property in body:
			value_variant = body.get(property)
		else:
			is_value = false
		if !is_value:
			continue
		var value: String
		match typeof(value_variant):
			TYPE_INT:
				if value_variant != -1:
					value = str(value_variant)
			TYPE_REAL:
				if value_variant == -INF:
					pass
				elif value_variant == INF:
					value = "?"
				elif show_datum.size() < 3:
					value = str(value_variant)
				else:
					var option_type: int = show_datum[2]
					var unit: String = show_datum[3] if show_datum.size() > 3 else ""
					value = _qty_strings.number_option(value_variant, option_type, unit)
			TYPE_STRING:
				value = tr(value_variant)
		if value:
			var label: String = show_datum[1]
			labels += tr(label) + "\n"
			values += value + "\n"
	_labels.text = labels
	_values.text = values

