# wiki_subinfo.gd
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

extends InfoSubpanel
class_name InfoSubpanelWiki
const SCENE := "res://ivoyager/gui_in_game/info_subpanel_wiki.tscn"

const BUTTON_TEXT := "BUTTON_WIKI"

var header_text := "" # expected by InfoPanel

static func get_availability(selection_manager_: SelectionManager) -> int:
	if Global.table_data.wiki_keys.has(selection_manager_.get_name()):
		return AVAILABLE
	return DISABLED

func init_selection() -> void:
	var selection_manager_: SelectionManager = owner.selection_manager
	var object_key = selection_manager_.get_name()
	var wiki_keys = Global.table_data.wiki_keys
	if wiki_keys.has(object_key):
		$ScrollContainer/ScrollText.text = wiki_keys[object_key]
		header_text = tr("LABEL_WIKIPEDIA") + " - " + tr(object_key)
