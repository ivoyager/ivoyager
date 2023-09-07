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

# Postprocess tables specified in IVGlobal using Table Reader plugin.
# Table data will be ready to use after 'data_tables_imported' signal, which
# will happen while 'initializers' are added in ProjectBuilder.


func _init() -> void:
	
	IVTableData.postprocess_tables(IVGlobal.postprocess_tables, IVGlobal.table_project_enums,
			IVUnits.multipliers, IVUnits.lambdas, IVGlobal.enable_wiki, IVGlobal.enable_precisions)
	
	# signal done
	IVGlobal.data_tables_imported.emit()


func _project_init() -> void:
	IVGlobal.program.erase("TableInitializer") # frees self

