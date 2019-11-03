# body_list.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2019 Charlie Whitfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# *****************************************************************************
#
# WIP
# Manages lists of instanced and "virtual" bodies. Virtual bodies are simply
# names that are instanced only if/when individually selected (eg, our 300000+
# Main Belt asteroids).

extends Reference
class_name BodyList

enum {
	SORT_NO_SORT, # leave as is, eg, from a data table
	SORT_DEFAULT,
	SORT_ASTEROIDS
	}

var list_name: String
var body_names: Array
var bodies_by_name := {}

var _instance_builder: Object
var _sort_type: int
#var _asteroid_integers: Dictionary

# persistence
const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["list_name", "body_names", "_sort_type"]
const PERSIST_OBJ_PROPERTIES := ["bodies_by_name", "_instance_builder"]

func init_virtual_bodies(list_name_: String, sort_type := SORT_DEFAULT, body_names_ := [], instance_builder: Object = null) -> void:
	# body_names_ is kept & modified
	list_name = list_name_
	_instance_builder = instance_builder
	_sort_type = sort_type
	body_names = body_names_
	match sort_type:
		SORT_DEFAULT:
			body_names.sort()
		SORT_ASTEROIDS:
			body_names.sort_custom(self, "_sort_asteroids")

func init_bodies(list_name_: String, sort_type := SORT_DEFAULT, bodies := [], instance_builder: Object = null) -> void:
	# bodies is released w/out modification
	list_name = list_name_
	_instance_builder = instance_builder
	_sort_type = sort_type
	body_names = []
	for body in bodies:
		var name: String = body.name
		assert(!bodies_by_name.has(name))
		body_names.append(name)
		bodies_by_name[name] = body
	match sort_type:
		SORT_DEFAULT:
			body_names.sort()
		SORT_ASTEROIDS:
			body_names.sort_custom(self, "_sort_asteroids")

func add_body(_body: Body) -> void:
	pass

func add_virtual_body(_body_name: String) -> void:
	pass

func remove_body(_body: Body) -> void:
	pass

func remove_virtual_body(_body_name: String) -> void:
	pass


# warning-ignore:unused_argument
func select(body_name: String, selection_manager: SelectionManager) -> void:
# warning-ignore:unused_variable
	var body: Body
	if bodies_by_name.has(body_name):
		body = bodies_by_name[body_name]
	else:
		prints(body_name, "selected!")
		return
#		body = _builder.make_body(body_name)
#	selection_manager.select(selection_item)


func _sort_asteroids(a: String, b: String) -> bool:
	# Sort on id, if this is "id [name]" format, but sort alphabetically if
	# string is "year letters digits" format.
	return a < b


