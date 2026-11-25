* clean_els.do: build the ELS:2002 analysis file by running every step in
* do/els/ in order
*
* Run from master.do, or on its own from the project folder:
*   do settings.do
*   do do/clean_els.do
*
* Each step is a do-file that also runs on its own. A step that fails stops
* the run, so later steps never read a half-built file.

local steps : dir `"$do/els"' files "*.do"
local steps : list sort steps
foreach step of local steps {
    display as text "Running do/els/`step'"
    do `"$do/els/`step'"'
}
