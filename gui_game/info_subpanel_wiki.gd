# wiki_subinfo.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2019 Charlie Whitfield
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
#

extends InfoSubpanel
class_name InfoSubpanelWiki
const SCENE := "res://ivoyager/gui_game/info_subpanel_wiki.tscn"

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
