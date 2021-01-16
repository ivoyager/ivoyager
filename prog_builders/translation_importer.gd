# translation_importer.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
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
# We can do some processing on translations under the following conditions:
#   1. They are not added by editor (i.e., not in project.godot).
#   2. Their paths are added to Global.translations.
#   3. They are reimported with compress OFF (compress=false in *.import file).
#
# E.g., We can patch Godot issue #38716 to interpret unicode escape "\uHHHH". 

class_name TranslationImporter

func project_init() -> void:
	pass

func _init():
	_load_translations()

func _load_translations() -> void:
	for tr_path in Global.translations:
		var translation: Translation = load(tr_path)
		if translation is PHashTranslation:
			TranslationServer.add_translation(translation)
		else:
			_process_translation(translation)
			# Note: PHashTranslation doesn't work in add_translation in export
			# project. Godot issue #38935.
#			var compressed_tr := PHashTranslation.new()
#			compressed_tr.generate(translation)
#			TranslationServer.add_translation(compressed_tr)
			TranslationServer.add_translation(translation)

func _process_translation(translation: Translation) -> void:
	# Patch for Godot issue #38716 not understanding "\uXXXX".
	for txt_key in translation.get_message_list():
		var text: String = translation.get_message(txt_key)
		var new_text := StrUtils.c_unescape_patch(text)
		if new_text != text:
			translation.add_message(txt_key, new_text)
	
