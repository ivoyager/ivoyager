# I, Voyager Style Guide
We adhear to Godot's [GDScript style guide](https://docs.godotengine.org/en/stable/getting_started/scripting/gdscript/gdscript_styleguide.html) with a few project-specific changes or additions described here.

## Naming conventions
### 'IV'-prefixing classes and globals
All class names and the two autoload/singletons in the core 'ivoyager' submodule are prefixed with 'IV' to avoid name collisions with embedding projects. We drop this prefix for the names of files, nodes, variables and dictionary indexes that relate to these classes.

### Static classes assigned to const
Use lower case for local assignment of static classes to constants:  
```const math := preload("res://ivoyager/static/math.gd")```

## Code order

### const SCENE
Scenes instantiated by IVProjectBuilder require const SCENE defining path. Keep this at top of file right under `extends`:
```
# File name and licence header
# *****************************************************************************
class_name IVSaveDialog
extends FileDialog
const SCENE := "res://ivoyager/gui_admin/save_dialog.tscn"

# Class comments
```
### Persisted variable blocks
I, Voyager's save/load system uses two constants to identify object properties to persist. Keep persisted variables together with these constants in a unified block:
```
# persisted
var body_id := -1
var flags := 0
var characteristics := {}
var components := {}
var satellites := []
var lagrange_points := []

const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["name", "body_id", "flags", "characteristics", "components",
	"satellites", "lagrange_points"]
```

### IVProjectBuilder virtual-like functions
There are two virtual-like functions for classes instantiated by IVProjectBuilder: `_extention_init()` and `_project_init()`. Keep these at the top of functions with Godot's virtual functions. They logically follow `_init()`.

### Overridable virtual substitute functions
Because Godot virtual functions are not overridable by subclasses, we often "pass-through" to functions that can be overridden. Order these substitute functions after the virtual functions that they replace. E.g.:
```
func _init() -> void:
	_on_init()


func _on_init() -> void:
	# overridable code


func _ready() -> void:
	_on_ready()


func _on_ready() -> void:
	# overridable code
```

## Static typing
Use static typing **everywhere** except where it is absolutely necessary to used an untyped varible. There are only a couple exceptions in 'ivoyager' involving table reading and settings, where `value` is generally used as var name for an untyped item:
```
func _on_ready() -> void:
	IVGlobal.connect("setting_changed", self, "_settings_listener")


func _settings_listener(setting: String, value) -> void:
	match setting:
		"planet_orbit_color":
			if flags & BodyFlags.IS_TRUE_PLANET and hud_orbit:
				hud_orbit.change_color(value)
		"dwarf_planet_orbit_color":
			if flags & BodyFlags.IS_DWARF_PLANET and hud_orbit:
				hud_orbit.change_color(value)
```
