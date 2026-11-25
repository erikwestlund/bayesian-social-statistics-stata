* 02_clean.do: build the analysis file from the ELS:2002 student file
*
* Run from master.do, or on its own from the project folder:
*   do settings.do
*   do do/els/02_clean.do
*
* inputs/public/raw/els_crosswalk.csv drives every step: which NCES
* variables to keep, missing-value codes, recodes, new names, and labels.
* The names follow the HSLS:09 crosswalk, so code written for one study reads
* the other. The R and Python projects keep the same crosswalk, so all three
* build the same file.
*
* A row's missing codes are nonresponse; its skip codes mark a survey
* component that did not apply. Both become missing values. A row with fill =
* <name>=<value> takes that value wherever it is still missing and the named
* variable is observed. Only the listed codes become missing: several
* composites, such as SES, have real negative values.

* The student file has 6,571 variables, more than Stata's default 5,000.
* Raising the limit needs an empty session; globals survive clear all.
clear all
set maxvar 10000

* Read the crosswalk into locals, one set per row
fw_use inputs.public.raw.els_crosswalk, clear options(stringcols(_all) case(preserve))
local rows = _N
local sources SCH_ID
local names
forvalues i = 1/`rows' {
    foreach column in name nces label missing skip derive within fill recode labels {
        local `column'`i' `"`=`column'[`i']'"'
    }
    local sources : list sources | nces`i'
    local names `names' `name`i''
}
local duplicates : list dups names
if "`duplicates'" != "" {
    display as error "The crosswalk names `duplicates' more than once."
    exit 459
}

* Doubles keep the weights and scores at full precision
fw_use inputs.private.raw.els_student, clear options(case(preserve) stringcols(1) asdouble)
keep `sources'
generate long row = _n

forvalues i = 1/`rows' {
    local source `nces`i''
    local name `name`i''

    * Mark nonresponse and skipped components
    tempvar missing skipped
    * A blank cell is missing too, so a flag never reads it as an answer
    quietly generate byte `missing' = missing(`source')
    quietly generate byte `skipped' = 0
    local codes : subinstr local missing`i' ";" " ", all
    foreach code of local codes {
        quietly replace `missing' = 1 if `source' == `code'
    }
    local codes : subinstr local skip`i' ";" " ", all
    foreach code of local codes {
        quietly replace `skipped' = 1 if `source' == `code'
    }

    quietly clonevar `name' = `source' if !`missing' & !`skipped'
    if `"`recode`i''"' != "" {
        local rules : subinstr local recode`i' ";" ") (", all
        quietly recode `name' (`rules')
    }
    if "`fill`i''" != "" {
        gettoken other value : fill`i', parse("=")
        gettoken equals value : value, parse("=")
        quietly replace `name' = `value' if missing(`name') & !missing(`other')
    }
    drop `missing' `skipped'
    label variable `name' `"`label`i''"'

    * Value labels, such as 1=City;2=Suburb. Every observed value needs one.
    if `"`labels`i''"' != "" {
        tempvar labelled
        quietly generate byte `labelled' = missing(`name')
        local rest `"`labels`i''"'
        while `"`rest'"' != "" {
            gettoken pair rest : rest, parse(";")
            if `"`pair'"' == ";" continue
            gettoken value text : pair, parse("=")
            gettoken equals text : text, parse("=")
            label define `name' `value' `"`text'"', add
            quietly replace `labelled' = 1 if `name' == `value'
        }
        label values `name' `name'
        quietly count if !`labelled'
        if r(N) {
            display as error "Unlabelled value in `name'"
            exit 459
        }
        drop `labelled'
    }
}

* Every reserve code the crosswalk does not list would pass through as a
* value. These variables have no real negative values, so any left is a code
* the crosswalk missed.
local real_negatives student_id w1_ses w1_ses_duncan w4_ses
local nonnegative : list names - real_negatives
local leftover
foreach name of local nonnegative {
    quietly count if `name' < 0
    if r(N) local leftover `leftover' `name'
}
if "`leftover'" != "" {
    display as error "Unlisted negative codes in: `leftover'"
    exit 459
}

assert SCH_ID == -5
assert !missing(student_id)
isid student_id
assert !missing(stratum)
quietly tabulate stratum
assert r(r) == 361
assert inlist(psu, 1, 2, 3)
* PSU occupies one digit in the NCES design key (2006-344, appendix G).
generate double school_id = 10 * stratum + psu
preserve
contract school_id, freq(size)
quietly summarize size, detail
display as text `"`=_N' base-year school clusters, median size `=r(p50)'"'
restore

local components w1_income_imputed w1_mother_edu_imputed w1_father_edu_imputed ///
    w1_mother_occ_imputed w1_father_occ_imputed
local components : list retokenize components
local any = subinstr("`components'", " ", " + ", .)
local all = subinstr("`components'", " ", ", ", .)
* Missing when SES or any component flag is missing, as in R
generate double w1_ses_imputed = (`any' > 0) if !missing(w1_ses) & !missing(`all')
assert missing(w2_math) == inlist(w2_test_status, 0, 4)
assert w2_math_imputed == inlist(w2_test_status, 2, 3) if !missing(w2_math_imputed)
assert missing(w1_ses_imputed) == missing(w1_ses)

keep row `names' school_id w1_ses_imputed
tempfile clean
quietly save `clean'

* The separate NCES replicate file uses the same student key as the CSV.
fw_use inputs.private.raw.els_brr, clear
keep STU_ID BYSTU1-BYSTU200 F1PNL1-F1PNL200
assert !missing(STU_ID)
generate student_id = string(STU_ID, "%12.0f")
isid student_id
foreach weight of varlist BYSTU1-BYSTU200 F1PNL1-F1PNL200 {
    assert !missing(`weight') & `weight' >= 0
}
rename (BYSTU#) (w1_weight_rep#)
rename (F1PNL#) (w2_weight_panel_rep#)
drop STU_ID
merge 1:1 student_id using `clean', assert(match) nogenerate

sort row
drop row
order `names' school_id w1_ses_imputed w1_weight_rep* w2_weight_panel_rep*

* CSV holds codes, as in R and Python. Labels go in the .dta file.
fw_save inputs/private/final/els_clean.csv, replace options(nolabel)
fw_save inputs/private/final/els_clean.dta, replace
display as text "`=string(_N, "%9.0fc")' students, `c(k)' variables"
