* 01-hsls-descriptives.do: notebook that describes the cleaned HSLS:09 file
*
* webdoc runs this do-file and writes the text blocks, Stata output, tables,
* and graphs to outputs/private/notebooks/01-hsls-descriptives.html. Run it
* through do/03_describe_hsls.do, which raises maxvar for the raw file first.
* The R and Python projects render the same notebook from
* notebooks/01-hsls-descriptives.qmd and .ipynb.

webdoc init `"$outputs_private_notebooks/01-hsls-descriptives.html"', replace ///
    header(title("HSLS:09 descriptives") author("Erik") date("2026-11-18") width(60em)) ///
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

<h1>HSLS:09 descriptives</h1>

<p>Erik, 2026-11-18</p>

<p>This notebook describes the cleaned HSLS:09 file before any model uses it:
each variable's type, summary statistics, and distribution, then its missing
values, why they are missing, and how they occur together.
<code>docs/codebook.md</code> lists every value and reserve code.
<code>docs/missing-data.md</code> explains the codes.</p>

<p>Counts are unweighted. Means and percentages are given both unweighted, over
the students in the file, and weighted to the population of 9th graders in
fall 2009.</p>

<p>The notebook reads private data, so it renders to
<code>outputs/private/notebooks</code>. It shows summaries only, never
individual records. Stata 14 has no <code>dyndoc</code>, so
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
<h2>Variables</h2>

<p>Each variable's type comes from the crosswalk. The stored type is how the
file holds it: every variable except the student ID is numeric, and
categories are codes with value labels.</p>
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
label variable Stored "Stored as"
label variable Distinct "Distinct values"
label variable Missing "Missing (%)"
format Distinct Observed %9.0fc
format Missing %5.1f
webdoc stlog close
html_table
restore

/***
<h2>Sample</h2>

<p>HSLS:09 sampled 23,503 9th graders in fall 2009. A weight above 0 marks a
student who counts toward estimates with that weight: the base-year student
weight needs a base-year student survey, the parent weight a parent survey,
and the panel weight both student surveys.</p>
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
label variable Share "Share (%)"
format Students %9.0fc
format Share %5.1f
webdoc stlog close
html_table
restore

webdoc stlog
* Who answered which survey. Missing means the response status itself is unknown.
preserve
generate str w1_survey = cond(w1_responded == 1, "Base-year survey", "No base-year survey") ///
    if !missing(w1_responded)
generate str w2_survey = cond(w2_responded == 1, "Follow-up survey", "No follow-up survey")
replace w2_survey = "Status unknown" if missing(w2_responded)
tabulate w1_survey w2_survey
restore
webdoc stlog close

/***
<h2>Continuous variables</h2>

<p>The weighted columns use the weight that matches the variable's source:
the base-year student weight for base-year variables, and the panel weight
for the first follow-up math score. Weighted SDs are population SDs.
Quantiles interpolate linearly between the sorted values, as R and pandas do
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
<p>The math scores are T-scores, scaled by NCES to a weighted mean of 50 and
SD of 10 in each wave. SES and math self-efficacy are standardized
composites, so their negative values are real values, not reserve codes.</p>
***/

webdoc stlog
local shown w1_math w2_math w1_math_efficacy w1_ses
foreach name of local shown {
    quietly count if !missing(`name')
    local n = strtrim(string(r(N), "%9.0fc"))
    histogram `name', bin(40) frequency name(`name', replace) nodraw ///
        fcolor("1 115 178") lcolor(white) lwidth(vthin) ///
        title(`"`: variable label `name'' (n = `n')"', size(medium)) ///
        xtitle("") ytitle("Students") ylabel(, angle(horizontal) format(%9.0fc) labsize(small))
}
graph combine `shown', cols(2) xsize(9) ysize(6.5) ///
    title("Distributions of the continuous variables, observed values", size(medium))
webdoc stlog close
webdoc graph, name(Graph) alt("Histograms of the two math scores, math self-efficacy, and SES")

/***
<h2>Categorical variables</h2>

<p>Percentages are of the students with an observed value. The weighted
percentages use the base-year student weight, or the parent weight for
variables from the parent survey.</p>
***/

webdoc stlog
* The response flags are in the sample table above
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
label variable Weighted_percent "Weighted percent"
webdoc stlog close
html_table
restore

/***
<h2>Missing values by reason</h2>

<p>Each missing value has one of three reasons, from the raw NCES codes:</p>

<ul>
<li><strong>Nonresponse</strong>: the question applied and went unanswered.
An analysis imputes these or models them.</li>
<li><strong>Logical skip</strong>: the question did not apply. An analysis of
that variable usually drops these students.</li>
<li><strong>Outside the flag</strong>: the raw file has an answer, but the
variable applies only where a flag is 1, such as parent 2's employment where
there is no second parent.</li>
</ul>
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
    legend(order(1 "Nonresponse" 2 "Logical skip" 3 "Outside the flag") rows(1) size(small) symxsize(*0.4) colgap(*4)) ///
    ytitle("Students (%)") xsize(8) ysize(7) graphregion(margin(l+12 r+4)) ///
    title("Missing values by reason, variables with any missing", size(medium))
webdoc stlog close
webdoc graph, alt("Stacked bars of the percent of students missing each variable, by reason")
restore

/***
<h2>Missingness patterns</h2>

<p>The patterns below use the variables a first model is likely to use: the
two math scores, SES, math self-efficacy, sex, race, parents' education, and
family income. Each row is a combination of observed (<code>·</code>) and
missing (<code>X</code>) values, counting a missing value for any reason.</p>
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
label variable Missing_variables "Missing variables"
webdoc stlog close
html_table m_*_ Students Percent Missing_variables
restore

webdoc stlog
egen missing_count = rowtotal(`missing')
quietly count if missing_count == 0
display as result strtrim(string(r(N), "%9.0fc")) " students (" %3.1f 100 * r(N) / _N ///
    "%) have all `: word count `analysis'' variables."
display as result "`patterns' distinct patterns. The 15 above cover " ///
    %3.1f 100 * `top' / _N "% of students."
drop missing_count
webdoc stlog close

/***
<p>Missing values cluster by survey. A student without a base-year survey
misses the base-year score, SES, and self-efficacy together. A parent who did
not respond leaves parents' education and income missing. The next table
gives the share missing on each variable within each response group.</p>
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
* Of students missing the row variable, the share also missing the column variable
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
    xlabel(`ticks', angle(45) labsize(vsmall)) ytitle("Missing", margin(r+16)) xtitle("Also missing") ///
    graphregion(margin(l+8)) ///
    legend(order(`legend') cols(1) position(3) title("Percent", size(small)) size(small)) ///
    xsize(7.5) ysize(6) plotregion(margin(zero)) ///
    title("Share missing the column variable, among students missing the row variable", size(small))
webdoc stlog close
webdoc graph, alt("Heat map of the percent of students missing one variable who also miss another")
restore

/***
<h2>Missingness and observed values</h2>

<p>If the students missing a value differ on what is observed, a
complete-case analysis describes a different group than the sample. The table
compares students with and without each outcome on base-year values that are
observed for both groups. The standardized difference is the difference in
means divided by the pooled SD. Values beyond about 0.1 are usually read as a
meaningful imbalance.</p>
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
    label variable Observed "Mean, `varlist' observed"
    label variable Missing "Mean, `varlist' missing"
    label variable Difference "Standardized difference"
    label variable N "n missing with a value"
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
    legend(order(1 "Follow-up score observed" 2 "Follow-up score missing") rows(1)) ///
    xtitle("`: variable label w1_math'") ytitle("Density") ylabel(, angle(horizontal) format(%4.2f)) ///
    title("Base-year math score by whether the follow-up score is observed", size(medium))
webdoc stlog close
webdoc graph, alt("Density curves of the base-year math score for students with and without a follow-up score")

/***
<h2>Relationships</h2>

<p>Correlations use all students with both values, so each pair can rest on a
different group. The table after the matrix gives each pair's count.</p>
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
    title("Math scores in the two waves (n = `n')", size(medium))
restore
webdoc stlog close
webdoc graph, alt("Binned scatter plot of the follow-up math score against the base-year math score")

/***
<h2>SES imputations</h2>

<p>For a student whose parent did not respond, <code>w1_ses</code> is the mean
of five imputations. The five spread around that mean, and averaging them
removes the spread. The table shows, by imputation status, the SD across the
five imputations within a student, averaged over students, and the SD of
<code>w1_ses</code> and of the first imputation.</p>
***/

webdoc stlog
preserve
keep if !missing(w1_ses_imputed)
generate str32 Status = "0: all components reported" if w1_ses_imputed == 0
replace Status = "1: parent did not respond" if w1_ses_imputed == 1
replace Status = "2: some components imputed" if w1_ses_imputed == 2
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
label variable spread "SD across imputations, mean"
label variable gap "Mean minus imputation mean, largest"
label variable ses "SD of w1_ses"
label variable imp1 "SD of imputation 1"
webdoc stlog close
html_table
restore

/***
<h2>Summary</h2>

<ul>
<li><strong>Weights.</strong> The base-year math score has a weighted mean of
50 and SD of 10, as NCES scaled it. The unweighted mean is about 51, so the
sample leans toward higher scorers.</li>
<li><strong>Complete cases.</strong> 56.2% of students have all eight analysis
variables. Most of the rest miss a whole survey: the base-year student
survey, the parent survey, or the follow-up.</li>
<li><strong>Who is missing.</strong> Students without a follow-up math score
scored 0.44 SD lower in the base year and had SES 0.29 SD lower than students
with one. Students missing parents' education, nearly all because the parent
did not respond, scored 0.44 SD lower too. A complete-case analysis drops
lower-scoring, lower-SES students, so the models in this series need to
address missing values rather than drop them.</li>
<li><strong>SES.</strong> Among students whose parent did not respond,
<code>w1_ses</code> has an SD of 0.54, against 0.82 for a single imputation.
The five imputations differ by an average SD of 0.66 within a student.
Treating <code>w1_ses</code> as observed ignores that uncertainty.</li>
</ul>
***/
