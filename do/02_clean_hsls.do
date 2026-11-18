* 02_clean_hsls.do: build the analysis file from the HSLS:09 student file
*
* inputs/public/raw/hsls_crosswalk.csv drives every step: which NCES
* variables to keep, missing-value codes, recodes, new names, and labels.
* The R and Python projects keep the same crosswalk, so all three build the
* same file.
*
* NCES marks missing values with negative reserve codes, and the crosswalk
* splits them in two (see docs/missing-data.md):
*   missing: nonresponse (-9, -8, -4, ...). The question applied but went
*            unanswered. Analyses impute these or model them.
*   skip:    logical skips (-7, -6). The question did not apply, such as
*            parent 2 education in a one-parent family. Analyses usually
*            drop these cases.
* Both become missing values, so a flag keeps the difference. A row with
* derive = "applies" builds a 0/1 flag from its source: 0 for a logical skip,
* 1 for an answer, missing for nonresponse. A row with within = <flag> is
* missing wherever that flag is not 1.
*
* Only the listed codes become missing. Several variables, such as the SES
* composite, have real negative values, so "negative means missing" would
* drop real data.

* The student file has 8,509 variables, more than Stata's default 5,000.
* Raising the limit needs an empty session; globals survive clear all.
clear all
set maxvar 10000

* Read the crosswalk into locals, one set per row
fw_use inputs.public.raw.hsls_crosswalk, clear options(stringcols(_all) case(preserve))
local rows = _N
local sources
local names
forvalues i = 1/`rows' {
    foreach column in name nces label missing skip derive within recode labels {
        local `column'`i' `"`=`column'[`i']'"'
    }
    local sources : list sources | nces`i'
    local names `names' `name`i''
}

* Read only the crosswalk's variables from the 8,509 in the student file
fw_use inputs.private.raw.hsls_student, clear options(case(preserve) stringcols(1))
keep `sources'

forvalues i = 1/`rows' {
    local source `nces`i''
    local name `name`i''

    * Mark nonresponse and logical skips
    tempvar missing skipped
    quietly generate byte `missing' = 0
    quietly generate byte `skipped' = 0
    local codes : subinstr local missing`i' ";" " ", all
    foreach code of local codes {
        quietly replace `missing' = 1 if `source' == `code'
    }
    local codes : subinstr local skip`i' ";" " ", all
    foreach code of local codes {
        quietly replace `skipped' = 1 if `source' == `code'
    }

    if "`derive`i''" == "applies" {
        quietly generate byte `name' = !`skipped' if !`missing'
    }
    else {
        quietly clonevar `name' = `source' if !`missing' & !`skipped'
        if `"`recode`i''"' != "" {
            local rules : subinstr local recode`i' ";" ") (", all
            quietly recode `name' (`rules')
        }
    }
    if "`within`i''" != "" {
        quietly replace `name' = . if `within`i'' != 1
    }
    drop `missing' `skipped'
    label variable `name' `"`label`i''"'

    * Value labels, such as 1=City;2=Suburb
    if `"`labels`i''"' != "" {
        local rest `"`labels`i''"'
        while `"`rest'"' != "" {
            gettoken pair rest : rest, parse(";")
            if `"`pair'"' == ";" continue
            gettoken value text : pair, parse("=")
            gettoken equals text : text, parse("=")
            label define `name' `value' `"`text'"', add
        }
        label values `name' `name'
    }
}

keep `names'
order `names'

* CSV holds codes, as in R and Python. Labels go in the .dta file.
fw_save inputs/private/final/hsls_clean.csv, replace options(nolabel)
fw_save inputs/private/final/hsls_clean.dta, replace
display as text "`c(N)' students, `c(k)' variables"
