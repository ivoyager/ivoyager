# Changelog

This file documents changes to the core submodule (ivoyager) and core assets (ivoyager_assets directory). Core assets are not Git-tracked and must be downloaded from official releases [here](https://github.com/ivoyager/ivoyager/releases) or non-release development assets [here](https://github.com/ivoyager/non_release_assets/releases).

File format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

See cloning and downloading instructions [here](https://www.ivoyager.dev/developers/).

## [v0.0.13] - Unreleased

Currently under development using Godot 3.5. Requres 3.5 for new Time API! 0.0.13 release coming soon!

Requires non-Git-tracked **ivoyager_assets-0.0.10**; find in [ivoyager releases](https://github.com/ivoyager/ivoyager/releases).

### Added
* Optional 'Prefix' header row in table.tsv import. Allows reduction of 'PLANET_MERCURY', 'PLANET_VENUS', 'PLANET_EARTH' to 'MERCURY', 'VENUS', 'EARTH' by setting Prefix to 'PLANET_'.

### Changed
* [Breaks API!] Renamed the core selection object ('IVSelectionItem' to 'IVSelection') and redesigned to be dynamically generated and more easily extensible. IVSelection is a wrapper object that can be extended to hold anything; IVSelectionManager keeps history of previous selections. (In core ivoyager we only select IVBody instances.)
* [Breaks API!] Removed IVBodyRegistry. Selection related functions moved to IVSelectionManager. Containers 'top_bodies' and 'selections' moved to IVGlobal.
* [Breaks API!] Save/load system made more intuitive with new object persist const 'PERSIST_MODE' with values NO_PERSIST, PERSIST_PROPERTIES_ONLY and PERSIST_PROCEDURAL.
* [Breaks API!] Various changes to IVTableReader API. Overhauled table import system to allow quick, direct access of typed table data via IVGlobal dictionaries.
* [Breaks API!] Removed IVGlobal.table_types and renamed IVGlobal.table_precisions -> IVGlobal.precisions
* [Breaks data tables!] Data table column field 'Comment' disallowed. You can now make any column a comment column by prepending the field name with # (e.g., '#comment').
* [Breaks data tables!] Data tables were simplified with only four types now: Type = 'BOOL', 'STRING', 'REAL' and 'INT'. The 'INT' type handles enumerations including data table row names (e.g., 'PLANET_EARTH' resolves to 2 because it is row 2 in planets.tsv) and enums listed in IVTableImporter.data_table_enums.
* IVView object now includes HUDs visibility states (orbits, names, icons, and asteroid points).
* Changes to IVProjectBuilder to improve extensibility.
* Updated and improved extension comments in project_builder.gd and elsewhere.
* Some time related code updated from OS to Time (OS methods depreciated). [Requres Godot 3.5!]

### Removed
* [Breaks API!] Removed IVViewCacher from 'ivoyager' submodule. (Added to Planetarium project.)
* [Breaks API!] Removed IVBody.body_id.
* [Breaks API!] Removed IVGlobal.static_enums_class.

### Fixed
* Widgets fixed to work if GUI is added after solar system build.
* Fixed IVTableImporter to print correct cell counts during data table reading.
* Fixed bug causing Pluto "north" flippage under some init circumstances.


## [v0.0.12] - 2022-01-20

Developed using Godot 3.4.2.stable.

Requires non-Git-tracked **ivoyager_assets-0.0.10**; find in [ivoyager releases](https://github.com/ivoyager/ivoyager/releases).

### Added
* Can start with cached time (including speed & time reversal). Used by Planetarium.

### Changed - API-breaking!
* Renamed imported tables (*.tsv) data type from 'DATA' to 'TABLE_ROW'. Also changed some related function names in IVTableReader.

### Fixed
* Fixed bug where start body wasn't updated in GUI when using IVViewCacher.

## [v0.0.11] - 2022-01-19

Developed using Godot 3.4.2.stable.

Requires non-Git-tracked **ivoyager_assets-0.0.10**; find in [ivoyager releases](https://github.com/ivoyager/ivoyager/releases).

### Added
* New [STYLE_GUIDE.md](https://github.com/ivoyager/ivoyager/blob/master/STYLE_GUIDE.md) documents the (very few) departures from Godot's GDScript style guide.
* New IVWindowManager handles fullscreen toggle and optionally adds main menu button.

### Changed - Project Integration
* Prefixed all 'ivoyager' classes and global names with 'IV'. This is to prevent name collisions with embedding projects. Unchanged: file names, node names (except 2 singletons), and container indexes (e.g., it's now 'IVGlobal.program.StateManager', not 'IVGlobal.program.IVStateManager')
* Submodule now depends on external static class SIBaseUnits with SI base units (previously in universe.gd). We keep this file external to 'ivoyager' so projects can change the scale const METER.
* universe.tscn & universe.gd were external (project-level outside of 'ivoyager') but have been moved internally to ivoyager/tree_nodes/. They act as default simulator root and main scene (as set by Project Template; this can be changed).
* Removed gui_example directory from the submodule. Moved externally to Project Template.

### Changed - API-breaking!
* Renamed IVUnits.conv() to convert_quantity() and changed function signature.
* Removed IVInputHandler. All input now handled by target classes.
* IVSelectionManager changed from Reference to Node. ProjectGUI needs to add it as child now.
* IVGlobal signal changes:
    * Renamed 'gui_update_needed' to 'gui_update_requested'
	* Signature change in 'show_hide_gui_requested'
	* Removed 'toggle_show_hide_gui_requested'

### Changed
* Improved integration with SceneTree.paused (we no longer have our own separate pause).
* Camera now re-levels itself and re-centers the target on object selection.

## [v0.0.10] - 2022-01-09

Developed using Godot 3.4.2.stable.

Requires non-Git-tracked **ivoyager_assets-0.0.10**; find in [ivoyager releases](https://github.com/ivoyager/ivoyager/releases).

### Fixed
* Images are now imported with `repeat` on (required for mipmaps to work).
* Set vertex compression off to fix broken models on HTML export in Godot 3.4.1 & 3.4.2.

## [v0.0.9] - 2021-04-29

Developed using Godot 3.3.

Requires non-Git-tracked **ivoyager_assets-0.0.9**; find in [ivoyager releases](https://github.com/ivoyager/ivoyager/releases).

### Project integration changes
The first two will break external projects using the ivoyager submodule! Make changes as needed.
* [project breaking!] The Universe node was moved from the ivoyager submodule to the top level project directory. External projects can now add scenes to the simulator root node in the editor (before you could do this only by code).
* [project breaking!] [universe.gd](https://github.com/ivoyager/project_template/blob/master/universe.gd) now has the constants that define base SI units. By "externalizing" this, external projects can now change simulator internal representation of values (in particular, METER, which sets the scale of the simulation).
* We are no longer maintaining a "web-deployment" branch for the Planetarium. Instead, the master branch *is* the web deployment (e.g., it uses GLES2). Basically, our [Web Planetarium](https://www.ivoyager.dev/planetarium/) has become our main "product." You can still switch to GLES3 and export a functioning Windows app.
* Solar system data tables are now tab delineated .tsv files rather than .csv. The switch was needed for [this](https://github.com/godotengine/godot/issues/47061) Godot issue, but it's a good switch anyway. Tabs are easy to add within a cell using "\t", so we no longer need quote-enclosed cells to deal with our delineator.
* After years of frustration with Excel "interpreting" and modifying table values (e.g., changing the Sun's GM from 1.32712440018e20 to 1.33E+20) and trying to thwart that with preventative prefixes (but missing cases) I have switched to a new .csv/.tsv editor: [Ron's CSV Editor](https://www.ronsplace.eu/Products/RonsEditor/Download). So far, it's working superbly! The consequence, however, is that I'm no longer trying to maintain "Excel-safety" in our data tables, so .tsv files opened and saved in Excel will be ruined in many cases.

### Added
* New IOManager manages a separate thread for I/O including resource loading and other file reading/writing. All functions are called on the Main thread if external project sets Global.enable_threads = false.
* Many new "something_requested" signals in [Global](https://github.com/ivoyager/ivoyager/blob/master/singletons/global.gd). These can be used in lieu of direct calls to most functions in StateManager and SaveManager (and others).
* Expanded API in [Body](https://github.com/ivoyager/ivoyager/blob/master/tree_nodes/body.gd) and [Orbit](https://github.com/ivoyager/ivoyager/blob/master/tree_refs/orbit.gd) classes.
* Expanded data display for all astronomical bodies with closeable sections and subsections. (Content can be customized by external project.)
* Expanded wiki links for many data display labels and items (must be enabled, as is the case for the Planetarium).
* Added new Composition object. The new Body.components dictionary can hold any number of Composition instances representing anything. (I, Voyager uses for atmosphere chemical composition for display.)
* Added [data/solar_system/TABLES_README.txt](https://github.com/ivoyager/ivoyager/blob/master/data/solar_system/TABLES_README.txt) with info and rules for our data table system.
* Added capability for language localized Wikipedia links. All someone needs to do is add a table column "es.wikipedia", "de.wikipedia", etc., and add "es", "de", etc., to Global.wikipedia_locales.
* Added capability for an internal game wiki (a la Civilopedia). For this, add table column "wiki" and set Global.use_internal_wiki.

### Changes
* External project can set root node of the simulation by setting ProjectBuilder property "universe".
* Better feedback from save/load system for checking game-state consistency.
* "Program nodes" are now children of Universe rather than Global. All nodes with persist data are now under Universe, which helps with recent save/load changes.
* Non-HTML5 Planetarium now has a boot screen.
* Moved pale_blue_dot.png to project directory level. It's boot image for our projects, but now easier to remove for external project developers.
* Smoother progress bar progress during start and load. It's now linked to tasks completed by I/O thread.
* Body object reorganized with most properties moved to new "characteristics" dictionary (for non-object properties) or "components" dictionary (for objects).
* Improvements to SaveBuilder encoding of objects; SaveBuilder optimizations.
* Moved remaining init code from Global to several new initializer classes. This is better organization and allows extension projects to modify.

### API-breaking changes
* Class renamings:
    * QtyStrings -> QtyTxtConverter
    * ModelGeometry -> ModelController (maintains data related to body orientation in space)
    * SaverLoader -> SaveBuilder (also changed API substantially)
* Class split: new SaveManager has save/load related functions previously in StateManager.
* Removed class "Properties" (was subsequently renamed "BodyCharacteristics" before removal). Replaced by Body.characteristics dictionary.
* Many Body properties were moved into Body.characteristics dictionary.
* Function name changes in StateManager.
* Moved init related signals from ProjectBuilder to Global.
* Renamed Global signal "gui_refresh_requested" -> "update_gui_needed".
* Added leading underscore to ivoyager "virtual" functions: `_extension_init()` and `_project_init()`. (Note: subclasses can override, unlike Godot virtual functions.)
* Changes in TableReader "build_" function signatures; renamed "conv_" functions to "convert_".
* Renamed ProjectBuilder dictionaries to be more consistent with file system directories.
* Removed Global arrays "camera_info" and "mouse_target". Info from these are contained in new VisualsHelper class.

### Bug fixes
* Fixes to mouse_filter in various GUIs (was preventing selection of Iapetus).
* Fixed bug in SelectionData widget that allowed it to proliferate Labels on each game load without clearing.
* Fixed "?" display for moon masses.
* Fixed bug preventing "Top" view from showing whole system.
* Various get function errors in Body and Orbit were identified and fixed while expanding data display.
* Fixed lat/long display bugs.
* Fixed various problems related to retrograde orbit or rotation.
* Fixed some precision (significant digits) errors in data display.
* Fixed bug causing moons to flicker or disappear at high game speeds.


## [v0.0.8] - 2021-02-10
Developed using **Godot 3.2.3** (tested & seems ok in 3.2.4-rc1)

Requires non-Git-tracked **ivoyager_assets-0.0.7**; find it in [ivoyager releases](https://github.com/ivoyager/ivoyager/releases).

**Repository changes!** I changed the names of the two "project" repositories, shortening to just "planetarium" and "project_template". The old URLs will continue to work so nothing should break. I deleated both the "issues" and "downloads" repositories (this was bad practice). Issues and downloads are now found in their respective project or submodule repositories, although the vast majority of issues will involve the submodule [here](https://github.com/ivoyager/ivoyager/issues).

### Added
* Network sync capability added in StateManager, Timekeeper and Body for multiplayer support. (Note: We won't have a NetworkLobby in core ivoyager, since that is very application-specific. But core will have signals and rpc calls to keep a network game synched on the solar system side.)
* Added [Scheduler](https://github.com/ivoyager/ivoyager/blob/master/prog_refs/scheduler.gd). This allows you to easily connect to signals that fire on simulator time intervals (which function caller can specify). I, Voyager uses this to update Orbit instances based on evolving orbital elements (precessions, etc.).
* New MDFileLabel widget can read an .md file and convert (some) markdown codes to BBCode. It's narrowly coded now to read ivoyager/CREDITS.md for in-app display, but it could be improved to read more markdown codes.
* Added mouse-cursor-shape feedback (pointy finger, etc.) for main 3d screen selectables and some GUI elements.
* Hints for all GUI input controls.
* Added time setting functionality in Planetarium (using TimeSetPopup + TimeSetter widget in core ivoyager).

### Changes
* Updates to README.md, CREDITS.md, LICENCE.txt, and export_presets.cfg.
* Standardized useage of NAN to mean missing or not applicable (don't display) and INF to mean applicable but unknown (display as "?"). This affects return of TableReader functions for float values.
* TranslationImporter reports duplicate text keys.
* Improved 3d body mouse-click selection and screen drags. These functions now happen in ProjectionSurface (removed obsolete MouseClickSelector).

### API-breaking changes
* Debug is no longer a singleton node! It's now a static Reference class. This must be updated in your project.godot file, or Editor/settings/autoload, if you use ivoyager submodule in your own project! (Also removed Debug functions that probably weren't used by anyone.)
* Many enums renamed (for internal consistency)
* Class renames:
    * Registrar -> BodyRegistry
    * HUD2dSurface -> ProjectionSurface
* Overhauled Timekeeper API to more correctly use Julian Day Number, Julian Day, UT, etc.
* ContainerSized, ContainerDraggable & ContainerDynamic generalized to modify Control parent and renamed ControlSized, ControlDraggable & ControlDynamic

### Bug fixes
* Fixed bug preventing hotkey action removal (when not replaced)


## [v0.0.7] - 2021-01-22
Developed using Godot **3.2.3** (not yet tested in 3.2.4 betas)

Requires non-Git-tracked **ivoyager_assets-0.0.7**; find it in [ivoyager releases](https://github.com/ivoyager/ivoyager/releases).

### General Update
The project was on hiatus for much of the second half of 2020, but we are back for 2021! We remain in "alpha" so expect many API breaking changes (although I try to document those here). I suspect that will be the case until Godot 4.0 release. After that, perhaps in mid- to late 2021, we'll release our "beta" and then move on to official "1.0" release. Our API should be reasonably stable with the beta release.

### Added
* Latitude & longitude GUI.
* Camera can track orbit (as before) or track ground (**new!**) or neither (camera stays fixed in space relative to its parent object). This is a super cool feature for observing our Moon's libration and Mercury's crazy terminator reversal!
* A new directory (ivoyager/gui_mods/) includes drag-and-drop components that modify GUI operation:
   * ContainerSized - Can be added to a PanelContainer to provide resize when user changes Options/GUI Size. Used in Project Template.
   * ContainerDraggable - Replaces above; provides above function and makes panel draggable (has settable snap settings). Used in Planetarium.
   * ContainerDynamic - Replaces above; provides above function and makes panel user-resizable via margin drag.
   * PanelLockVisibleCkbx - Allows panel to hide when mouse is not over or near it. A checkbox allows the user to lock it in visible state. Used in Planetarium.
   * ProjectCyclablePanels - Allows a key action to cycle-through panels, making them visible (if hidden due to mod above) and grabbing focus. Used in Planetarium.
* Many new GUI widgets in ivoyager/gui_widgets/ directory. Names are mostly self-explanitory if you've used the Template Project and the Planetarium.
* Added hint tooltips on mouse-over for most buttons, checkboxes, etc.

### Changes
* **Huge improvements to GUI modularity!** I, Voyager GUI widgets are now drag-and-drop for building custom GUI scene trees. Widgets include dynamic labels and textures (e.g., RangeLabel, DateTimeLabel, SelectionImage) and user controls (e.g., SpeedButtons, OrbitsNamesSymbolsCkbxs, PlanetMoonButtons) that plug into I, Voyager core systems.
* Overhauled GUI for both the game template example (ivoyager/gui_example/example_game_gui.tcsn) and the Planetarium (planetarium/gui/pl_gui.tscn in the Planetarium repository) using the new modular widgets and mods.
* Translations are loaded from Global.translations so extensions can add w/out access to project.godot.
* Unicode escape using \uHHHH (where HHHH is a hexidecimal value) can now be used in data table files and localized text files. To make this work for localized text, text.csv files must be reimported with compress OFF. (This is a GDScript patch until Godot issue [#38716](https://github.com/godotengine/godot/issues/38716) gets fixed.)
* Improvements to graphics and graphic import settings.

### API-breaking changes
* Many class renamings.
* Many existing GUI widgets were depreciated in favor of new, more modular widgets.
* Game template example GUI is now in directory ivoyager/gui_example/.
* Removed gui_planetarium directory from ivoyager submodule. The planetarium extension project now contains its own GUI.

### Bug fixes
* Fixed visibility issues related to recent Godot versions.
* [Assets hotfix 0.0.6a] Resized images that weren't a power-of-2 size (throws errors in HTML5 builds).
* [Assets hotfix 0.0.6a] Fixed some import settings: flags/srgb ON for 3D assets, OFF for 2D; Mipmaps ON for everything (was off for 2D).
* Fixed stray node after opening Credits.
* Fixes for fullscreen toggle in Planetarium (HTML5 projects)


## [v0.0.6] - 2020-05-13
Godot version: **3.2.1**

Use **ivoyager_assets-0.0.6a**: [download](https://github.com/ivoyager/ivoyager/releases/download/v0.0.6-alpha/ivoyager_assets-0.0.6a.zip). (This is an asset hotfix documented in the next changelog.)

* Note 1: There is a lot of API-breakage lately! I want to do that now before we go to official beta.
* Note 2: We changed the main scene to Universe! If you update the ivoyager submodule in your own project, you will need to change two settings in project.godot manually (I don't know why there are two! and for some reason, the 2nd doesn't update when changed from editor):
   * run/main_scene="res://ivoyager/tree_nodes/universe.tscn"
   * main_scene="res://ivoyager/tree_nodes/universe.tscn" (this one didn't update from the editor!)

### Added
* Added small moon 3d models: Phobos, Deimos, Hyperion (plus a couple asteroids but you can't visit these yet).
* More planetary data (surface atmos pressure, surface temp, etc.).
* Added static class UnitDefs (static/unit_defs.gd) that defines base and derived units, and all simulator internal representation. It provides constants, dictionaries and functions for unit conversion.
* Added class QtyStrings (program_refs/qty_strings.gd) for generating GUI quantity strings with units. User specifies display units and other options, but does not need to know sim internal units. For example, functions can be called to display an internal mass property in pure SI form "3.00x10^15 kg" or more sci-fi style "3.00 Terratonnes".
* Added class ~~TableHelper~~ TableReader (the old TableReader is now TableImporter). This class provides all table access.
* Added static class Enums (static/enums.gd). Moved enums here that are shared among multiple classes. (Enums used only in one class and its own function signatures still reside in the class.)
* Added Global signals: "about_to_exit", "about_to_quit".
* Added Timekeeper function to get real World GMT time (from user system clock). The Planetarium starts in "real world time" and can be reset to this in the time control GUI.
* Added 3 Global arrays for timekeeping (these supercede Global.time_array). You can grab and keep a reference to these in your class file header (e.g., var clock: Array = Global.clock):
   * Global.times = \[sim_time (SI seconds since J2000), engine_time (accumulated delta), UT1 days] (floats)
   * Global.date = \[year, month, day] (ints)
   * Global.clock = \[hour, minute, second] (ints)
* Added 4 "mouse drag modes" in BCameraInput (program_nodes/viewport_input.gd). There are project vars in ViewportInput that let you hook these up as you want, but by default we have:
   * Left mouse button drag: moves camera around the target body.
   * Shift + any mouse button drag: pitch, yaw
   * Alt + any mouse button drag: roll
   * Cntr + any mouse button OR right button drag: "hybrid" of above two (pitch, yaw if mouse near screen center; roll if near screen edge).
* Added smoothing for camera motions and rotations.
* Added "Universe" as the top Spatial and main scene root. We previously did a scene change after solar system build and when exiting, but now it just stays Universe at all times.
* Added new factory classes (all in ivoyager/program_refs/): EnvironmentBuilder, HUDsBuilder, ModelBuilder, LightBuilder.
* Added data table classes.csv with basic astronomical classifications like G-Type Star, Terrestrial Planet, Gas Giant, C-Type Asteroid, etc. Includes wiki_en title for url linking.
* SelectionData widget shows "classification" from classes.csv table above, and provides option to make these into Wikipedia links (off by default, but Planetarium sets to on).
* Added Body.flags and Enums.BodyFlags. Flag logic supercedes previous boolean members and selection_type (removed).
* Added Body components ~~Rotations~~ ModelManager & Properties (new tree_ref classes). ModelManager handles model rotations and Properties is just a container. Together with Orbit, these define almost everything about Body.
* Implemented decimal precision. Table significant digits are maintained in display, even after import unit conversion and for derived values.
* For external project support, we now have a "fall-through" system for finding models, world maps, icons, body 2D images, and rings. See "search" arrays in Global.
* Added Global.is_gles2 (autodetects).
* Added Global.auto_exposure_enabled (project setting). EnvironmentBuilder sets from Global value.
* First attempt at HDR, auto-exposure, glow/bloom. EnvironmentBuilder, LightBuilder & ModelBuilder attempt to compensate for 3 different scenarios: 1. GLES3, auto_exposure_enabled = true; 2. GLES3, auto_exposure_enabled = false; 3. GLES2.
* Dynamic stars! ModelManager can grow stars (i.e., the Sun) at large distances so they stay visible >2 au out. It also regulates surface emission_engergy dynamically for appropriate auto-exposure effect (i.e., a huge amount at or inside Mercury, strong at Earth, weak at Jupiter, then unnoticeable).
* ModelBuilder now loads "emission" textures. (**Requires new ivoyager_assets-master-2020-05-13!**)
* Added new font "Roboto-NotoSansSymbol-merge.ttf" which is a custom font merge. It has all of our astronomical body symbols plus MANY other useful symbols (an old-fashoned phone, guy at beach, whatever you might need for your game...). (**Requires new ivoyager_assets-master-2020-05-13!**)
### Changes
* Total makeover for Planetarium GUI.
* Recolored the fallback globe model for non-imaged bodies; now grey with whitish lat/long grid.
* Renamed all .csv data tables in data/solar_system/ directory (simplified to "planets.csv", etc.).
* External .csv data table row headers Data_Type, Default_Value & Unit_Conversion changed to DataType, Default & Units. Units row now takes strings such as "km", "au", "1/century", "10^24 kg", "km^3/s^2"; see static/unit_defs.gd for allowed symbols. Data tables no longer need to know sim internal units.
* Data tables accept new DataType 's to assist object building:
   * "DATA" - interpreted as row number (int) of item in any imported data table (e.g., CLASS_G_STAR).
   * "BODY" - interpreted as Body instance by that name (e.g., PLANET_EARTH).
   * Any enum name in the Enums static class (or replacement class specified in Global.enums) - interpreted as enum (int).
* A large chuck of BCamera code was split off into a new class: BCameraInput. The new class handles input not handled by InputHandler or various GUIs (what's left is camera movement control plus viewport click selection).
* BCamera is now fully replaceable with another Camera class in ProjectBuilder (i.e., you don't have to subclass BCamera). See comments in tree_nodes/b_camera.gd for tips on this (you'll still need to match some BCamera API and/or modify some other classes).
* BCamera can now traverse poles. Movement/rotation code is more comprehensible and robust (although a full overhaul to quaternions would be better than existing code).
* Improved distance selection when moving BCamera between bodies of different sizes.
* Lazy init for minor moon models (and uniniting for models not visited for a while). This cuts the number of models at any time from >130 to <30, which is a HUGE improvement for low end graphics computers!
* Directory program_refs split into prog_builders and prog_refs (the former are factory classes, the latter are runtime classes). Also renamed program_nodes -> prog_nodes.
* Labels/Icons were changed to Names/Symbols in the GUI. Both names & symbols display via HUDLabel object. (The old HUDIcon system using a billboard QuadMesh & Texture was removed.)
* Improved star maps.
### API-Breaking Changes
* Removed Global.scale (superseded by UnitDefs.METER). There may be other API breakages related to the units/scaling overhaul.
* All imported data table access is different. See class TableReader (program_refs/table_reader.gd) for table data access.
* Changed Global.enums. It was a dictionary. It now holds a reference to the actual Enums static class. The reason we have a reference in Global is so you can extend Enums class (with your own enums), set Global.enums to it, and then classes can find them (e.g., TableReader).
* Renamed Global.objects -> Global.program. (This holds single instance program_nodes & program_refs.)
* ~~Renamed Global.time_array -> Global.time_date~~ Global.time_array superceded; see Global.times, Global.date, Global.clock above. 
* Renamed Global signals; require_stop_requested -> sim_stop_required, allow_run_requested -> sim_run_allowed, about_to_add_environment -> environment_created
* Renamed Orbit.get_cartesian() -> get_vectors() & get_cartesian_from_elements() -> get_vectors_from_elements()
* Removed StringMaker. Replaced by more powerful QtyStrings.
* Renamed VoyagerCamera -> BCamera. (B for Body; presumably others will add "free flight" or other cameras.) Most of BCamera interface has changed.
* Changes to Timekeeper interface.
* Registrar.top_body changed to top_bodies (an array; contains only the Sun now but could contain, for example, a group of stars).
* Removed a bunch of "passive" tree_nodes classes that had only init() function: Model, HUDLabel, HUDIcon, Starlight, TempRings & VoyagerEnvironment. New "builder" classes generate the relevant base classes and add them as needed.
* Removed GUITop. (Universe is now the main scene at start and stays so after solar system build.)
* Renamed bodies.csv to models.csv (this table is about graphic representation of bodies).
* Removed Enums.SelectionTypes (and related members in Body and SelectionItem). Code cruft.
* Many Body boolean members are superceded by Body.flags.
* ProjectBuilder.program_refs dictionary was split into program_builders and program_refs (corresponding to directory changes listed above).
* Reorganized arrays & dicts that hold asset paths/directories in Global.


## [v0.0.5] - 2020-01-30
(Godot version **3.2**)

### Changes
* Improved Planetarium GUI visibility control. GUI won't disapear when mouse in margin between GUI and screen edge.
* Full screen toggle (Shift-F) hides/shows all GUI for Planetarium. 
* Planetarium uses common MainMenu rather than its own menu. This allows add-ons or other external code to use MainMenu API to add buttons for Planetarium.
* Copyright notices updated for 2020.
* Fixed "Hide HUD when close" option to work without restart.
* Renamed ivoyager directories: "system_tree" & "system_refs" to "tree_nodes" & "tree_refs".
* Made tree processing more logical: TreeManager subscribes to Timekeeper, calls tree_manager_process() for VoyagerCamera and then Body instances.

### API breaking changes
* Removed VoyagerCamera "processed" signal.
* Removed GregorianTimekeeper; its functions & members have been consolidated into its parent class Timekeeper.
* Changed signature & return value for SaverLoader.debug_log() function. This is a fix for the free-standing Procedural Saver/Loader 1.1 in the Godot Asset Library. 

### 3.2 compatibility fixes
* Fixed GUI widgets to work with 3.2 button signal changes. (Not compatible with Godot 3.1.2!)

### Bug fixes
* Fixed body momentary disappearance during camera move (due to not updating `near` property).
* Fixed giant sun when loading game that was fully zoomed out.
* Fixed date/time display when loading game that was paused.
* Fixed Timekeeper.convert_date_time_string().


## [v0.0.4] - 2019-12-26
(Godot version **3.1.2.**)

### Added
* Added Full Screen button to Planetarium GUI.
* Added many user options for camera movement rates (mouse & key).

### Changes
* Added default hotkeys to overcome web browser disabling of +/- keys (0.0.3 **hotfix a** for Web Planetarium only).
* Slowed down default camera wheel effect.
* Localization text keys added for OptionsPopup & HotkeysPopup.

### API-breaking changes
* Changes to VoyagerCamera public vars


## [v0.0.3] - 2019-12-18
(Now using Godot **3.1.2.**)

### Added
* Many new GUI widgets. The idea here is to make existing "functional elements" (e.g., a set of related buttons) into self-contained scene widgets for easy use in project-specific GUI. This will be done on an as-needed basis.
* Added new "planetarium-style" GUI. This is now default in the Planetarium project. Both "game-style" and "planetarium-style" are in the core submodule, so can be used by any project. PlanetariumGUI is cleaner and less "gamey".
* Added missing selection functions. You can navigate almost entirely now with Shift-arrows, P, Shift-P, M, Shift-M, etc. (see Hotkeys/Selection)
* Use class const GLOBAL_ENUM or GLOBAL_ENUM_2 to add listed enums to Global.enums.
* Added project setting Global.asteroid_mag_cutoff_override. This can overide mag_cutoff for all groups normally set in data/solar_system/asteroid_group_data.csv (the table uses mag_cutoff=15 for most groups but a less restrictive setting for Near-Earth and Mars-Crossers). With asteroid_mag_cutoff_override = 15.0, you will have 64,738 total asteroids. With 100.0, you'll have all 647,000 asteroids! ("Larger" magnitude is smaller object so less restrictive!)

### Changes
* Most old GUI widgets work a little differently.
* Renamed "COPYRIGHT.txt" to "3RD_PARTY.txt" in all repositories. "COPYRIGHT" was interfering with GitHub recognition our Apache 2.0 license in LICENSE.txt. Also, "3RD_PARTY" is a better description of the contents.
* Many Controls such as MainMenu, MainProgBar and others are now safely removable.
* Renamed "HUD2dControl" to "HUD2dSurface" and moved from wrong directory to gui_admin.
* Widget DateTime displays date/time text in red when time runs in reverse.
* Removed InfoPanel and the wiki subpanel. This was for a couple reasons: 1) InfoPanel was confusingly coded, 2) the Planetarium now links directly to Wikipedia, so no need to maintain large text files. (Post [in the forum](https://ivoyager.dev/forum/) if you want previous code for your project.)
* Changes in asteroid shaders to allow WebGL1 export.
* Stars brightened up (in new 0.0.3 ivoyager_assets).
* Minor color adjustments & special adjustments for planetarium web deployment (GLES2 is darker than GLES3).
* Planetarium skips the splash screen.

### API-breaking changes
* Changes to VoyagerCamera "VIEWPOINT_" enums.
* Renamed several GUI widgets.
* Moved some public vars from Main to Global (ivoyager_version, project_version, is_modded).
* There was a directory name change from "gui_in_game" to "gui_game". This isn't technically API-breaking, but it may mess you up if you have hard-coded paths to the old directory and update ivoyager submodule.
* Project vars in Global that specified directory paths with "/ivoyager_assets/" were moved into the Global.asset_paths dictionary.
* Removed class_name and SCENE constant for almost all GUI widgets. These should mostly be built using the scene editor. A few are still callable by class_name including OneUseConfirm.
* Removed EnumGlobalizer (functionality moved to Global.project_init()).
* Renamed SelectionItem "SelectionType" to "SelectionTypes".

### Bug fixes
* Fixed var shadowing error.
* Fixed asteroid visibility save/load persistence.
* Fixed error in AsteroidGroup.max_apoapsis calculation.

### Planetarium web-deployment note
Repository ivoyager_planetarium has a new branch "web-deployment". This branch is periodically rebased onto master. It has one commit that changes some project.godot settings, for example, to use GLES2 rendering. There is a different (reduced) assets directory "ivoyager_assets_web" that is intended for use in web deployment.


## [v0.0.2] - 2019-11-26

### Added
- Yaw, Pitch, Roll - via hotkeys and right-button mouse drag (drag near screen center for yaw/pitch, or near edge for roll)

### Changes
- Reduced window size to fit inside HD screen: now 1800 x 900. (This is in Project Settings so it will only effect new Project Templates and the stand-alone Planetarium.) It's still resizable on the fly.
- "Quit/Exit without saving?" confirmations disabled if save/load disabled.

### Interface-breaking changes
* Signature changes in SaverLoader.save_game() & load_game(); this is to make SaverLoader stand-alone so it can be added to Godot Asset Library.
* Moved make_object_or_scene() from FileHelper to SaverLoader (same reason as above).
* Some VoyagerCamera API changes to allow for yaw/pitch/roll rotations.

### Bug fixes
* Fixed Credits button in exports [0.0.1-hotfix-a]
* Fixed InfoPanel movement when minimizing
* Removed hotkeys for non-existent developer functions


## v0.0.1 - 2019-11-8

Initial alpha release!

[v0.0.13]: https://github.com/ivoyager/ivoyager/compare/v0.0.12...HEAD
[v0.0.12]: https://github.com/ivoyager/ivoyager/compare/v0.0.11...v0.0.12
[v0.0.11]: https://github.com/ivoyager/ivoyager/compare/v0.0.10...v0.0.11
[v0.0.10]: https://github.com/ivoyager/ivoyager/compare/v0.0.9-alpha...v0.0.10
[v0.0.9]: https://github.com/ivoyager/ivoyager/compare/0.0.8-alpha...v0.0.9-alpha
[v0.0.8]: https://github.com/ivoyager/ivoyager/compare/v0.0.7-alpha...0.0.8-alpha
[v0.0.7]: https://github.com/ivoyager/ivoyager/compare/v0.0.6-alpha...v0.0.7-alpha
[v0.0.6]: https://github.com/ivoyager/ivoyager/compare/v0.0.5-alpha...v0.0.6-alpha
[v0.0.5]: https://github.com/ivoyager/ivoyager/compare/v0.0.4-alpha...v0.0.5-alpha
[v0.0.4]: https://github.com/ivoyager/ivoyager/compare/v0.0.3-alpha...v0.0.4-alpha
[v0.0.3]: https://github.com/ivoyager/ivoyager/compare/v0.0.2-alpha...v0.0.3-alpha
[v0.0.2]: https://github.com/ivoyager/ivoyager/compare/v0.0.1-alpha...v0.0.2-alpha
