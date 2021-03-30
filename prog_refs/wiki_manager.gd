# wiki_manager.gd
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

class_name WikiManager


var _wiki_titles: Dictionary = Global.wiki_titles
var _wiki_locale: String = Global.wiki_locale


func _project_init() -> void:
	Global.connect("open_wiki_requested", self, "_open_wiki")

func _open_wiki(wiki_title: String) -> void:
	if _wiki_locale == "wiki":
		_open_internal_wiki(wiki_title)
	else:
		var url := "https://" + _wiki_locale + ".org/wiki/" + wiki_title
		OS.shell_open(url)

func _open_internal_wiki(_wiki_title: String) -> void:
	# subclass override
	pass
