# table_importer_temp.gd
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
extends RefCounted


const TableResource := preload("res://ivoyager/tables_temp/table_resource.gd")



func import(table_paths: Array[String], table_resources: Dictionary) -> void:
	# DEPRECIATE: This is needed until we have a real editor importer.

	for path in table_paths:
		var table_res := TableResource.new()
		table_res.import_table(path)
		table_resources[table_res.table_name] = table_res


