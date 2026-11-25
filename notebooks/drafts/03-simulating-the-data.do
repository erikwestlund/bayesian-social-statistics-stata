* 03-simulating-the-data.do: notebook that simulates the regression's data
*
* webdoc runs this do-file and writes the text, Stata output, tables, and
* graphs to outputs/notebooks/03-simulating-the-data.html. Run it
* through do/04_bayes_notebooks.do. The R and Python projects render the same
* notebook. It compares fake students with HSLS:09 students, checks that
* bayesmh recovers known parameters, and runs simulation-based calibration.

webdoc init `"$outputs_notebooks/03-simulating-the-data.html"', replace ///
    header(title("Simulating the data-generating process") author("Erik") date("2026-11-18") width(60em)) ///
    logdir(03-simulating-the-data_files) ///
    grdir(03-simulating-the-data_files) ///
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

<h1>Simulating the data-generating process</h1>

<p>Erik, 2026-11-18</p>

<p>A statistical model is a story about how the data came to be. Writing that
story as code that generates fake data does three things before any real data
are fit:</p>

<ol>
<li>It makes the assumptions concrete. Fake data that look nothing like real
data point to an assumption worth questioning.</li>
<li>It gives data with known parameters, so a fitting procedure can be checked
for whether it recovers them.</li>
<li>It shows how precisely the parameters can be learned from a sample of a
given size.</li>
</ol>

<p>This notebook writes the story for the regression in
<code>02-ols-vs-bayes</code>, compares fake students with HSLS:09 students,
checks that <code>bayesmh</code> recovers known parameters, and then runs
simulation-based calibration: a check that the posterior intervals have the
coverage they claim.</p>
***/

webdoc stlog
bayes_analysis_sample, clear
tempfile hsls
quietly save `hsls'
local n_hsls = _N

* One seed for every simulation, so reruns give the same fake data
set seed 1009
webdoc stlog close

/***
<h2>The story as code</h2>

<p>The regression describes the follow-up score given the predictors:</p>

$$
\text{w2_math}_i \sim \text{Normal}(\alpha + \beta_1\, \text{w1_math_c}_i + \beta_2\, \text{w1_ses}_i,\ \sigma).
$$

<p>It says nothing about where the predictors come from. To generate complete
fake students, the simulation adds a model for them: base-year math and SES
drawn from a bivariate normal distribution with the HSLS:09 means, SDs, and
correlation. The program below is the whole story, step by step. It is the
same as <code>bayes_simulate</code> in <code>functions/</code>.</p>
***/

webdoc stlog
capture program drop simulate_students
program define simulate_students
    syntax, n(integer) alpha(real) beta1(real) beta2(real) sigma(real)
    clear
    * Step 1: predictors. Base-year math has mean 51.7 (1.7 after centering at
    * 50) and SD 10, SES has mean 0.08 and SD 0.8, and the two correlate 0.43.
    matrix mean = (1.7, 0.08)
    matrix sd = (10, 0.8)
    matrix correlation = (1, 0.43 \ 0.43, 1)
    quietly drawnorm w1_math_c w1_ses, n(`n') means(mean) sds(sd) corr(correlation) double
    generate double w1_math = w1_math_c + 50

    * Step 2: each student's expected follow-up score
    generate double mu = `alpha' + `beta1' * w1_math_c + `beta2' * w1_ses

    * Step 3: the follow-up score, with normal noise around the expectation
    generate double w2_math = rnormal(mu, `sigma')
    drop mu
end

* The HSLS:09 values behind the simulation's settings
quietly correlate w1_math w1_ses
local r = r(rho)
foreach name in w1_math w1_ses {
    quietly summarize `name'
    local `name'_mean = r(mean)
    local `name'_sd = r(sd)
}
webdoc stlog close
preserve
clear
quietly input str20 statistic double value
"Mean of w1_math" .
"SD of w1_math" .
"Mean of w1_ses" .
"SD of w1_ses" .
"Correlation" .
end
quietly replace value = cond(_n == 1, `w1_math_mean', cond(_n == 2, `w1_math_sd', ///
    cond(_n == 3, `w1_ses_mean', cond(_n == 4, `w1_ses_sd', `r'))))
label variable statistic " "
label variable value "HSLS:09"
format value %9.2f
html_table
restore

/***
<p>The simulation's settings round these values. Base-year math in this sample
has a mean above 50, the T-score mean, because the sample is students with both
scores, who scored higher than students missing one.</p>

<h2>Fake students next to real ones</h2>

<p>The cell simulates as many fake students as the HSLS:09 sample holds, with
parameters close to the HSLS:09 estimates, and plots each variable for
both.</p>
***/

webdoc stlog
simulate_students, n(`n_hsls') alpha(50.4) beta1(0.7) beta2(1.8) sigma(6.6)
generate str9 source = "Simulated"
tempfile both
quietly save `both'
use `hsls', clear
keep w1_math w1_ses w2_math
generate str9 source = "HSLS:09"
quietly append using `both'

* Gaussian kernels with Scott's bandwidth, SD times n^(-1/5), as seaborn uses
local panels
foreach name in w1_math w1_ses w2_math {
    local plots
    foreach source in "HSLS:09" "Simulated" {
        quietly summarize `name' if source == "`source'"
        local bandwidth = r(sd) * r(N)^(-1/5)
        local color = cond("`source'" == "HSLS:09", "1 115 178", "222 143 5")
        local pattern = cond("`source'" == "HSLS:09", "solid", "dash")
        local plots `plots' (kdensity `name' if source == "`source'", kernel(gaussian) bwidth(`bandwidth') ///
            n(200) lcolor("`color'") lpattern(`pattern') lwidth(medthick))
    }
    twoway `plots', name(`name', replace) nodraw xtitle("`name'") ytitle("Density") ///
        ylabel(, angle(horizontal) format(%4.2f) labsize(small)) legend(order(1 "HSLS:09" 2 "Simulated") rows(1))
}
graph combine w1_math w1_ses w2_math, cols(3) xsize(12) ysize(3.8) ///
    title("Simulated and HSLS:09 students (n = `=strtrim(string(`n_hsls', "%9.0fc"))' each)", size(medium))
webdoc stlog close
webdoc graph, alt("Density curves of base-year math, SES, and follow-up math for simulated and HSLS:09 students")

webdoc stlog
preserve
collapse (mean) w1_math_mean = w1_math w1_ses_mean = w1_ses w2_math_mean = w2_math ///
    (sd) w1_math_sd = w1_math w1_ses_sd = w1_ses w2_math_sd = w2_math ///
    (min) w1_math_min = w1_math w1_ses_min = w1_ses w2_math_min = w2_math ///
    (max) w1_math_max = w1_math w1_ses_max = w1_ses w2_math_max = w2_math, by(source)
webdoc stlog close
* One row per variable and statistic, one column per source (row 1 is HSLS:09)
local k 0
foreach name in w1_math w1_ses w2_math {
    foreach stat in mean sd min max {
        local ++k
        local label`k' = "`name' " + cond("`stat'" == "sd", "SD", "`stat'")
        local h`k' = `name'_`stat'[1]
        local s`k' = `name'_`stat'[2]
    }
}
clear
quietly set obs `k'
generate str20 statistic = ""
generate double hsls = .
generate double simulated = .
forvalues i = 1/`k' {
    quietly replace statistic = "`label`i''" in `i'
    quietly replace hsls = `h`i'' in `i'
    quietly replace simulated = `s`i'' in `i'
}
label variable statistic " "
label variable hsls "HSLS:09"
label variable simulated "Simulated"
format hsls simulated %9.2f
html_table
restore

/***
<p>The simulated predictors match the HSLS:09 means and SDs, because the
settings came from them, and so does the simulated outcome, because the
parameters came from the HSLS:09 fit. The shapes differ in ways that matter
later:</p>

<ul>
<li><strong>SES.</strong> The HSLS:09 composite is bounded and lumpy, because it
is built from categorical parent education and occupation and bracketed income.
The normal distribution in the simulation is smooth and unbounded.</li>
<li><strong>Math scores.</strong> The real T-scores have a lower and upper limit
set by the test. Normal noise produces scores past those limits.</li>
</ul>

<p>The regression conditions on the predictors, so the SES shape does not bias
its estimates. The bounded outcome is part of the model, though: the posterior
predictive checks in <code>08-posterior-predictive</code> look for it.</p>

<h2>Recovering known parameters</h2>

<p>A fitting procedure that cannot recover the parameters of data generated by
its own model will not recover anything from real data. The cell fits the
model with <code>bayesmh</code>, with the weak priors (the default of
<code>bayes_sample</code>), to 1,000 fake students, and compares the posterior
with the truth.</p>
***/

webdoc stlog
simulate_students, n(1000) alpha(50.4) beta1(0.7) beta2(1.8) sigma(6.6)
tempfile draws
bayes_sample w2_math w1_math_c w1_ses, saving(`draws')
use `draws', clear
tempname post
tempfile recovery
postfile `post' str8 parameter double(truth mean low high) using `recovery'
foreach name in alpha beta1 beta2 sigma {
    local truth = cond("`name'" == "alpha", 50.4, cond("`name'" == "beta1", 0.7, cond("`name'" == "beta2", 1.8, 6.6)))
    bayes_interval `name', level(90)
    post `post' ("`name'") (`truth') (r(mean)) (r(low)) (r(high))
}
postclose `post'
webdoc stlog close
preserve
use `recovery', clear
generate str5 inside = cond(low <= truth & truth <= high, "True", "False")
label variable parameter " "
label variable truth "Truth"
label variable mean "Posterior mean"
label variable low "90% low"
label variable high "90% high"
label variable inside "Truth inside"
format truth mean low high %9.3f
html_table
restore

/***
<p>The last column says whether each 90% interval contains the true value. A
miss here would not be evidence of a problem. Bayesian intervals are calibrated
on average over parameter values drawn from the prior; at one fixed truth, the
miss rate across repeated data sets can differ from 10%. The calibration
section below checks that average over 200 fits.</p>

<h2>Precision and sample size</h2>

<p>The simulation also shows how the posterior narrows as the sample grows. The
cell fits fake samples of 50 to 20,000 students and plots the posterior SD of
the SES slope. For a regression, it falls with the square root of the sample
size, so on log scales the points lie close to a line with slope −1/2.</p>
***/

webdoc stlog
tempfile precision
postfile `post' long n double sd using `precision'
foreach n in 50 200 800 3200 12800 20000 {
    simulate_students, n(`n') alpha(50.4) beta1(0.7) beta2(1.8) sigma(6.6)
    quietly bayes_sample w2_math w1_math_c w1_ses, saving(`draws') replace
    use `draws', clear
    quietly summarize beta2
    post `post' (`n') (r(sd))
}
postclose `post'
use `precision', clear
generate double log_n = ln(n)
generate double log_sd = ln(sd)
quietly regress log_sd log_n
local slope = _b[log_n]
twoway connected sd n, msymbol(O) mcolor("1 115 178") lcolor("1 115 178") ///
    xscale(log) yscale(log) xlabel(50 200 800 3200 12800 20000, format(%9.0fc)) ylabel(0.1 0.2 0.5 1, angle(horizontal)) ///
    xtitle("Simulated students (log scale)") ytitle("Posterior SD of the SES slope (log scale)") ///
    title("Posterior SD by sample size (fitted log-log slope `: display %4.2f `slope'')", size(medium)) xsize(6) ysize(4)
webdoc stlog close
webdoc graph, alt("Posterior SD of the SES slope against the number of simulated students, on log scales")
preserve
keep n sd
label variable n "n"
label variable sd "Posterior SD of the SES slope"
format n %9.0fc
format sd %9.3f
html_table
restore

/***
<h2>Simulation-based calibration</h2>

<p>One recovery check can pass by luck. Simulation-based calibration (Talts et
al., 2018) repeats it many times, and draws the true parameters from the prior
each time:</p>

<ol>
<li>Draw parameters from the prior.</li>
<li>Simulate a data set from the model with those parameters.</li>
<li>Fit the model to the simulated data.</li>
<li>Record the rank of the true value among the posterior draws: how many draws
fall below it.</li>
</ol>

<p>If the model and the sampler are correct, each true value is a draw from its
own posterior, so its rank is equally likely to take any value. A histogram of
ranks over many simulations should then be flat. A U shape means the
posteriors are too narrow, a hump means they are too wide, and a slope means
they are shifted.</p>

<p>The cell runs 200 simulations with 100 students each, using the predictors
of 100 HSLS:09 students drawn at random each time, so the predictors are
realistic. The draws must be close to independent, or the ranks bunch up, and
Metropolis-Hastings draws are strongly autocorrelated. So each fit runs one
chain, started at the OLS estimates of its data set, with 2,500 burn-in
iterations, and then keeps 99 draws, one every 40 iterations. Ranks run from 0
to 99, 100 possible values. The rank argument assumes the kept draws are close
to independent, so the thinning is needed here, not only a precaution. The R
and Python notebooks keep every 40th of Stan's 4,000 draws, which
gives the same 99. The cell takes about two minutes.</p>
***/

webdoc stlog
tempfile ranks
postfile `post' double(alpha beta1 beta2 sigma) using `ranks'
forvalues sim = 1/200 {
    * 1. Parameters from the prior: bayes_sample's default weak priors
    local alpha = rnormal(50, 10)
    local beta1 = rnormal(0, 2.5)
    local beta2 = rnormal(0, 2.5)
    local sigma = rexponential(10)

    * 2. Data from the model, with real predictors
    use w1_math_c w1_ses using `hsls', clear
    quietly sample 100, count
    generate double w2_math = rnormal(`alpha' + `beta1' * w1_math_c + `beta2' * w1_ses, `sigma')

    * 3. Fit
    quietly bayes_sample w2_math w1_math_c w1_ses, saving(`draws') replace ///
        chains(1) burnin(2500) draws(99) thinning(40) init(ols)

    * 4. Rank of each true value among the kept draws: 0 to 99
    use `draws', clear
    assert _N == 99
    foreach name in alpha beta1 beta2 sigma {
        quietly count if `name' < ``name''
        local rank_`name' = r(N)
    }
    post `post' (`rank_alpha') (`rank_beta1') (`rank_beta2') (`rank_sigma')
}
postclose `post'
use `ranks', clear
webdoc stlog close

webdoc stlog
* Ranks 0 to 99 in 10 bins of 10 ranks each (0-9, ..., 90-99). With 200
* simulations, a flat histogram has 20 per bin. The band is the central 99% range for one bin's count under a flat
* histogram, from the binomial distribution.
local low .
local high .
forvalues k = 0/200 {
    if `low' == . & binomial(200, `k', 0.1) >= 0.005 local low `k'
    if `high' == . & binomial(200, `k', 0.1) >= 0.995 local high `k'
}
preserve
local panels
local outside
foreach name in alpha beta1 beta2 sigma {
    restore, preserve
    forvalues b = 0/9 {
        quietly count if floor(`name' / 10) == `b'
        local count`b' = r(N)
    }
    clear
    quietly set obs 10
    generate byte bin = _n - 1
    quietly generate int count = .
    forvalues b = 0/9 {
        quietly replace count = `count`b'' if bin == `b'
    }
    quietly count if count < `low' | count > `high'
    local outside `outside' `name': `r(N)'
    generate double x = 10 * bin + 5
    generate double band_low = `low'
    generate double band_high = `high'
    twoway (rarea band_low band_high x, fcolor(gs13) lcolor(gs13)) ///
        (bar count x, barwidth(9.5) fcolor("1 115 178") lcolor(white)), ///
        name(`name', replace) nodraw legend(off) title(`name', size(medium)) ///
        xtitle("Rank of the true value (of 99 draws)", size(small)) ytitle("Simulations") ///
        xlabel(0(20)100) yscale(range(0 45)) ylabel(0(10)40, angle(horizontal))
    local panels `panels' `name'
}
restore
graph combine `panels', cols(4) ycommon xsize(13) ysize(3.4) ///
    title("Simulation-based calibration: 200 simulations, 100 students each", size(medium))
display as result "Band for one bin's count: `low' to `high' simulations"
display as result "Bins outside the band, by parameter: `outside'"
webdoc stlog close
webdoc graph, alt("Histograms of the ranks of the true values for the four parameters, with the band a flat histogram stays in")

webdoc stlog
* Coverage: the share of simulations whose central 50% and 90% intervals hold
* the true value. Ranks give it directly: a central 90% interval of 99 draws
* runs from rank 5 to rank 94.
preserve
tempfile coverage
postfile `post' str8 parameter double(c50 c90) using `coverage'
foreach name in alpha beta1 beta2 sigma {
    quietly count if inrange(`name', 25, 74)
    local c50 = r(N) / _N
    quietly count if inrange(`name', 5, 94)
    post `post' ("`name'") (`c50') (r(N) / _N)
}
postclose `post'
use `coverage', clear
webdoc stlog close
label variable parameter " "
label variable c50 "50% interval"
label variable c90 "90% interval"
format c50 c90 %9.2f
html_table
restore

/***
<p>With ten bins per parameter, a bin or two outside a 99% band can happen by
chance across the four histograms. Here no bin falls outside. The coverage
farthest from its target is the 50% coverage of $\beta_1$, 0.42. With 200
simulations a coverage share has a standard error of about 0.035, so that is a
little over 2 standard errors low. With eight shares to look at, one that far
off happens about one time in six by chance. More simulations would settle
it.</p>

<p>Flat histograms and coverage near 50% and 90% mean this check found no
calibration failure at its resolution: 200 simulations and four one-parameter
summaries can catch a posterior that is clearly too narrow, too wide, or
shifted, not a subtle error. The check does not say the model is right for
HSLS:09. It says the model as <code>bayes_sample</code> writes it for
<code>bayesmh</code>, and the sampler, pass a test that a coding or sampling
error would likely fail.</p>
***/
