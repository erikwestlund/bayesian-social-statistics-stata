*! hsls_missing_reasons: why each value in the clean HSLS:09 file is missing
*
* The data in memory hold the clean variables and their raw NCES sources,
* aligned row by row. For each crosswalk row, the program adds a variable
* <prefix><name> with one of four reasons:
*   1 Observed: the clean value is present
*   2 Nonresponse: the raw value is a nonresponse code or blank
*   3 Logical skip: the raw value is a logical-skip code
*   4 Outside the flag: the raw value is an answer, but the crosswalk's
*     within flag is not 1 for this student
* A flag built from a logical skip (derive = applies) turns the skip into 0,
* so its skips count as observed. The Python and R projects keep the same
* rules in functions/hsls.py and functions/hsls.R.
*
*   hsls_missing_reasons using crosswalk.dta [, prefix(why_)]
program define hsls_missing_reasons
    version 14
    syntax using/ [, PREfix(name)]
    if "`prefix'" == "" local prefix why_

    * Read the crosswalk's names, sources, and codes
    preserve
    quietly use `"`using'"', clear
    local rows = _N
    forvalues i = 1/`rows' {
        foreach column in name nces missing skip {
            local `column'`i' `"`=`column'[`i']'"'
        }
    }
    restore

    capture label drop hsls_reason
    label define hsls_reason 1 "Observed" 2 "Nonresponse" 3 "Logical skip" 4 "Outside the flag"
    forvalues i = 1/`rows' {
        local source `nces`i''
        local reason `prefix'`name`i''
        quietly generate byte `reason' = 4
        local codes : subinstr local skip`i' ";" " ", all
        foreach code of local codes {
            quietly replace `reason' = 3 if `source' == `code'
        }
        quietly replace `reason' = 2 if missing(`source')
        local codes : subinstr local missing`i' ";" " ", all
        foreach code of local codes {
            quietly replace `reason' = 2 if `source' == `code'
        }
        quietly replace `reason' = 1 if !missing(`name`i'')
        label values `reason' hsls_reason
        label variable `reason' `"Why `name`i'' is missing"'
    }
end
