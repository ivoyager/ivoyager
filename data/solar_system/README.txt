README for I, Voyager data table system

WARNING! Do not use Excel for .tsv file editing! Excel will "interpret" and
modify cell values. For example, the Sun's GM = "1.32712440018e20" will be
be changed to "1.33E+20" in the display bar AND THE SAVED FILE VALUE! You can
prevent this by prefixing with either single-quote (') or underscore (_).
However, it is then necessary to assess each REAL and large INT value
individually for "Excel-safety", or prefix all numbers. Alternatively, you can
use the import wizard and set all columns to text EVERY TIME you edit a *.tsv
file. Any of these options is a major hassle.

Remarkably, the only .csv/.tsv file editor that I could find that doesn't do
this (and is currently being maintained for Windows 10) is Ron's Editor:
	https://www.ronsplace.eu/Products/RonsEditor/Information
It's free for files with up to 1000 rows ($40 for "pro" unlimited). It works
well for me so far and I recommend it.

Overview:

TableImporter reads *.tsv files specified in Global.table_import and stores
data as modified string values. TableReader API (prog_refs/table_reader.gd) is
used to "read" internal data tables, converting cells to typed values and (for
REAL) converting for specified Units. String representation allows us to retain
significant digits of REAL values for correct precision display. Use
TableReader "get_" and "build_" functions to init object properties with table
values. Don't use TableReader for runtime logic that needs to be fast.

File rules:

*	Any row with # in the first 3 characters is a comment (skipped).
*	The first non-comment row must have headers.
*	The last column is ignored if header is "Comment".
*	The first column header must be "name".
*	Row name must be globally unique among all data tables.
*	After header row there must be a "DataType" row. See details below.
*	Two more rows are optional: "Default" and "Units". See details below.

Cell rules:

*	Double-quotes (") will be removed if they enclose the cell on both ends.
*	A prefix single-quote (') or underscore (_) will be removed.
*	Blank cells are allowed for any DataType and (if no Default specified) are
	interpreted as missing or n/a values. These values will not be set in
	TableReader "build_" functions. However, get_int(), get_real(), etc., will
	return type-specific null-equivilent values (e.g., -1, NAN, etc.).

Wikipedia:

All data tables can have column wiki_en, which specifies item text needed to
complete URL for English language Wikipedia page. TODO: other localizations.
Also, we plan to implement similar (but different) headers to facilitate
hyperlinks to internal game content wikis (a la Civilopedia). 

DataType:

	STRING
		Normal Godot escaping applies for \n, \t, etc. We have also patched
		\uXXXX to correctly convert to unicode (this will eventually work in
		Godot; see issue https://github.com/godotengine/godot/issues/38716).
		However, \UXXXXXXXX for advanced unicode does not currently work. 
	BOOL
		Case-insensitive "True" or "False". Blank Default is the same as False.
	X
		Must be "x" or blank. This is essentially the same as BOOL except
		Default is not allowed. Use TableReader.get_bool() to read this
		data type.
	INT
		Any valid integer. See WARNING about Excel above; it will change vary
		large int values unless they are prefixed by ' or _.
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
		An enum name can be specified for DataType. The enum must exist in a
		static Reference class specified in Global.enums. If you need to add
		enums for table data, extend the existing static/enums.gd class file
		and set Global.enums to your new class.

Default:

	Default row is optional. Value must be blank or follow DataType rules
	above.

Units:

	Units row is optional. It is valid only for DataType = REAL. The Unit
	string must be a key in one of the dictionaires in static/unit_defs.gd
	(MULTIPLIERS or FUNCTIONS), or in replacement dictionaries specified in
	Global.unit_multipliers or Global.unit_functions.
	Unit can be prefixed by "10^### " where ### is any valid integer.
	