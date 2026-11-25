* 08-posterior-predictive.do: notebook of posterior predictive checks
*
* webdoc runs this do-file and writes the text, Stata output, tables, and
* graphs to outputs/private/notebooks/08-posterior-predictive.html. Run it
* through do/04_bayes_notebooks.do, after 05-sampling, which saves the
* HSLS:09 draws this notebook reads. The R and Python projects render the
* same notebook.

webdoc init `"$outputs_private_notebooks/08-posterior-predictive.html"', replace ///
    header(title("Posterior predictive checks") author("Erik") date("2026-11-18") width(60em)) ///
    logdir(08-posterior-predictive_files) ///
    grdir(08-posterior-predictive_files) ///
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
<script>window.MathJax = { tex: { inlineMath: [["$", "$"], ["\\(", "\\)"]] } };</script>
<script src="https://cdn.jsdelivr.net/npm/mathjax@3.2.2/es5/tex-chtml.js"></script>

<h1>Posterior predictive checks</h1>

<p>Erik, 2026-11-18</p>

<p>A fitted model is also a generator of data. For each posterior draw,
simulate a replicated data set: new follow-up scores for the same students,
from the model with that draw's parameters. Together the replications form the
posterior predictive distribution: the data the model expects, given what it
learned. A posterior predictive check compares the observed data with the
replications. Where the observed data look unlike the replications, the model
misses something.</p>

<p>The check never proves a model right. It finds the features of the data a
model fails to reproduce, so the analyst can judge whether they matter for the
question. The notebook runs the checks on simulated students, where the model
is true by construction, and then on HSLS:09, using the draws saved by
<code>05-sampling</code>.</p>
***/

webdoc stlog
bayes_analysis_sample, clear
tempfile hsls
quietly save `hsls'
local n_hsls = _N

use `"$outputs_private_models/hsls_regression_draws.dta"', clear
if "`: char _dta[bayes_n]'" != "`n_hsls'" {
    display as error "The saved draws come from a different sample. Rerun 05-sampling."
    exit 459
}
tempfile hsls_draws
quietly save `hsls_draws'

* One seed for the simulated students and the replications
set seed 808
webdoc stlog close

/***
<h2>Test statistics</h2>

<p>A test statistic summarizes a data set in one number. The check computes it
for the observed data and for each replication. The posterior predictive
p-value is the share of replications whose statistic is at least as large as
the observed one. Values near 0 or 1 mean the observed statistic is unusual
under the model. A value in between means the check found no discrepancy for
that statistic, which is weaker than saying the model is right about it.
Statistics the model fits directly, such as the mean, tend to give values near
0.5 because the same data informed the fit. The tables also give the count
behind each p-value: the number of replications whose statistic is at least as
large as the observed one.</p>

<p>The replications are matrices of thousands of draws by thousands of
students, so the checks run in Mata. The SD and the skewness use the
population formulas, dividing by $n$, and the percentiles interpolate as numpy
does.</p>
***/

webdoc stlog
capture mata mata drop ppc_q7() ppc_statistics() ppc_check()
mata:
// Quantile by linear interpolation between sorted values (type 7)
real scalar ppc_q7(real colvector sorted, real scalar p)
{
    real scalar h, low
    h = (rows(sorted) - 1) * p + 1
    low = floor(h)
    return(sorted[low] + (h - low) * (sorted[min((low + 1, rows(sorted)))] - sorted[low]))
}

// Mean, SD, minimum, maximum, skewness, 5th and 95th percentiles, share above 70
real rowvector ppc_statistics(real colvector y)
{
    real colvector s
    real scalar m, m2, m3
    m = mean(y)
    m2 = mean((y :- m):^2)
    m3 = mean((y :- m):^3)
    s = sort(y, 1)
    return((m, sqrt(m2), s[1], s[rows(s)], m3 / m2^1.5, ppc_q7(s, 0.05), ppc_q7(s, 0.95), mean(y :> 70)))
}

// One row per statistic: observed, replicated median, 5% and 95%, and the p-value
void ppc_check(real colvector y, real matrix y_rep, string scalar result)
{
    real matrix replicated, table
    real rowvector observed
    real colvector sorted
    real scalar d, k
    replicated = J(rows(y_rep), 8, .)
    for (d = 1; d <= rows(y_rep); d++) {
        replicated[d, .] = ppc_statistics(y_rep[d, .]')
    }
    observed = ppc_statistics(y)
    table = J(8, 6, .)
    for (k = 1; k <= 8; k++) {
        sorted = sort(replicated[., k], 1)
        table[k, .] = (observed[k], ppc_q7(sorted, 0.5), ppc_q7(sorted, 0.05), ppc_q7(sorted, 0.95),
            mean(replicated[., k] :>= observed[k]), sum(replicated[., k] :>= observed[k]))
    }
    st_matrix(result, table)
}
end

capture program drop show_check
program define show_check
    * The check's matrix as an HTML table
    args result
    preserve
    clear
    quietly svmat `result'
    generate str16 statistic = ""
    local names `" "Mean" "SD" "Minimum" "Maximum" "Skewness" "5th percentile" "95th percentile" "Share above 70" "'
    forvalues i = 1/8 {
        quietly replace statistic = "`: word `i' of `names''" in `i'
    }
    order statistic
    label variable statistic " "
    label variable `result'1 "Observed"
    label variable `result'2 "Replicated, median"
    label variable `result'3 "Replicated, 5%"
    label variable `result'4 "Replicated, 95%"
    label variable `result'5 "p-value"
    label variable `result'6 "Replications at least as large"
    format `result'1-`result'5 %9.3f
    format `result'6 %9.0fc
    html_table
end

capture program drop overlay
program define overlay
    * Density of the observed scores (black) and of 50 replications (blue),
    * Gaussian kernels with Scott's bandwidth, as seaborn uses
    syntax varname, replications(varlist) title(string)
    local plots
    foreach v of local replications {
        quietly summarize `v'
        local plots `plots' (kdensity `v', kernel(gaussian) bwidth(`=r(sd) * r(N)^(-1/5)') n(150) ///
            lcolor("86 180 233") lwidth(vthin))
    }
    quietly summarize `varlist'
    local plots `plots' (kdensity `varlist', kernel(gaussian) bwidth(`=r(sd) * r(N)^(-1/5)') n(150) ///
        lcolor(black) lwidth(thick))
    twoway `plots', legend(off) xtitle("Follow-up math score") ytitle("Density") ///
        ylabel(, angle(horizontal) format(%4.2f)) title("`title'", size(medium)) xsize(7) ysize(4)
end
webdoc stlog close

/***
<h2>Simulated data</h2>

<p>Stan draws the replications itself, in the <code>generated quantities</code>
block of the program. Stata 14's <code>bayesmh</code> has no counterpart;
<code>bayespredict</code> came in Stata 16. The cell fits 500 simulated
students with <code>bayes_sample</code> and draws the replications in Mata with
the same formula: for each draw and student, the expected score plus normal
noise with the draw's $\sigma$. That gives a 4,000 by 500 matrix.</p>
***/

webdoc stlog
bayes_simulate, n(500) alpha(50.4) beta(0.7 1.8) sigma(6.6) clear
tempfile fake fake_draws
quietly save `fake'
bayes_sample w2_math w1_math_c w1_ses, saving(`fake_draws')
mata: X = st_data(., ("w1_math_c", "w1_ses"))
mata: y = st_data(., "w2_math")
use `fake_draws', clear
mata: P = st_data(., ("alpha", "beta1", "beta2", "sigma"))
mata: y_rep = P[., 1] :+ P[., 2..3] * X' + P[., 4] :* rnormal(rows(P), rows(X), 0, 1)
mata: printf("y_rep: %f draws by %f students\n", rows(y_rep), cols(y_rep))

use `fake', clear
forvalues r = 1/50 {
    quietly generate double rep`r' = .
}
mata: st_store(., st_varindex("rep1")..st_varindex("rep50"), y_rep[1..50, .]')
overlay w2_math, replications(rep1-rep50) title("Simulated data (black) and 50 replications (blue)")
* Every 4th draw: 1,000 replications spread evenly over the four chains
mata: ppc_check(y, y_rep[(1::1000) :* 4 :- 3, .], "fake_check")
webdoc stlog close
webdoc graph, alt("Density of the simulated scores and of 50 replications")
show_check fake_check

/***
<p>When the model is true, the observed statistics sit inside the spread of the
replicated ones, and the p-values fall between 0 and 1 with no pattern.
Here every observed statistic sits inside the central 90% of its
replications, the skewness only just, with a p-value of 0.056. The statistics use 1,000 of the 4,000 replications, every fourth draw,
so all four chains contribute. With 1,000 replications, a p-value near 0.5 has
a simulation standard error of about 0.016, so differences in the second
decimal are noise.</p>

<h2>HSLS:09</h2>

<p>For 18,623 students, a replication for every one of the 4,000 draws would
hold about 75 million values. The cell draws one replication for each of 400
posterior draws, chosen at random:
$y^{\text{rep}}_i = \alpha + X_i \beta + \sigma \varepsilon_i$ with
$\varepsilon_i \sim \text{Normal}(0, 1)$.</p>
***/

webdoc stlog
use `hsls', clear
mata: X = st_data(., ("w1_math_c", "w1_ses"))
mata: y = st_data(., "w2_math")
use `hsls_draws', clear
quietly sample 400, count
mata: P = st_data(., ("alpha", "beta1", "beta2", "sigma"))
mata: y_rep = P[., 1] :+ P[., 2..3] * X' + P[., 4] :* rnormal(rows(P), rows(X), 0, 1)
mata: printf("y_rep: %f draws by %f students\n", rows(y_rep), cols(y_rep))

use `hsls', clear
forvalues r = 1/50 {
    quietly generate double rep`r' = .
}
mata: st_store(., st_varindex("rep1")..st_varindex("rep50"), y_rep[1..50, .]')
overlay w2_math, replications(rep1-rep50) title("HSLS:09 follow-up scores (black) and 50 replications (blue)")
drop rep*
webdoc stlog close
webdoc graph, alt("Density of the HSLS:09 follow-up scores and of 50 replications")

webdoc stlog
mata: ppc_check(y, y_rep, "hsls_check")
webdoc stlog close
show_check hsls_check

/***
<p>The model reproduces the mean and SD, which a linear regression with an
intercept fits by construction, and the upper part of the distribution: the
95th percentile and the share above 70. The tails are where it fails:</p>

<ul>
<li><strong>Minimum and maximum.</strong> Every replication has a lower minimum
and a higher maximum than the observed scores. The observed minimum is about
8 points above the median replicated minimum, and the observed maximum
about 6 points below the median replicated maximum. Normal errors have no
bounds and the test's scores do. <code>03-simulating-the-data</code>
anticipated this.</li>
<li><strong>Lower tail.</strong> The observed 5th percentile is below 395
of the 400 replicated ones, while the observed minimum is above all of them.
More students score in the low 30s than the model expects, and none score far
below that.</li>
<li><strong>Skewness.</strong> The observed scores are slightly right-skewed,
more than any replication.</li>
</ul>

<p>The discrepancies are in the tails, so they matter most for questions about
the lowest and highest scorers. They say the normal distribution is an
approximation for this test score.</p>

<h2>Spread across base-year scores</h2>

<p>The model assumes the same residual SD, $\sigma$, for every student. The
check splits students into ten groups by base-year score and compares the SD of
the follow-up score within each group with the same SD in the
replications.</p>
***/

webdoc stlog
* Deciles of base-year math, cut at the 10th to 90th percentiles as pandas qcut does
hsls_quantile w1_math, percentiles(10 20 30 40 50 60 70 80 90)
generate byte decile = 0
foreach p in 10 20 30 40 50 60 70 80 90 {
    quietly replace decile = decile + (w1_math > r(p`p'))
}
mata: g = st_data(., "decile")
mata: w1 = st_data(., "w1_math")
mata:
spread = J(10, 5, .)
for (k = 0; k <= 9; k++) {
    idx = select((1::rows(g)), g :== k)
    replicated = J(rows(y_rep), 1, .)
    for (d = 1; d <= rows(y_rep); d++) {
        replicated[d] = sqrt(variance(y_rep[d, idx]'))
    }
    replicated = sort(replicated, 1)
    spread[k + 1, .] = (ppc_q7(sort(w1[idx], 1), 0.5), sqrt(variance(y[idx])),
        ppc_q7(replicated, 0.5), ppc_q7(replicated, 0.05), ppc_q7(replicated, 0.95))
}
st_matrix("spread", spread)
end
preserve
clear
quietly svmat spread
rename (spread1 spread2 spread3 spread4 spread5) (middle observed replicated low high)
twoway (rarea low high middle, fcolor("86 180 233") lcolor("86 180 233")) ///
    (connected observed middle, msymbol(O) mcolor(black) lcolor(black)), ///
    legend(order(1 "Replications, central 90%" 2 "Observed") rows(1)) ///
    xtitle("Base-year math score, median of the decile") ytitle("SD of follow-up score within the decile") ///
    ylabel(, angle(horizontal) format(%3.1f)) ///
    title("Spread of follow-up scores by base-year decile", size(medium)) xsize(7) ysize(4)
webdoc stlog close
webdoc graph, alt("Observed and replicated SD of the follow-up score within each base-year decile")
generate byte decile = _n - 1
keep decile middle observed replicated
order decile
label variable decile "Decile"
label variable middle "Median base-year score"
label variable observed "Observed SD"
label variable replicated "Replicated SD, median"
format middle observed replicated %9.2f
html_table
restore

/***
<p>The observed SD in the middle deciles scatters around the replicated SD. At
the ends it does not. In the top decile, the observed SD is well below the
replicated one: the model overpredicts the spread among the students who scored
highest in the base year. A ceiling on the follow-up test is one explanation,
since it would bunch top scorers together; the check alone cannot confirm it.
The replicated SD rises
in the outer deciles because those deciles span a wider range of base-year
scores, and the model passes that range on to the expected follow-up score. The
observed SD does not rise at the top. A model with a residual SD that varies
with the base-year score, or an outcome model with bounds, might fit better;
it would need the same check.</p>

<h2>Group means the model leaves out</h2>

<p>The model has no term for race and ethnicity. If groups differ in follow-up
scores beyond what base-year math and SES predict, the replications will miss
their means. The check compares each group's observed mean follow-up score with
the replicated means for the same students. Missing race is its own group. The
group names are the value labels of <code>w1_race</code>, from the
data spec.</p>
***/

webdoc stlog
generate byte race = cond(missing(w1_race), 9, w1_race)
mata: race = st_data(., "race")
mata:
codes = uniqrows(race)
groups = J(rows(codes), 5, .)
for (k = 1; k <= rows(codes); k++) {
    idx = select((1::rows(race)), race :== codes[k])
    observed = mean(y[idx])
    replicated = J(rows(y_rep), 1, .)
    for (d = 1; d <= rows(y_rep); d++) {
        replicated[d] = mean(y_rep[d, idx]')
    }
    sorted = sort(replicated, 1)
    groups[k, .] = (codes[k], rows(idx), observed, ppc_q7(sorted, 0.05), ppc_q7(sorted, 0.95))
    st_numscalar("p" + strofreal(codes[k]), mean(replicated :>= observed))
}
st_matrix("groups", groups)
end
* The group names, kept before the data and their labels are cleared
local labels : value label w1_race
quietly levelsof race, local(codes)
foreach code of local codes {
    local name`code' = cond(`code' == 9, "Missing", "`: label `labels' `code''")
}
preserve
clear
quietly svmat groups
rename (groups1 groups2 groups3 groups4 groups5) (race students observed low high)
quietly generate double p = .
quietly generate str60 group = ""
forvalues i = 1/`=_N' {
    local code = race[`i']
    quietly replace p = scalar(p`code') in `i'
    quietly replace group = "`name`code''" in `i'
}
gsort -students
generate int y = _n
forvalues i = 1/`=_N' {
    label define group `i' "`=group[`i']' (n = `=strtrim(string(students[`i'], "%9.0fc"))')", modify
}
label values y group
twoway (rspike low high y, horizontal lcolor("86 180 233") lwidth(vthick)) ///
    (scatter y observed, msymbol(O) mcolor(black)), ///
    legend(order(1 "Replications, central 90%" 2 "Observed") rows(1) size(small)) ///
    ylabel(1(1)`=_N', valuelabel angle(horizontal) labsize(small) nogrid) yscale(reverse) ytitle("") ///
    xtitle("Mean follow-up math score") ///
    title("Group means: observed and replicated", size(medium)) xsize(8) ysize(4.5)
webdoc stlog close
webdoc graph, alt("Observed mean follow-up score of each race and ethnicity group with the central 90% of replicated means")
keep group students observed low high p
order group
label variable group " "
label variable students "Students"
label variable observed "Observed mean"
label variable low "Replicated, 5%"
label variable high "Replicated, 95%"
label variable p "p-value"
format students %9.0fc
format observed low high p %9.2f
html_table
restore

/***
<p>Two groups fall outside the replicated band. The model underpredicts the
mean follow-up score of Asian students and overpredicts that of Black students,
given each group's own base-year math and SES. These are prediction errors for
group averages, not adjusted comparisons between groups: an estimate of how
groups differ at the same base-year math and SES needs a model with group terms
and a stated set of covariate values to compare at. A relationship that is not
linear could also produce errors like these, since the groups differ in their
base-year scores and SES. The other groups fall inside or at the edge of their
bands, and the small groups have wide bands. Whether to add race to the model
depends on the question. For describing how relative standing persists, the
misfit says one regression line averages over groups it does not fit equally
well. That is a substantive finding, not only a technical one.</p>

<h2>Predictions for one student</h2>

<p>The posterior predictive distribution also answers a question the posterior
summary does not: what score to expect for one new student. For a student with
a base-year score of 50 and SES of 0, the cell compares two intervals:</p>

<ul>
<li>the 90% interval for the expected score, the average over all such
students, which reflects uncertainty about the parameters only;</li>
<li>the 90% predictive interval for one student's score, which adds the
student-level variation $\sigma$.</li>
</ul>
***/

webdoc stlog
use `hsls_draws', clear
generate double expected = alpha
generate double predicted = expected + sigma * rnormal()
tempname post
tempfile one
postfile `post' str40 quantity double(low high) using `one'
bayes_interval expected, level(90)
post `post' ("Expected score, average student") (r(low)) (r(high))
bayes_interval predicted, level(90)
post `post' ("Score of one student") (r(low)) (r(high))
postclose `post'
webdoc stlog close
preserve
use `one', clear
label variable quantity " "
label variable low "5%"
label variable high "95%"
format low high %9.2f
html_table
restore

/***
<p>The expected score is known to within a fraction of a point. One student's
score is not: the predictive interval spans about 22 points. With this much
data, almost all the uncertainty in a prediction for an individual comes from
the variation between students, not from the parameters.</p>
***/
