# translation_importer.gd
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
# We report key duplicates and process text under the following conditions:
#
#   1. Translation is not added by editor (i.e., not in project.godot).
#   2. Translation path is added to Global.translations.
#   3. Translation are reimported with compress OFF (compress=false in *.import file).
#
# Processing modifications:
#
#   1. Interpret unicode escape "\uHHHH" (patches Godot issue #38716)
#

class_name TranslationImporter

func _init():
	_load_translations()
	Global.emit_signal("translations_imported")
	Global.program.erase("TranslationImporter") # this Reference will free itself

func _load_translations() -> void:
	var load_dict := {}
	var duplications := []
	for tr_path in Global.translations:
		var translation: Translation = load(tr_path)
		if translation is PHashTranslation:
			# Note: PHashTranslation doesn't work in add_translation in export
			# project. Godot issue #38935.
#			var compressed_tr := PHashTranslation.new()
#			compressed_tr.generate(translation)
#			TranslationServer.add_translation(compressed_tr)
			TranslationServer.add_translation(translation)
		else:
			load_dict[translation] = tr_path
			_process_translation(translation, load_dict, duplications)
			TranslationServer.add_translation(translation)
	if duplications:
		print("WARNING! Duplication(s) found in translations; kept 1st:")
		for duplication in duplications:
			var key: String = duplication[0]
			var tr1: Translation = duplication[1]
			var tr2: Translation = duplication[2]
			prints(" ", key, load_dict[tr1])
			prints(" ", key, load_dict[tr2])

func _process_translation(translation: Translation,	load_dict: Dictionary,
		duplications: Array) -> void:
	for txt_key in translation.get_message_list():
		# Duplicate test.
		if load_dict.has(txt_key):
			var duplication := [txt_key, load_dict[txt_key], translation]
			duplications.append(duplication)
			continue
		load_dict[txt_key] = translation
		var text: String = translation.get_message(txt_key)
		# Patch for Godot issue #38716 not understanding "\uXXXX".
		var new_text := StrUtils.c_unescape_patch(text)
		if new_text != text:
			translation.add_message(txt_key, new_text)
