* render_notebooks.do: render the series notebooks
*
* webdoc runs each notebook in notebooks/01-simple-regression/ and writes
* outputs/private/notebooks/01-simple-regression/<name>.html, with the graphs
* embedded. The R and Python projects render the same notebooks. The pages
* show summaries only, never individual records, and stay under private/
* because they read private data. Notebooks in notebooks/drafts/ are older
* material and are not rendered.

local part 01-simple-regression
capture mkdir `"$outputs_private_notebooks/`part'"'
local notebooks : dir `"$notebooks/`part'"' files "*.do"
local notebooks : list sort notebooks
foreach notebook of local notebooks {
    timer clear 1
    timer on 1
    webdoc do `"$notebooks/`part'/`notebook'"'
    timer off 1
    quietly timer list 1
    display as text "`part'/`notebook': " %5.0f r(t1) " seconds"
}
