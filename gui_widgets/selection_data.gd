# selection_buttons.gd
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
# UI widget. On _ready(), searches up tree for first ancestor with "selection_manager"
# member.

extends GridContainer
class_name SelectionData
const SCENE := "res://ivoyager/gui_widgets/selection_data.tscn"

onready var _string_maker: StringMaker = Global.objects.StringMaker
var _selection_manager: SelectionManager

onready var _show_data := [
	# [property, label, display_type]; only REAL values use 3rd element
	# We look first in SelectionItem, then Body if SelectionItem.is_body
	# Integer value -1 is not displayed.
	["classification", "LABEL_CLASSIFICATION"],
	["mass", "LABEL_MASS", _string_maker.DISPLAY_MASS],
	["esc_vel", "LABEL_ESCAPE_VELOCITY", _string_maker.DISPLAY_VELOCITY],
	["n_stars", "LABEL_STARS"],
	["n_planets", "LABEL_PLANETS"],
	["n_dwarf_planets", "LABEL_DWARF_PLANETS"],
	["n_moons", "LABEL_MOONS"],
	["n_asteroids", "LABEL_ASTEROIDS"],
	["n_comets", "LABEL_COMETS"]
	]

onready var _labels: Label = $Labels
onready var _values: Label = $Values

func _ready():
	var ancestor: Node = get_parent()
	while not "selection_manager" in ancestor:
		ancestor = ancestor.get_parent()
	_selection_manager = ancestor.selection_manager
	_selection_manager.connect("selection_changed", self, "_update")
	_update()

func _update() -> void:
	var selection_item := _selection_manager.selection_item
	if !selection_item:
		return
	var body: Body
	if _selection_manager.is_body():
		body = _selection_manager.get_body()
	var labels := ""
	var values := ""
	for show_datum in _show_data:
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
				var display_type: int = show_datum[2]
				value = _string_maker.get_str(value_variant, display_type)
			TYPE_STRING:
				value = tr(value_variant)
		if value:
			var label: String = show_datum[1]
			labels += tr(label) + "\n"
			values += value + "\n"
	_labels.text = labels
	_values.text = values

