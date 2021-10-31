# playedagefilter
A musicbase utility to generate filtered output based on last played values

Uses awk to filter rated-tracks FILE, based on last-played-date, and outputs results to a database file of 
not-recently-played tracks, which can then be used by other tools for playlist creation. Used
when POPM and last-played data are included in the input database.
