* 07-posterior-summary.do: notebook that summarizes the posterior draws
*
* webdoc runs this do-file and writes the text, Stata output, tables, and
* graphs to outputs/notebooks/07-posterior-summary.html. Run it
* through do/04_bayes_notebooks.do, after 05-sampling, which saves the
* HSLS:09 draws this notebook reads. The R and Python projects render the
* same notebook.

webdoc init `"$outputs_notebooks/07-posterior-summary.html"', replace ///
    header(title("Posterior summaries") author("Erik") date("2026-11-18") width(60em)) ///
    logdir(07-posterior-summary_files) ///
    grdir(07-posterior-summary_files) ///
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

<h1>Posterior summaries</h1>

<p>Erik, 2026-11-18</p>

<p>A posterior is a distribution, and the draws are a sample from it. Every
summary in this notebook is computed the same way: do a calculation once per
draw, then summarize the results across draws. That covers the parameters
themselves, probabilities of statements about them, and quantities built from
them, such as the expected score for a given student or the variance the model
explains.</p>

<p>The notebook checks the summaries on a simulated fit with known parameters,
then applies them to the HSLS:09 draws saved by <code>05-sampling</code>. Run
that notebook first.</p>
***/

webdoc stlog
bayes_analysis_sample, clear
tempfile hsls
quietly save `hsls'
local n_hsls = _N

* The HSLS:09 draws and the settings they were sampled with, from 05-sampling
use `"$outputs_models/hsls_regression_draws.dta"', clear
if "`: char _dta[bayes_n]'" != "`n_hsls'" {
    display as error "The saved draws come from a different sample. Rerun 05-sampling."
    exit 459
}
tempfile hsls_draws
quietly save `hsls_draws'
display as result strtrim(string(_N, "%9.0fc")) " draws of alpha, beta1, beta2, sigma"
display as result "Priors: `: char _dta[bayes_priors]'"
display as result "Centering: `: char _dta[bayes_center]'"

* One seed for the simulated students and the chains
set seed 707
webdoc stlog close

/***
<h2>Summaries of each parameter</h2>

<p>The program below gives the usual summaries for each parameter:</p>

<ul>
<li><strong>Mean and median.</strong> For a symmetric posterior they
agree.</li>
<li><strong>SD</strong> of the draws, the Bayesian counterpart of a standard
error.</li>
<li><strong>Central intervals</strong>: the 5th to 95th and 2.5th to 97.5th
percentiles.</li>
<li><strong>Highest-density interval (HDI)</strong>: the narrowest interval
holding 95% of the draws. For a symmetric, single-peaked posterior it matches
the central interval; for a skewed one, such as the posterior of an SD, it
shifts toward the mode. For a posterior with several peaks, the highest-density
region can be split into pieces, and a single interval does not describe
it.</li>
</ul>

<p>The Monte Carlo standard error of each summary is in
<code>06-diagnostics</code>, which has the chain structure it needs.</p>
***/

webdoc stlog
capture program drop hdi
program define hdi, rclass
    * Slide a window holding the given share of the sorted draws, keep the
    * narrowest. A window from position i to i + width holds width + 1 draws.
    syntax varname [, level(real 95)]
    preserve
    keep `varlist'
    sort `varlist'
    local width = ceil(`level' / 100 * _N) - 1
    tempvar span
    quietly generate double `span' = `varlist'[_n + `width'] - `varlist'
    quietly summarize `span'
    quietly keep if `span' == r(min)
    return scalar low = `varlist'[1]
    return scalar high = `varlist'[1] + `span'[1]
end

capture program drop summarize_draws
program define summarize_draws
    * One row per variable of the draws in memory, saved to a file
    syntax varlist, saving(string)
    tempname post
    quietly postfile `post' str32 parameter double(mean median sd p5 p95 p2_5 p97_5 hdi_low hdi_high) ///
        using `saving', replace
    foreach name of local varlist {
        quietly summarize `name'
        local mean = r(mean)
        local sd = r(sd)
        bayes_interval `name', level(0)
        local median = r(low)
        bayes_interval `name', level(90)
        local p5 = r(low)
        local p95 = r(high)
        bayes_interval `name', level(95)
        local p2_5 = r(low)
        local p97_5 = r(high)
        hdi `name'
        post `post' ("`name'") (`mean') (`median') (`sd') (`p5') (`p95') (`p2_5') (`p97_5') ///
            (r(low)) (r(high))
    }
    postclose `post'
end

capture program drop label_summary
program define label_summary
    label variable parameter " "
    label variable mean "Mean"
    label variable median "Median"
    label variable sd "SD"
    label variable p5 "5%"
    label variable p95 "95%"
    label variable p2_5 "2.5%"
    label variable p97_5 "97.5%"
    label variable hdi_low "HDI 95% low"
    label variable hdi_high "HDI 95% high"
    quietly ds parameter, not
    format `r(varlist)' %9.3f
end
webdoc stlog close

/***
<h3>Simulated data</h3>

<p>1,000 simulated students with known parameters, fitted with the weak
priors.</p>
***/

webdoc stlog
bayes_simulate, n(1000) alpha(50.4) beta(0.7 1.8) sigma(6.6) clear
tempfile fake_draws fake_summary
bayes_sample w2_math w1_math_c w1_ses, saving(`fake_draws')
use `fake_draws', clear
summarize_draws alpha beta1 beta2 sigma, saving(`fake_summary')
webdoc stlog close
preserve
use `fake_summary', clear
generate double truth = cond(_n == 1, 50.4, cond(_n == 2, 0.7, cond(_n == 3, 1.8, 6.6)))
label_summary
label variable truth "Truth"
html_table
restore

/***
<h3>HSLS:09</h3>
***/

webdoc stlog
use `hsls_draws', clear
tempfile hsls_summary
summarize_draws alpha beta1 beta2 sigma, saving(`hsls_summary')
webdoc stlog close
preserve
use `hsls_summary', clear
label_summary
html_table
restore

/***
<h2>Probabilities of statements</h2>

<p>A posterior gives probabilities for statements about parameters directly:
the share of draws for which the statement holds. Some statements about the
HSLS:09 slopes:</p>
***/

webdoc stlog
use `hsls_draws', clear
tempname post
tempfile statements
postfile `post' str50 statement long holds double probability using `statements'
local labels `" "SES slope above 0" "SES slope above 1.5 points per unit" "SES slope above 2 points per unit" "Base-year math slope below 1" "Base-year math slope between 0.69 and 0.71" "'
local conditions `" "beta2 > 0" "beta2 > 1.5" "beta2 > 2" "beta1 < 1" "inrange(beta1, 0.69, 0.71)" "'
forvalues i = 1/5 {
    quietly count if `: word `i' of `conditions''
    post `post' ("`: word `i' of `labels''") (r(N)) (r(N) / _N)
}
postclose `post'
webdoc stlog close
preserve
use `statements', clear
label variable statement " "
label variable holds "Draws where it holds"
label variable probability "Posterior probability"
format holds %9.0fc
format probability %9.5f
html_table
restore

/***
<p>A probability of 1 here means all 4,000 draws satisfied the statement. The
posterior probability is then close to 1, not exactly 1, and 4,000 draws cannot
say how close. Statements near the edge of the posterior need many draws to
estimate well.</p>

<p>The base-year math slope below 1 is regression to the mean in relative
standing: a student who scored 10 points above 50 in the base year is expected
to score about 7 points above the intercept two years later, given SES. Both
scores are T-scores, so this is about standing among classmates, not about
learning. Measurement error in the base-year score contributes to a slope
below 1, as do real changes in standing; this regression cannot separate the
two.</p>

<h2>Derived quantities</h2>

<p>Any function of the parameters has a posterior too: compute it once per
draw. The cell computes the expected follow-up score for nine student
profiles: base-year scores of 40, 50, and 60 crossed with SES of −1, 0, and 1.
In the analysis sample, SES runs from about −1.9 to 2.9 with an SD of
0.79.</p>
***/

webdoc stlog
use `hsls_draws', clear
local center 50
tempfile profiles
postfile `post' int w1_math int w1_ses double(mean low high) using `profiles'
* One variable per profile, one row per draw
foreach math in 40 50 60 {
    foreach ses in -1 0 1 {
        tempvar expected
        quietly generate double `expected' = alpha + beta1 * (`math' - `center') + beta2 * `ses'
        bayes_interval `expected', level(90)
        post `post' (`math') (`ses') (r(mean)) (r(low)) (r(high))
    }
}
postclose `post'
use `profiles', clear
webdoc stlog close
preserve
label variable w1_math "w1_math"
label variable w1_ses "w1_ses"
label variable mean "Posterior mean"
label variable low "5%"
label variable high "95%"
format mean low high %9.2f
html_table
restore

webdoc stlog
generate double x = w1_math + w1_ses * 0.6
twoway (rcap low high x if w1_ses == -1, lcolor("1 115 178")) ///
    (connected mean x if w1_ses == -1, msymbol(O) mcolor("1 115 178") lcolor("1 115 178")) ///
    (rcap low high x if w1_ses == 0, lcolor("222 143 5")) ///
    (connected mean x if w1_ses == 0, msymbol(D) mcolor("222 143 5") lcolor("222 143 5")) ///
    (rcap low high x if w1_ses == 1, lcolor("2 158 115")) ///
    (connected mean x if w1_ses == 1, msymbol(T) mcolor("2 158 115") lcolor("2 158 115")), ///
    legend(order(2 "SES -1" 4 "SES +0" 6 "SES +1") rows(1)) xlabel(40 50 60) ///
    xtitle("Base-year math score") ytitle("Expected follow-up math score") ylabel(, angle(horizontal)) ///
    title("Expected follow-up score by profile, posterior mean and 90% interval", size(medium)) xsize(7) ysize(4)
webdoc stlog close
webdoc graph, alt("Expected follow-up score with 90% intervals for nine student profiles")

/***
<p>The intervals are narrow: with 18,623 students, the expected score for a
profile is known within about 0.2 points either way. That is uncertainty about
the average student with the profile, not about any one student, whose score
varies around the expectation with an SD of about 6.6 points.
<code>08-posterior-predictive</code> covers predictions for individual
students.</p>

<h2>Contrasts and standardized effects</h2>

<p>Three more derived quantities:</p>

<ul>
<li><strong>SES contrast</strong>: the expected difference between two
students with the same base-year score, one at SES +1 and one at SES −1, which
is $2\beta_2$.</li>
<li><strong>Standardized SES slope</strong>: the change in the follow-up score,
in follow-up SDs, for a one-SD change in SES, holding base-year math fixed. It
is $\beta_2$ times the SD of SES over the SD of the follow-up score, using the
sample SDs.</li>
<li><strong>Bayesian $R^2$</strong> (Gelman et al., 2019): for each draw, the
variance of the expected scores across students over that variance plus
$\sigma^2$. It gives a posterior for the share of variance the model
explains.</li>
</ul>
***/

webdoc stlog
* The variance of the expected scores across students, for each draw: b' C b,
* where C is the covariance matrix of the predictors, divided by n, and b the
* draw's slopes
use `hsls', clear
quietly correlate w1_math_c w1_ses, covariance
local scale = (r(N) - 1) / r(N)
local c11 = r(Var_1) * `scale'
local c22 = r(Var_2) * `scale'
local c12 = r(cov_12) * `scale'
quietly summarize w1_ses
local sd_ses = r(sd)
quietly summarize w2_math
local sd_y = r(sd)

use `hsls_draws', clear
generate double contrast = 2 * beta2
generate double standardized = beta2 * `sd_ses' / `sd_y'
generate double mu_variance = beta1^2 * `c11' + 2 * beta1 * beta2 * `c12' + beta2^2 * `c22'
generate double r_squared = mu_variance / (mu_variance + sigma^2)
label variable contrast "SES contrast, +1 vs -1"
label variable standardized "Standardized SES slope"
label variable r_squared "Bayesian R-squared"
tempfile derived derived_summary
quietly save `derived'
summarize_draws contrast standardized r_squared, saving(`derived_summary')
webdoc stlog close
preserve
use `derived_summary', clear
quietly replace parameter = cond(_n == 1, "SES contrast, +1 vs -1", cond(_n == 2, "Standardized SES slope", "Bayesian R-squared"))
label_summary
keep parameter mean sd p5 p95
html_table
restore

webdoc stlog
local panels
foreach name in contrast standardized r_squared {
    bayes_interval `name', level(90)
    quietly histogram `name', bin(50) density fcolor("1 115 178") lcolor(white) lwidth(vthin) ///
        xline(`r(low)' `r(high)', lcolor(black) lpattern(dash)) name(`name', replace) nodraw ///
        title("`: variable label `name''", size(medium)) xtitle("") ///
        ytitle(`=cond("`name'" == "contrast", "Density", " ")') ylabel(, angle(horizontal))
    local panels `panels' `name'
}
graph combine `panels', cols(3) xsize(13) ysize(3.5) ///
    title("Posteriors of derived quantities, with central 90% intervals (dashed)", size(medium))
webdoc stlog close
webdoc graph, alt("Histograms of the posterior draws of the SES contrast, the standardized SES slope, and the Bayesian R-squared")

/***
<h2>Reporting</h2>

<p>A report gives the estimate, its uncertainty, and the scale. The cell writes
the main result as a sentence from the draws, so the numbers in the text always
match the analysis.</p>
***/

webdoc stlog
bayes_interval beta2, level(90)
local mean2 = r(mean)
local low2 = r(low)
local high2 = r(high)
bayes_interval contrast, level(90)
display as result "Among students with the same base-year math score, each unit of SES goes with a " ///
    %4.2f `mean2' "-point higher follow-up math score (90% interval " %4.2f `low2' " to " %4.2f `high2' "). " ///
    "A student at SES +1 is expected to score " %3.1f r(mean) " points higher than a student at SES -1 " ///
    "(90% interval " %3.1f r(low) " to " %3.1f r(high) "), about " %3.1f (r(mean) / 10) " T-score SDs."
webdoc stlog close

/***
<p>These are associations in the students with complete data, unweighted. They
do not say what would happen to a student's score if their family's SES
changed, and they leave out the students missing a math score or SES, who
scored lower on average (<code>01-hsls-descriptives</code>). Later notebooks in
the series take up the missing data and the design.</p>
***/
