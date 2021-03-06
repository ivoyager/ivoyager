README for I, Voyager data table system

WARNING! Do not use Excel for .tsv file editing! Excel will "interpret" and
modify cell values. For example, the Sun's GM = "1.32712440018e20" will be
be changed to "1.33E+20" in the display bar AND THE SAVED FILE VALUE! You can
prevent this by prefixing with either single-quote (') or underscore (_).
However, it is then necessary to assess each REAL for "Excel-safety", or prefix
all REALs. Alternatively, you can use the import wizard and set all columns to
text EVERY TIME you edit a *.tsv file, but that seems like a major hassle to
me.

Remarkably, the only .csv/.tsv file editor that I could find that doesn't do
this (and is currently being maintained for Windows 10) is Ron's Editor:
	https://www.ronsplace.eu/Products/RonsEditor/Information
It's free for files with up to 1000 rows ($40 for "pro" unlimited). It works
well for me so far and I recommend it.

Overview:

TableImporter reads *.tsv files specified in Global.table_import (and
Global.wiki_titles_import) and stores data as modified string values. Use
TableReader API (prog_refs/table_reader.gd) to read internal data tables; it
will convert strings to typed values and convert REAL values to specified
Units. Use TableReader get_ and build_ functions to init object properties
with table values. Don't use TableReader for runtime logic that needs to be
fast.

File rules:

*	Any row with # in the first 3 characters is a comment (skipped).
*	The first non-comment row must have headers.
*	The last column is ignored if header is "Comment".
*	The first column header must be "name".
*	Row name must be globally unique among all data tables listed and imported
	from Global.table_import. Tables listed in Global.wiki_titles_import can have
	duplicate row names (duplicates will overwrite existing values).
*	After header row there must be a "Type" row. See details below.
*	Two more rows are optional: "Default" and "Units". See details below.

Cell rules:

*	Double-quotes (") will be removed if they enclose the cell on both ends.
*	A prefix single-quote (') or underscore (_) will be removed.
*	Blank cells are allowed for any Type and (if no Default specified) are
	interpreted as missing or n/a values. These values will not be set in
	TableReader build_ functions. However, get_int(), get_real(), etc., will
	return type-specific "null" values (e.g., -1, NAN, etc.).

Item hyperlinks to Wikipedia or internal wiki:

Extension project can set Global.enable_wiki = true for GUI hyperlinks. Column
fields "en.wikipedia", etc., contain page titles for language-specific
Wikipedia pages. Additional languages can be added as new columns and must be
added to Global.wikipedia_locales. For an internal wiki (a la "Civiliopedia")
add new column "wiki" and set Global.use_internal_wiki = true. For more info,
see comments and API in prog_refs/wiki_manager.gd.

Type (required row):

	STRING
		Normal Godot escaping applies for \n, \t, etc. We have also patched
		\uXXXX to correctly convert to unicode (this will eventually work in
		Godot; see issue https://github.com/godotengine/godot/issues/38716).
		However, \UXXXXXXXX for advanced unicode does not currently work. 
	BOOL
		Case-insensitive "True" or "False". Note that blank cell (without
		Default) is different than "False". A "False" value will be set to
		false in TableReader build_ functions; a blank will not be set. Both
		"False" and blank/missing value will return false in get_bool().
	X
		Must be "x" or blank. This is essentially the same as BOOL except
		Default is not allowed. Use TableReader.get_bool() to read this type.
	INT
		Any valid integer.
	REAL
		See WARNING about Excel above. If you must use it, then prefix all REAL
		values with ' or _ to prevent number modification.
		"E" or "e" are ok.
		"?" means unknown. It is converted to INF by TableReader.get_float()
		and "build_" functions, which is displayed as "?" by GUI.
		Blank value means n/a. It produces NAN in TableReader.get_float(), is
		not set in "build_" functions, and is not displayed by GUI.
		Any number prefixed with "~" will be interpreted as a "zero-precision"
		number, displayed as (for example) "~1 x 10^-10".
		For numbers not preceded by "~", precision is interpreted for GUI
		display as in the following examples:
			1e3 - 1 significant digit
			1000 - 1 significant digit
			1100 - 2 significant digits
			1.000e3 - 4 significant digits 
			1000. - 4 significant digits
			1000.0 - 5 significant digits
			1.0010 - 5 significant digits
			0.0010 - 2 significant digits
	DATA
		Expected to be a valid data table row name, e.g., "CLASS_GAS_GIANT".
		Return from TableReader.get_data() is the data table row number.
	BODY
		Expected to be a Body name, e.g., "PLANET_EARTH". Return value from
		TableReader.get_body() is the Body instance (if it exists in tree) or
		null.
	< enum name >
		An enum name can be specified for Type. The enum must exist in a
		static Reference class specified in Global.enums. If you need to add
		enums for table data, extend the existing static/enums.gd class file
		and set Global.enums to your new class.

Default (optional row):

	Default values must be blank or follow Type rules above. If non-blank, this
	value is used for any blank cells in the column.

Units (optional row):

	Units are valid only for Type = REAL. The Units string must be a key in one
	of the dictionaires in static/unit_defs.gd (MULTIPLIERS or FUNCTIONS), or
	in replacement dictionaries specified in Global.unit_multipliers or
	Global.unit_functions. Units can be prefixed by "10^### " where ### is a
	valid integer.
	