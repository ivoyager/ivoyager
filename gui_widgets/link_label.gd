# link_label.gd
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
class_name IVLinkLabel
extends RichTextLabel

# GUI widget. A hyperlink!

var _link_url := "https://www.ivoyager.dev"


func _ready() -> void:
	connect("meta_clicked", self, "_on_meta_clicked")


func set_hyperlink(link_text: String, link_url: String) -> void:
	bbcode_text = "[url]" + link_text + "[/url]"
	_link_url = link_url


func _on_meta_clicked(_meta: String) -> void:
	prints("Opening external link:", _link_url)
	OS.shell_open(_link_url)
