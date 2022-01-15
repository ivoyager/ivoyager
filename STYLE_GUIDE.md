# I, Voyager Style Guide
We adhear to Godot's [GDScript style guide](https://docs.godotengine.org/en/stable/getting_started/scripting/gdscript/gdscript_styleguide.html) with a few changes and additions described here.

## Naming conventions

### 'IV'-prefixing classes and globals
All class names and the two autoload/singletons in the core 'ivoyager' submodule are prefixed with 'IV' to avoid name collisions with embedding projects. We drop this prefix for the names of files, nodes, variables and dictionary indexes that relate to these classes.

### Astronomy over code convention, in isolation
Within certain functions we favor standard orbital mechanics symbols over code convention. For example, in orbit calculations: `var e: float` for eccentricity and `var E: float` for eccentric anomaly. Avoid this for class properties and methods.

### Static function classes assigned to const
Use lower case for local assignment of static function classes to constants:  
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
# Enums, constants first

# persisted
var body_id := -1
var flags := 0
var characteristics := {}
var components := {}
var satellites := []
var lagrange_points := []
var _something_private: float
const PERSIST_AS_PROCEDURAL_OBJECT := true
const PERSIST_PROPERTIES := ["name", "body_id", "flags", "characteristics", "components",
	"satellites", "lagrange_points", "_something_private"]

# Other public, then private vars
```

### Keep init and destructor code together
Keep init and destructor functions together (whether virtual or not) before all other functions.

```
func _init() -> void:
	_on_init()


func _on_init() -> void:
 	# This function can be overriden by a subclass, unlike the virtual
	# function above.
	pass


func _project_init() -> void:
	# This is a 'virtual-like' function called for classes instantiated by
	# IVProjectBuilder before they are added to the tree. It's not a Godot
	# virtual function so subclasses can override.
	pass


func _ready() -> void:
	_on_ready()


func _on_ready() -> void:
	IVGlobal.connect("project_builder_finished", self, "_on_project_builder_finished", [], CONNECT_ONESHOT)
	IVGlobal.connect("simulator_started", self, "_on_simulator_started")
	IVGlobal.connect("simulator_exited", self, "_on_simulator_exited")


func _on_project_builder_finished() -> void:
	pass


func _on_simulator_started() -> void:
	pass


func _on_simulator_exited() -> void:
	pass


# Other virtual functions, then public functions, then private functions...
```

## Static typing
**Always** use static typing except where it is absolutely necessary to use untyped. There are only a couple exceptions in 'ivoyager' involving table reading and settings, where `value` is generally used as var name for an untyped item:
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
