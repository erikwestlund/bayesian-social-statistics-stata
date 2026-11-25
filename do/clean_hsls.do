* clean_hsls.do: build the HSLS:09 analysis file by running every step in
* do/hsls/ in order
*
* Run from master.do, or on its own from the project folder:
*   do settings.do
*   do do/clean_hsls.do
*
* Each step is a do-file that also runs on its own. A step that fails stops
* the run, so later steps never read a half-built file.

local steps : dir `"$do/hsls"' files "*.do"
local steps : list sort steps
foreach step of local steps {
    display as text "Running do/hsls/`step'"
    do `"$do/hsls/`step'"'
}
