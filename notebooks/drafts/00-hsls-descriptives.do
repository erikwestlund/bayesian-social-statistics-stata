* 01-hsls-descriptives.do: notebook that describes the cleaned HSLS:09 file
*
* webdoc runs this do-file and writes the text blocks, Stata output, tables,
* and graphs to outputs/private/notebooks/01-hsls-descriptives.html. Run it
* through do/03_describe_hsls.do, which raises maxvar for the raw file first.
* The R and Python projects render the same notebook from
* notebooks/01-hsls-descriptives.qmd and .ipynb.

webdoc init `"$outputs_private_notebooks/01-hsls-descriptives.html"', replace ///
    header(title("HSLS:09 descriptive statistics") author("Erik") date("2026-11-18") width(60em)) ///
    logdir(01-hsls-descriptives_files) ///
    grdir(01-hsls-descriptives_files) ///
    linesize(100) nokeep gropts(as(svg) hardcode)
set scheme s1color

/***
<style>
body { font-size: 15px; line-height: 1.5; }
div.table { overflow-x: auto; margin: 0 0 1.2em; }
table { border-collapse: collapse; font-size: 13px; }
th, td { padding: 3px 8px; border-bottom: 1px solid #DDDDDD; text-align: left; vertical-align: top; }
th { border-bottom: 2px solid #999999; }
td.num { text-align: right; font-variant-numeric: tabular-nums; }
figure { margin: 0 0 1.2em; }
</style>

<h1>HSLS:09 descriptive statistics</h1>

<p>Erik, 2026-11-18</p>

<p>This notebook reports descriptive statistics and missing-data diagnostics for
the cleaned HSLS:09 student file (<code>hsls_clean</code>): variable storage
types and missingness rates, survey response counts and analytic weights,
univariate distributions for continuous and categorical variables,
missing-value classifications, joint missingness patterns, covariate
differences between observed and missing cases, pairwise correlations, and
variance across socioeconomic status (SES) imputations. Value labels and NCES
reserve codes are documented in <code>docs/codebook.md</code>, and missing-data
coding rules are documented in <code>docs/missing-data.md</code>.</p>

<p>All student counts are unweighted record counts in <code>hsls_clean</code>.
Sample-level shares use all records in <code>hsls_clean</code> as the
denominator, whereas univariate summary statistics use records with
non-missing values on each variable. Univariate continuous and categorical
tables report both unweighted statistics and weighted estimates targeting the
population of 9th graders in fall 2009; missing-data, covariate-balance,
correlation, and imputation tables are unweighted.</p>

<p>Because this notebook reads private data (<code>inputs.private.*</code>),
rendered output is written to <code>outputs/private/notebooks</code> and
reports aggregate statistics only. Stata 14 has no <code>dyndoc</code>, so
<a href="http://repec.sowi.unibe.ch/stata/webdoc">webdoc</a> builds the page.
The helper programs are in <code>functions/</code>.</p>
***/

webdoc stlog
* The crosswalk gives each variable's source, type, wave, and codes
fw_use inputs.public.raw.hsls_crosswalk, clear options(stringcols(_all) case(preserve))
tempfile crosswalk
quietly save `crosswalk'
local rows = _N
local names
local sources
forvalues i = 1/`rows' {
    local name = name[`i']
    local names `names' `name'
    foreach column in nces wave type derive {
        local `column'_`name' = `column'[`i']
    }
    local sources `sources' `=nces[`i']'
}
local sources : list uniq sources

* Raw values give the reasons for missing values. Keep the crosswalk's variables.
fw_use inputs.private.raw.hsls_student, clear options(case(preserve) stringcols(1))
keep `sources'
tempfile raw
quietly save `raw'

* The clean file, with variable and value labels
fw_use inputs.private.final.hsls_clean_stata, clear
local variables = c(k)

* Missing-value reasons compare raw and clean values row by row
merge 1:1 _n using `raw', assert(match) nogenerate
assert STU_ID == student_id
hsls_missing_reasons using `crosswalk'
drop `sources'
display as result strtrim(string(_N, "%9.0fc")) " students, `variables' variables"
webdoc stlog close

/***
<h2>Variable overview</h2>

<p>The table below lists every column in <code>hsls_clean</code>. Variable
labels, survey waves, and measurement types come from
<code>hsls_crosswalk</code>, while <code>Data type</code> reports the storage
type in <code>hsls_clean</code>: <code>student_id</code> is stored as a string
and all other variables are numeric, with binary, categorical, and ordinal
variables stored as integer codes mapped to labels in the crosswalk.
<code>Distinct observed</code> and <code>Observed</code> count non-missing
records only; <code>Missing (% of sample)</code> is the unweighted percentage
of all students in <code>hsls_clean</code> with a missing value on that
variable.</p>
***/

webdoc stlog
preserve
tempname post
tempfile overview
postfile `post' str32 Variable str100 Label str4 Wave str12 Type str8 Stored ///
    double(Distinct Observed Missing) using `overview'
foreach name of local names {
    quietly count if !missing(`name')
    local observed = r(N)
    tempvar first
    quietly bysort `name': generate byte `first' = _n == 1 & !missing(`name')
    quietly count if `first'
    post `post' ("`name'") (`"`: variable label `name''"') ("`wave_`name''") ///
        ("`type_`name''") ("`: type `name''") (r(N)) (`observed') ///
        (100 * (1 - `observed' / _N))
    drop `first'
}
postclose `post'
use `overview', clear
label variable Stored "Data type"
label variable Distinct "Distinct observed"
label variable Missing "Missing (% of sample)"
format Distinct Observed %9.0fc
format Missing %5.1f
webdoc stlog close
html_table
restore

/***
<h2>Survey response and analytic weights</h2>

<p>HSLS:09 sampled 23,503 9th graders in fall 2009. A weight above 0
identifies a student included in weighted estimates under that weight: the
base-year student weight (<code>w1_weight</code>) requires a base-year student
survey, the parent weight (<code>w1_weight_parent</code>) requires a parent
survey, and the longitudinal panel weight (<code>w2_weight_panel</code>)
requires both the base-year student survey and the first follow-up student
survey.</p>

<p>The first table reports unweighted student counts and unweighted
percentages of all records in <code>hsls_clean</code> with each response
indicator equal to 1 and each analytic weight above 0. The cross-tabulation
then gives unweighted student counts jointly by base-year student survey
status (<code>w1_responded</code>) and first follow-up student survey status
(<code>w2_responded</code>), coding missing values on
<code>w2_responded</code> as <code>Response status unknown</code>.</p>
***/

webdoc stlog
local flags w1_responded w1_parent_responded w2_responded
local weights w1_weight w1_weight_parent w2_weight_panel
preserve
tempfile sample
postfile `post' str32 Students_in str100 Label double Students using `sample'
foreach name of local flags {
    quietly count if `name' == 1
    post `post' ("`name' = 1") (`"`: variable label `name''"') (r(N))
}
foreach name of local weights {
    quietly count if `name' > 0 & !missing(`name')
    post `post' ("`name' > 0") (`"`: variable label `name''"') (r(N))
}
postclose `post'
local students = _N
use `sample', clear
generate double Share = 100 * Students / `students'
label variable Students_in " "
label variable Share "Share of sample (%)"
format Students %9.0fc
format Share %5.1f
webdoc stlog close
html_table
restore

webdoc stlog
* Unweighted student counts by base-year and first follow-up student survey status
preserve
generate str w1_survey = cond(w1_responded == 1, "Base-year student survey", "No base-year student survey") ///
    if !missing(w1_responded)
generate str w2_survey = cond(w2_responded == 1, "First follow-up student survey", "No first follow-up student survey")
replace w2_survey = "Response status unknown" if missing(w2_responded)
* tabulate cuts long values to a few characters, so post the counts to an HTML
* table with the same rows, columns, and totals
quietly levelsof w1_survey, local(rows)
quietly levelsof w2_survey, local(levels)
local columns
local c 0
foreach level of local levels {
    local columns `columns' c`++c'
    local header_c`c' `"`level'"'
}
tempfile responses
postfile `post' str32 Survey double(`columns' Total) using `responses'
foreach row in `rows' Total {
    local in_row = cond("`row'" == "Total", `"w1_survey != """', `"w1_survey == "`row'""')
    local counts
    foreach level of local levels {
        quietly count if `in_row' & w2_survey == "`level'"
        local counts `counts' (`=r(N)')
    }
    quietly count if `in_row'
    post `post' ("`row'") `counts' (`=r(N)')
}
postclose `post'
use `responses', clear
label variable Survey " "
foreach c of local columns {
    label variable `c' "`header_`c''"
}
format `columns' Total %9.0fc
webdoc stlog close
html_table
restore

/***
<h2>Continuous variable distributions</h2>

<p>For each continuous variable in <code>hsls_crosswalk</code>, unweighted
summary statistics (<code>Unweighted mean</code>, <code>Unweighted SD</code>,
extrema, and percentiles) are computed over all students with a non-missing
value on that variable (<code>Observed</code>), where <code>Unweighted
SD</code> is the sample standard deviation. <code>Weighted mean</code> and
<code>Weighted SD</code> are computed over students with both a non-missing
value and a positive analytic weight, using the base-year student weight
(<code>w1_weight</code>) for base-year variables and the longitudinal panel
weight (<code>w2_weight_panel</code>) for the first follow-up math score
(<code>w2_math</code>). Weighted SDs are population standard deviations
(dividing by the sum of weights without sample degrees-of-freedom
adjustment). Quantiles interpolate linearly between the sorted values, as R and pandas do
by default.</p>
***/

webdoc stlog
local continuous
foreach name of local names {
    if "`type_`name''" == "continuous" local continuous `continuous' `name'
}
preserve
tempfile summaries
postfile `post' str32 Variable double(Observed Mean SD Min p5 p25 Median p75 p95 Max) ///
    str16 Weight double(Weighted_mean Weighted_SD) using `summaries'
foreach name of local continuous {
    local weight = cond("`wave_`name''" == "2", "w2_weight_panel", "w1_weight")
    quietly summarize `name'
    local summary
    foreach statistic in N mean sd min {
        local summary `summary' (`=r(`statistic')')
    }
    local max = r(max)
    hsls_quantile `name', percentiles(5 25 50 75 95)
    foreach p in 5 25 50 75 95 {
        local summary `summary' (`=r(p`p')')
    }
    hsls_weighted_mean_sd `name', weightvar(`weight')
    post `post' ("`name'") `summary' (`max') ("`weight'") (r(mean)) (r(sd))
}
postclose `post'
use `summaries', clear
format Observed %9.0fc
format Mean-Max Weighted_mean Weighted_SD %9.2f
label variable Mean "Unweighted mean"
label variable SD "Unweighted SD"
label variable p5 "5%"
label variable p25 "25%"
label variable p75 "75%"
label variable p95 "95%"
label variable Weighted_mean "Weighted mean"
label variable Weighted_SD "Weighted SD"
webdoc stlog close
html_table
restore

/***
<p>Base-year math (<code>w1_math</code>) and first follow-up math
(<code>w2_math</code>) are norm-referenced T-scores scaled by NCES to a
weighted mean of 50 and a standard deviation of 10 in each wave.
Socioeconomic status (<code>w1_ses</code>) and math self-efficacy
(<code>w1_math_efficacy</code>) are standardized continuous composites;
negative values represent substantive scores below the reference mean rather
than NCES reserve codes. The histograms below plot unweighted student counts
over non-missing observations for <code>w1_math</code>, <code>w2_math</code>,
<code>w1_math_efficacy</code>, and <code>w1_ses</code>.</p>
***/

webdoc stlog
local shown w1_math w2_math w1_math_efficacy w1_ses
foreach name of local shown {
    quietly count if !missing(`name')
    local n = strtrim(string(r(N), "%9.0fc"))
    histogram `name', bin(40) frequency name(`name', replace) nodraw ///
        fcolor("1 115 178") lcolor(white) lwidth(vthin) ///
        title(`"`: variable label `name'' (n = `n')"', size(medium)) ///
        xtitle("") ytitle("Students (unweighted)") ylabel(, angle(horizontal) format(%9.0fc) labsize(small))
}
graph combine `shown', cols(2) xsize(9) ysize(6.5) ///
    title("Unweighted distributions of observed continuous analysis variables", size(medium))
webdoc stlog close
webdoc graph, name(Graph) alt("Histograms of the two math scores, math self-efficacy, and SES")

/***
<h2>Categorical variable frequencies</h2>

<p>The frequency table summarizes all binary, categorical, and ordinal
variables in <code>hsls_crosswalk</code> other than the survey response
indicators tabulated above. For each variable, <code>Students</code> and
<code>Unweighted (%)</code> are computed over all students with a non-missing
value on that variable. <code>Weighted (%)</code> is the category's
percentage of total positive weight among students with both a non-missing
value and a positive weight, using the parent weight
(<code>w1_weight_parent</code>) for variables from the parent survey
(identified by NCES names beginning with <code>X1PAR</code>,
<code>X1P2</code>, or <code>X1FAM</code>) and the base-year student weight
(<code>w1_weight</code>) for all remaining variables.</p>
***/

webdoc stlog
* Survey response flags are reported in the sample table above
local categorical
local parent_items
foreach name of local names {
    if inlist("`type_`name''", "binary", "categorical", "ordinal") & !`: list name in flags' {
        local categorical `categorical' `name'
        if inlist(substr("`nces_`name''", 1, 5), "X1PAR", "X1FAM") | substr("`nces_`name''", 1, 4) == "X1P2" {
            local parent_items `parent_items' `name'
        }
    }
}
tempfile frequencies
local first 1
foreach name of local categorical {
    local weight = cond(`: list name in parent_items', "w1_weight_parent", "w1_weight")
    preserve
    quietly keep if !missing(`name')
    generate double weighted = cond(`weight' > 0 & !missing(`weight'), `weight', 0)
    generate double Students = 1
    collapse (sum) Students weighted, by(`name')
    generate str32 Variable = "`name'"
    generate double Value = `name'
    generate str100 Label = ""
    forvalues i = 1/`=_N' {
        local value = Value[`i']
        if "`derive_`name''" == "applies" {
            local text = cond(`value' == 1, "Answered", "Logical skip in the source variable")
        }
        else if "`: value label `name''" != "" {
            local text : label (`name') `value', strict
        }
        else if "`type_`name''" == "binary" {
            local text = cond(`value' == 1, "Yes", "No")
        }
        else local text
        quietly replace Label = `"`text'"' in `i'
    }
    quietly summarize Students
    generate double Percent = 100 * Students / r(sum)
    quietly summarize weighted
    generate double Weighted_percent = 100 * weighted / r(sum)
    keep Variable Value Label Students Percent Weighted_percent
    order Variable Value Label Students Percent Weighted_percent
    if !`first' quietly append using `frequencies'
    quietly save `frequencies', replace
    local first 0
    restore
}
preserve
use `frequencies', clear
* Appending puts the last variable first, so sort back to the crosswalk order
generate order = .
local i 0
foreach name of local categorical {
    quietly replace order = `++i' if Variable == "`name'"
}
sort order Value
drop order
format Value %9.0f
format Students %9.0fc
format Percent Weighted_percent %5.1f
label variable Students "Students"
label variable Percent "Unweighted (%)"
label variable Weighted_percent "Weighted (%)"
webdoc stlog close
html_table
restore

/***
<h2>Missing values by reason</h2>

<p>Comparing each variable in <code>hsls_clean</code> row by row against its
raw NCES source in <code>hsls_student</code> classifies every missing value
into one of three reasons:</p>

<ul>
<li><strong>Nonresponse</strong>: the survey or item applied to the student,
but no response was recorded. These values are unobserved within the target
subpopulation.</li>
<li><strong>Logical skip</strong>: the item did not apply to the student under
survey routing rules, placing the student outside the subpopulation for which
the variable is defined.</li>
<li><strong>Outside the flag</strong>: the raw file records an answer, but
<code>hsls_clean</code> sets the variable to missing unless an applicability
flag equals 1, such as parent 2's employment where there is no second
parent.</li>
</ul>

<p>The table reports unweighted student counts across all records in
<code>hsls_clean</code> for <code>Observed</code> and each missing-value
reason. For variables with any missing values, the bar chart plots each
reason as an unweighted percentage of all students in <code>hsls_clean</code>,
ordered by the nonresponse percentage.</p>
***/

webdoc stlog
preserve
tempfile reasons
postfile `post' str32 Variable str100 Label double(Observed Nonresponse Skip Outside) ///
    using `reasons'
foreach name of local names {
    local counts
    forvalues reason = 1/4 {
        quietly count if why_`name' == `reason'
        local counts `counts' (`=r(N)')
    }
    post `post' ("`name'") (`"`: variable label `name''"') `counts'
}
postclose `post'
use `reasons', clear
format Observed-Outside %9.0fc
label variable Skip "Logical skip"
label variable Outside "Outside the flag"
webdoc stlog close
html_table

webdoc stlog
foreach reason in Nonresponse Skip Outside {
    generate double share_`reason' = 100 * `reason' / `students'
}
keep if Nonresponse + Skip + Outside > 0
graph hbar (asis) share_Nonresponse share_Skip share_Outside, ///
    over(Variable, sort(share_Nonresponse) descending label(labsize(vsmall))) ///
    stack bar(1, color("1 115 178")) bar(2, color("222 143 5")) bar(3, color("2 158 115")) ///
    legend(order(1 "Nonresponse" 2 "Logical skip" 3 "Outside the flag") rows(1) size(small) symxsize(*0.4) colgap(*4) ///
    title("Reason", size(small))) ///
    ytitle("Share of sample (%, unweighted)") xsize(8) ysize(7) graphregion(margin(l+12 r+4)) ///
    title("Missing values by reason among variables with missing data", size(medium))
webdoc stlog close
webdoc graph, alt("Stacked bars of the percent of students missing each variable, by reason")
restore

/***
<h2>Joint missingness patterns</h2>

<p>Joint missingness is tabulated across the core analysis variables: the two
math scores (<code>w1_math</code>, <code>w2_math</code>), SES
(<code>w1_ses</code>), math self-efficacy (<code>w1_math_efficacy</code>), sex
(<code>w1_female</code>), race/ethnicity (<code>w1_race</code>), parents'
education (<code>w1_parents_edu</code>), and family income
(<code>w1_family_income</code>). Each row represents a combination of
observed (<code>·</code>) and missing (<code>X</code>) indicators, pooling all
missing-value reasons. <code>Students</code> is the unweighted count and
<code>Share of sample (%)</code> is the unweighted percentage of all records
in <code>hsls_clean</code>.</p>
***/

webdoc stlog
local analysis w1_math w2_math w1_ses w1_math_efficacy w1_female w1_race ///
    w1_parents_edu w1_family_income
local missing
foreach name of local analysis {
    generate byte m_`name' = missing(`name')
    label variable m_`name' "`name'"
    local missing `missing' m_`name'
}
preserve
contract `missing', freq(Students)
gsort -Students
egen Missing_variables = rowtotal(`missing')
foreach name of local missing {
    generate str2 `name'_ = cond(`name', "X", "·")
    label variable `name'_ "`: variable label `name''"
}
generate double Percent = 100 * Students / `students'
local patterns = _N
quietly summarize Students in 1/`=min(15, _N)'
local top = r(sum)
quietly keep in 1/`=min(15, _N)'
format Students %9.0fc
format Percent %5.1f
label variable Students "Students"
label variable Percent "Share of sample (%)"
label variable Missing_variables "Missing variables"
webdoc stlog close
html_table m_*_ Students Percent Missing_variables
restore

webdoc stlog
egen missing_count = rowtotal(`missing')
quietly count if missing_count == 0
display as result strtrim(string(r(N), "%9.0fc")) " students (" %3.1f 100 * r(N) / _N ///
    "%, unweighted) have observed values on all `: word count `analysis'' analysis variables."
display as result "There are `patterns' distinct missingness patterns; the 15 most frequent patterns cover " ///
    %3.1f 100 * `top' / _N "% of all students."
drop missing_count
webdoc stlog close

/***
<p>Missing values cluster by survey instrument: a student without a base-year
student survey misses the base-year math score, SES, and math self-efficacy
together, and nonresponse on the parent survey leaves parents' education and
family income missing.</p>

<p>The table below partitions <code>hsls_clean</code> by each survey response
indicator (<code>w1_responded</code>, <code>w1_parent_responded</code>,
<code>w2_responded</code>) and reports the unweighted percentage of students
in each response group (<code>No</code>, <code>Yes</code>, and
<code>Unknown</code> where the indicator itself is missing) who are missing
each analysis variable. The heatmap then shows, among students missing the
row variable, the unweighted percentage who are also missing the column
variable.</p>
***/

webdoc stlog
preserve
tempfile groups
postfile `post' str32 Variable str32 Flag str8 Group double Share using `groups'
foreach flag of local flags {
    foreach name of local analysis {
        foreach group in No Unknown Yes {
            local condition = cond("`group'" == "No", "`flag' == 0", ///
                cond("`group'" == "Yes", "`flag' == 1", "missing(`flag')"))
            quietly summarize m_`name' if `condition'
            if r(N) post `post' ("`name'") ("`flag'") ("`group'") (100 * r(mean))
        }
    }
}
postclose `post'
use `groups', clear
* One column per flag and group, in the order of the flags
generate column = ""
local columns
foreach flag of local flags {
    foreach group in No Unknown Yes {
        quietly count if Flag == "`flag'" & Group == "`group'"
        if r(N) {
            local c : word count `columns'
            local c = `c' + 1
            quietly replace column = "c`c'" if Flag == "`flag'" & Group == "`group'"
            local columns `columns' c`c'
            local header_c`c' "`flag' = `group'"
        }
    }
}
generate order = .
local i 0
foreach name of local analysis {
    quietly replace order = `++i' if Variable == "`name'"
}
keep Variable order column Share
quietly reshape wide Share, i(Variable order) j(column) string
sort order
foreach c of local columns {
    rename Share`c' `c'
    label variable `c' "`header_`c''"
    format `c' %5.1f
}
webdoc stlog close
html_table Variable `columns'
restore

webdoc stlog
* Unweighted conditional percentage missing the column variable given the row variable is missing
preserve
tempfile both
postfile `post' row column double Share using `both'
local r 0
foreach row of local analysis {
    local ++r
    quietly count if m_`row'
    local row_missing = r(N)
    local c 0
    foreach column of local analysis {
        local ++c
        quietly count if m_`row' & m_`column'
        post `post' (`r') (`c') (100 * r(N) / `row_missing')
    }
}
postclose `post'
use `both', clear
* Viridis colors in ten steps of 10 points
local viridis `""68 1 84" "72 40 120" "62 73 137" "49 104 142" "38 130 142" "31 158 137" "53 183 121" "109 205 89" "180 222 44" "253 231 37""'
generate step = min(floor(Share / 10), 9)
generate low = column - 0.5
generate high = column + 0.5
generate text = strtrim(string(Share, "%3.0f"))
local plots
local legend
local layer 0
forvalues s = 0/9 {
    quietly count if step == `s'
    if r(N) {
        local color : word `=`s' + 1' of `viridis'
        local plots `plots' (rbar low high row if step == `s', horizontal barwidth(1) ///
            fcolor("`color'") lcolor("`color'") lwidth(none))
        local ++layer
        local legend `legend' `layer' "`=`s' * 10'-`=`s' * 10 + 10'"
    }
}
local ticks
local i 0
foreach name of local analysis {
    local ticks `ticks' `++i' "`name'"
}
twoway `plots' ///
    (scatter row column if step >= 6, msymbol(none) mlabel(text) mlabposition(0) mlabcolor(black)) ///
    (scatter row column if step < 6, msymbol(none) mlabel(text) mlabposition(0) mlabcolor(white)), ///
    yscale(reverse) ylabel(`ticks', angle(0) nogrid labsize(vsmall)) ///
    xlabel(`ticks', angle(45) labsize(vsmall)) ytitle("Row variable missing", margin(r+16)) xtitle("Column variable also missing") ///
    graphregion(margin(l+8)) ///
    legend(order(`legend') cols(1) position(3) title("Conditional missing (%)", size(small)) size(small)) ///
    xsize(7.5) ysize(6) plotregion(margin(zero)) ///
    title("Unweighted share missing column variable among students missing row variable", size(small))
webdoc stlog close
webdoc graph, alt("Heat map of the percent of students missing one variable who also miss another")
restore

/***
<h2>Covariate differences between observed and missing cases</h2>

<p>When students with missing data differ systematically on observed
variables, complete-case estimation does not represent the full sample. The
tables below partition students by whether the first follow-up math score
(<code>w2_math</code>) or parents' education (<code>w1_parents_edu</code>) is
observed versus missing, and compare both groups on selected base-year
covariates. Within each group, unweighted means and unweighted sample
variances are computed over that group's non-missing values on the covariate
(<code>n (missing group, covariate observed)</code> gives the non-missing
covariate count in the group missing the target variable). The standardized
difference equals the unweighted mean in the missing group minus the
unweighted mean in the observed group, divided by the unweighted pooled
sample standard deviation,
<code>sqrt((var_observed + var_missing) / 2)</code>. Absolute standardized
differences exceeding roughly 0.1 indicate substantive covariate
imbalance.</p>

<p>The density plot displays unweighted kernel density estimates of observed
base-year math scores (<code>w1_math</code>) separately for students with
observed and missing first follow-up math scores (<code>w2_math</code>),
normalized independently within each group.</p>
***/

webdoc stlog
capture program drop compare
program define compare
    * Means of covariates for students with and without a value of missing_on
    syntax varname, covariates(varlist) saving(string)
    tempname post
    quietly postfile `post' str32 Variable double(Observed Missing Difference N) using `"`saving'"', replace
    foreach name of local covariates {
        quietly summarize `name' if !missing(`varlist')
        local mean = r(mean)
        local variance = r(Var)
        quietly summarize `name' if missing(`varlist')
        local pooled = sqrt((`variance' + r(Var)) / 2)
        post `post' ("`name'") (`mean') (r(mean)) ((r(mean) - `mean') / `pooled') (r(N))
    }
    postclose `post'
    preserve
    use `"`saving'"', clear
    format Observed Missing Difference %9.2f
    format N %9.0fc
    label variable Observed "Mean (`varlist' observed)"
    label variable Missing "Mean (`varlist' missing)"
    label variable Difference "Standardized difference"
    label variable N "n (missing group, covariate observed)"
    quietly save `"`saving'"', replace
    restore
end

tempfile followup parents
compare w2_math, covariates(w1_math w1_ses w1_math_efficacy w1_female w1_parents_edu) saving(`followup')
compare w1_parents_edu, covariates(w1_math w1_math_efficacy w1_female) saving(`parents')
webdoc stlog close
preserve
use `followup', clear
html_table
use `parents', clear
html_table
restore

webdoc stlog
* Gaussian kernels with Scott's bandwidth, SD times n^(-1/5), as seaborn uses
local plots
local i 0
foreach group in 0 1 {
    quietly summarize w1_math if m_w2_math == `group'
    local bandwidth = r(sd) * r(N)^(-1/5)
    local color = cond(`group', "222 143 5", "1 115 178")
    local plots `plots' (kdensity w1_math if m_w2_math == `group', kernel(gaussian) ///
        bwidth(`bandwidth') n(200) range(`=r(min) - 3 * `bandwidth'' `=r(max) + 3 * `bandwidth'') ///
        lcolor("`color'") lwidth(medthick) lpattern(`=cond(`group', "dash", "solid")'))
}
twoway `plots', xsize(7) ysize(4) ///
    legend(order(1 "First follow-up math observed" 2 "First follow-up math missing") rows(1)) ///
    xtitle("`: variable label w1_math'") ytitle("Density") ylabel(, angle(horizontal) format(%4.2f)) ///
    title("Unweighted base-year math density by first follow-up math availability", size(medium))
webdoc stlog close
webdoc graph, alt("Density curves of the base-year math score for students with and without a follow-up score")

/***
<h2>Pairwise associations among analysis variables</h2>

<p>The correlation matrix reports unweighted Pearson correlation coefficients
across the continuous and ordinal analysis variables (<code>w1_math</code>,
<code>w2_math</code>, <code>w1_math_efficacy</code>, <code>w1_ses</code>,
<code>w1_parents_edu</code>, and <code>w1_family_income</code>). Each entry is
computed via pairwise deletion over all students with non-missing values on
both variables in the pair, so sample composition varies across cells; the
accompanying count matrix gives the unweighted pairwise non-missing student
counts (with univariate non-missing counts on the diagonal). The
two-dimensional binned plot displays unweighted student counts across the
joint distribution of base-year and first follow-up math scores among
students with both scores observed.</p>
***/

webdoc stlog
local related w1_math w2_math w1_math_efficacy w1_ses w1_parents_edu w1_family_income
preserve
tempfile pairs
postfile `post' str32 Variable str32 With double(r N) using `pairs'
foreach row of local related {
    foreach column of local related {
        quietly correlate `row' `column'
        local rho = cond("`row'" == "`column'", 1, r(rho))
        post `post' ("`row'") ("`column'") (`rho') (r(N))
    }
}
postclose `post'
use `pairs', clear
generate order = .
local i 0
foreach name of local related {
    quietly replace order = `++i' if Variable == "`name'"
}
quietly reshape wide r N, i(Variable order) j(With) string
sort order
local rs
local ns
foreach name of local related {
    local rs `rs' r`name'
    local ns `ns' N`name'
    format r`name' %9.2f
    format N`name' %9.0fc
    label variable r`name' "`name'"
    label variable N`name' "`name'"
}
webdoc stlog close
html_table Variable `rs'
html_table Variable `ns'
restore

webdoc stlog
* Counts in square bins, 45 across, as a stand-in for seaborn's hexagons
local xtitle : variable label w1_math
local ytitle : variable label w2_math
preserve
keep if !missing(w1_math, w2_math)
local n = strtrim(string(_N, "%9.0fc"))
local bins 45
foreach axis in w1_math w2_math {
    quietly summarize `axis'
    local width_`axis' = (r(max) - r(min)) / `bins'
    generate double bin_`axis' = r(min) + (min(floor((`axis' - r(min)) / `width_`axis''), `bins' - 1) + 0.5) * `width_`axis''
}
contract bin_w1_math bin_w2_math, freq(students)
generate double low = bin_w2_math - `width_w2_math' / 2
generate double high = bin_w2_math + `width_w2_math' / 2
quietly summarize students
local most = r(max)
generate step = min(floor(10 * (students - 1) / `most'), 9)
local plots
local legend
local layer 0
forvalues s = 0/9 {
    quietly count if step == `s'
    if r(N) {
        local color : word `=`s' + 1' of `viridis'
        local plots `plots' (rbar low high bin_w1_math if step == `s', barwidth(`width_w1_math') ///
            fcolor("`color'") lcolor("`color'") lwidth(none))
        local ++layer
        local from = ceil(1 + `s' * `most' / 10)
        local legend `legend' `layer' "`from'+"
    }
}
twoway `plots', xsize(6) ysize(5.5) ///
    xtitle("`xtitle'") ytitle("`ytitle'") ylabel(, angle(horizontal)) ///
    legend(order(`legend') cols(1) position(3) title("Students", size(small)) size(small)) ///
    title("Base-year and first follow-up math scores (n = `n', unweighted)", size(medium))
restore
webdoc stlog close
webdoc graph, alt("Binned scatter plot of the follow-up math score against the base-year math score")

/***
<h2>Socioeconomic status imputations</h2>

<p>For a student with nonresponse on the parent survey, <code>w1_ses</code> is
the arithmetic mean of five NCES imputations (<code>w1_ses_imp1</code> through
<code>w1_ses_imp5</code>). Averaging the five draws eliminates within-student
imputation variance and attenuates between-student dispersion relative to any
single draw. Grouped by <code>w1_ses_imputed</code> over students with
non-missing SES records, the table reports unweighted student counts, the
student-level sample SD across the five imputations averaged over students in
the group, the maximum absolute discrepancy between <code>w1_ses</code> and
the five-imputation mean, and the unweighted between-student sample SDs of
<code>w1_ses</code> and of the first imputation
(<code>w1_ses_imp1</code>).</p>
***/

webdoc stlog
preserve
keep if !missing(w1_ses_imputed)
generate str32 Status = "0: All components reported" if w1_ses_imputed == 0
replace Status = "1: Parent-survey nonresponse" if w1_ses_imputed == 1
replace Status = "2: Partial component imputation" if w1_ses_imputed == 2
egen double spread = rowsd(w1_ses_imp1-w1_ses_imp5)
egen double imputation_mean = rowmean(w1_ses_imp1-w1_ses_imp5)
generate double gap = abs(w1_ses - imputation_mean)
generate double ses = w1_ses
generate double imp1 = w1_ses_imp1
generate double Students = 1
collapse (sum) Students (mean) spread (max) gap (sd) ses imp1, by(Status)
format Students %9.0fc
label variable Students "Students"
format spread gap ses imp1 %9.3f
label variable spread "Mean within-student imputation SD"
label variable gap "Max |w1_ses - imputation mean|"
label variable ses "Between-student SD of w1_ses"
label variable imp1 "Between-student SD of imputation 1"
webdoc stlog close
html_table
restore

/***
<h2>Summary of findings</h2>

<ul>
<li><strong>Sample weighting.</strong> Weighted by the base-year student weight
(<code>w1_weight</code>), the base-year math score (<code>w1_math</code>) has
a mean of 50 and a population SD of 10 over observed respondents, matching
the NCES T-score scaling. Its unweighted respondent mean is about 51,
indicating that unweighted respondents overrepresent higher-scoring students
relative to the weighted target population.</li>
<li><strong>Complete-case coverage.</strong> Across <code>hsls_clean</code>,
56.2% of students (unweighted) have non-missing values on all eight core
analysis variables. Most incomplete records reflect unit nonresponse to an
entire survey: the base-year student survey, the parent survey, or the first
follow-up student survey.</li>
<li><strong>Covariate imbalance under missingness.</strong> In unweighted
comparisons over each group's non-missing base-year observations, students
missing the first follow-up math score (<code>w2_math</code>) scored 0.44
pooled SDs lower on base-year math (<code>w1_math</code>) and 0.29 pooled SDs
lower on SES (<code>w1_ses</code>) than students with an observed first
follow-up math score. Students missing parents' education
(<code>w1_parents_edu</code>), nearly all due to parent-survey nonresponse,
also scored 0.44 pooled SDs lower on base-year math than students with
observed parents' education. Because complete-case restriction
disproportionately excludes lower-scoring and lower-SES students, subsequent
models must account for missing data rather than rely on listwise
deletion.</li>
<li><strong>SES imputation variance.</strong> Among students with
parent-survey nonresponse, <code>w1_ses</code> has an unweighted
between-student sample SD of 0.54, compared with 0.82 for a single
imputation. Across the five imputations, the average within-student sample SD
is 0.66. Treating <code>w1_ses</code> as an observed point value ignores that
imputation uncertainty and understates SES dispersion.</li>
</ul>
***/
