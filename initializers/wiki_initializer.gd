# wiki_initializer.gd
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
class_name IVWikiInitializer
extends RefCounted

# FIXME or DEPRECIATE: IVGlobal 'wiki' settings don't do anything now. We need
# to figure out how to do localization.
# Many loose ends after shift to Table Importer plugin...

func _init() -> void:
	_on_init()
	
	
func _on_init() -> void:
	if !IVGlobal.enable_wiki:
		return
	if IVGlobal.use_internal_wiki:
		IVGlobal.wiki = "wiki"
	else:
		var locale := TranslationServer.get_locale()
		if IVGlobal.wikipedia_locales.has(locale):
			IVGlobal.wiki = locale + ".wikipedia"
		else:
			IVGlobal.wiki = "en.wikipedia"


func _project_init() -> void:
	IVGlobal.program.erase(&"WikiInitializer") # frees self

