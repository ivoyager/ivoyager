# table_initializer.gd
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
class_name IVTableInitializer
extends RefCounted

# Loads tables specified in IVGlobal.


func _init() -> void:
	_on_init()


func _on_init() -> void:
	
	# temp import
	var table_import := IVGlobal.table_import
	var table_array := table_import.values()
	table_array.append("res://ivoyager/data/solar_system/wiki_extras.tsv")
	table_array.append("res://ivoyager/data/solar_system/test_enumeration.tsv")
	table_array.append("res://ivoyager/data/solar_system/test_mod.tsv")
	table_array.append("res://ivoyager/data/solar_system/test_enum_x_enum.tsv")
	
	
	IVTableData.import_tables(table_array)
	
	# temp process
	var table_names := table_import.keys()
	table_names.append("wiki_extras")
	table_names.append("test_enumeration")
	table_names.append("test_mod")
	table_names.append("test_enum_x_enum")
	var table_enums := [
		IVEnums.SBGClass,
		IVEnums.Confidence,
		IVEnums.BodyFlags,
	]
	IVTableData.process_table_data(table_names, table_enums, IVUnits.multipliers, IVUnits.lambdas,
			true, true)
	
	
	IVGlobal.data_tables_imported.emit()


func _project_init() -> void:
	IVGlobal.program.erase("TableInitializer") # frees self

