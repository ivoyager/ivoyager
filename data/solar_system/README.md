# README for I, Voyager tables

For table construction rules, see [ivoyager_table_importer/README.md](https://github.com/ivoyager/ivoyager_table_importer/blob/master/README.md).

WARNING! Do not use Excel for .tsv file editing! Excel will "interpret" and modify cell values. For example, the Sun's GM = "1.32712440018e20" will be be changed to "1.33E+20" in the display bar AND THE SAVED FILE VALUE! You can prevent this by prefixing with either single-quote (') or underscore (_). However, we don't want to have to prefix all REALs (or use other labor-intensive work-arounds) just to use Excel.

Remarkably, the only .csv/.tsv file editor that I could find that doesn't do this (and is currently being maintained for Windows 10) is Ron's Editor: https://www.ronsplace.eu/Products/RonsEditor/Information. It's free for files with up to 1000 rows ($40 for "pro" unlimited). It works well for me and I recommend it.


*******************************************************************************
## Specific Table Comments

WIP, needs reformating for .md file

asset_adjustments.tsv
This table has atypical 'name' column (= asset file name).
Maps are assumed to have prime meridian at center & longitude 180 at edge, as
is typical for Earth maps; if different use 'longitude_offset'.
Model scale is assumed to be in meters (1 meter), unless included here.
Default values are hard-coded so we don't have to include all assets here.

asteroid_groups.tsv
See Asteroid Importer addon for creation of asteroid binaries. (TODO! It needs
update to work with current ivoyager.)
Edit mag_cutoff to change how many asteroids are loaded. Number asteroids at
'mag_cutoff': 15.0 ~94k; 14.0 ~31k, 13.0 ~9k, 12.0 ~3k.
All other columns (and provided rows) are used to make binaries and should not
be changed unless rebuilding binaries. 
Groups are based on:
https://en.wikipedia.org/wiki/List_of_minor_planets#Orbital_groups,
with criteria modified so there are no excluded orbits.
Asteroids are added to the first matching group. q, perihelion (closest); a,
semimajor axis (peri- & apohelion average); q = (1 - e) * a.
For each group, binaries were created representing half-integer ranges of
magnitude. mag_cutoff determines which of these binaries are loaded.
Rows here are currently hard-coded into navigation_panel.gd. This is something
we try very hard not to do! To make this procedural rather than hard-coded, we
would need columns here telling GUI where the asteroid group should be placed
relative to planets.
Totals shown in comments are from wiki, and I think include only numbered. We
have multiopposition non-numbered, so add ~20%.

barycenters.tsv
NOT IMPLEMENTED

classes.tsv
Used only for GUI info display.

environments.tsv
NOT IMPLEMENTED. The idea is to move internal environment settings to this data
table, and possibly provide alternative settings.

lights.tsv
OmniLight properties for stars (only Sun for now). Some internal settings may
be moved here.

models.tsv
Tells simulator how to implement model.
Graphics attributes need attention! Columns can be added here, then implemented
in program_refs/model_builder.gd. Our target aesthetic for base I, Voyager is
"harsh realism". E.g., see videos of Musk's roadster in space. NOT cartoony!

moons.tsv
Source: https://ssd.jpl.nasa.gov/?sat_elem
Pw, Pnode are apsidal and nodal precession, ie, period of rotation of w and Om.
Pw is in the direction of orbit; Pnode is in the opposite direction!
Pw for the Moon from above source (5.997) is in conflict with other sources
(eg, Wiki: 8.85). WTH?
Sort each planet's moons by semi_major axis (a) for proper GUI selection order.

planets.tsv
Keplarian elements and rates for approximate position calculation from 3000BC
to 3000AD from https://ssd.jpl.nasa.gov/?planet_pos. Earth is really Earth-Moon
barycenter.
Physical characteristics mostly from https://ssd.jpl.nasa.gov/?planet_phys_par
or Wikipedia.
Ceres was added using AstDyS-2 proper elements a, e, sin(i), n and non-proper
Om, w & M0.
longitude_at_epoch is planetocentric longitude facing solar system barycenter
at epoch.

stars.tsv
We only have one! Data mostly from Wikipedia.

wiki_extras.tsv
Holds strings that we want associated with wiki page that are not row names in
a table with en.wikipedia column.

