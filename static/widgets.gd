# widgets.gd
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
class_name IVWidgets
extends Object

# Utility static functions for widgets.

# TODO34: DEPRECIATE? Make static func in IVSelectionManager, assuming self reference ok.

static func get_selection_manager(control: Control) -> IVSelectionManager:
	var ancestor: Node = control.get_parent()
	while ancestor is Control:
		if "selection_manager" in ancestor:
			var selection_manager: IVSelectionManager = ancestor.selection_manager
			if selection_manager:
				return selection_manager
		ancestor = ancestor.get_parent()
	return null
