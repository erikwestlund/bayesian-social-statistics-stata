* 06-diagnostics.do: notebook of MCMC diagnostics for bayesmh fits
*
* webdoc runs this do-file and writes the text, Stata output, tables, and
* graphs to outputs/notebooks/06-diagnostics.html. Run it through
* do/04_bayes_notebooks.do. The R and Python projects render the same
* notebook with Stan. It checks a fit that passes, two fits built to fail,
* and a model with one intercept per school context.

webdoc init `"$outputs_notebooks/06-diagnostics.html"', replace ///
    header(title("Sampler diagnostics") author("Erik") date("2026-11-18") width(60em)) ///
    logdir(06-diagnostics_files) ///
    grdir(06-diagnostics_files) ///
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

<h1>Sampler diagnostics</h1>

<p>Erik, 2026-11-18</p>

<p>MCMC draws are only a sample from the posterior if the chains have converged
and mixed. Nothing in the draws themselves announces a failure: a broken fit
returns numbers just like a good one. This notebook goes through the checks
that catch failures, first on a fit that passes them, then on two fits built
to fail, and then on a model with one intercept per school context, whose group
estimates are shown in caterpillar plots.</p>

<p>The checks fall into two groups:</p>

<ul>
<li><strong>Convergence and precision</strong>, computed from the draws of each
parameter: R-hat, effective sample size (ESS), and Monte Carlo standard error
(MCSE).</li>
<li><strong>Sampler behavior</strong>, reported by <code>bayesmh</code> for
each chain: the acceptance rate and the efficiency. The Stan versions of this
notebook check divergent transitions, the tree depth, and the energy
diagnostic E-BFMI instead. Those belong to Hamiltonian Monte Carlo and have no
counterpart in <code>bayesmh</code>'s Metropolis-Hastings sampler.</li>
</ul>
***/

webdoc stlog
bayes_analysis_sample, clear
tempfile hsls
quietly save `hsls'

* One seed for the subsamples and the chains
set seed 606
webdoc stlog close

/***
<h2>Convergence and precision</h2>

<p><code>bayes_summary</code> in <code>functions/</code> reports, for each
parameter, what Stan's summary reports:</p>

<ul>
<li><strong>R-hat</strong> compares the spread within each chain with the
spread across chains, after splitting each chain in half and rank-normalizing
the draws (Vehtari et al., 2021). <code>bayes_summary</code>, like Stan,
reports the larger of that value and the same statistic computed on folded
draws, the distances from the median, which catches chains that agree on
location but not on spread. Chains that sampled the same distribution give
R-hat near 1. A value above 1.01 means the chains disagree, and the draws
should not be used.</li>
<li><strong>ESS</strong> is the number of independent draws that would give
the same precision as the autocorrelated draws in hand. Bulk ESS measures
precision for the center of the distribution, such as the mean or median. Tail
ESS measures it for the 5th and 95th percentiles. Both should be at least 100
per chain, 400 for four chains.</li>
<li><strong>MCSE</strong> is the standard error of the posterior mean due to
having a finite number of draws: roughly the posterior SD over the square root
of the ESS. <code>bayes_summary</code>, like Stan, computes the ESS for this
from the draws as they are, not after the rank normalization used for bulk
ESS, so the two can differ when a fit fails. The MCSE should be small next to
the posterior SD.</li>
</ul>

<p><code>bayesmh</code> itself runs one chain, so it has no R-hat, and its ESS
uses one chain's autocorrelations. <code>bayes_summary</code> pools the chains
and follows Vehtari et al. (2021), as Stan and ArviZ do; its bulk ESS, tail
ESS, and R-hat match ArviZ's on the same draws. The cell fits the regression
to HSLS:09 with four chains and shows the summary.</p>
***/

webdoc stlog
tempfile fit raw
bayes_sample w2_math w1_math_c w1_ses, saving(`fit') rawsaving(`raw')
matrix chain_stats = r(chain_stats)
use `fit', clear
bayes_summary alpha beta1 beta2 sigma, chain(chain) clear
webdoc stlog close
html_table

/***
<h2>Sampler behavior</h2>

<p>A random-walk Metropolis-Hastings sampler has two numbers of its own per
chain:</p>

<ul>
<li><strong>Acceptance rate</strong>: the share of proposals accepted. Too
high, and the proposals are too small to move far; too low, and the chain
stands still. <code>bayesmh</code> tunes the proposals during burn-in toward
0.234 for a block of several parameters and 0.44 for a block of one, the rates
that are most efficient for a random walk.</li>
<li><strong>Efficiency</strong>: the chain's ESS over the number of draws, for
each parameter. The table shows the lowest and the average across the four
parameters. Values near 0.01 mean about one effective draw in a hundred.</li>
</ul>

<p>Divergent transitions, the maximum tree depth, and E-BFMI do not exist here.
A random-walk sampler cannot diverge: a bad proposal is simply rejected. Its
failure mode is quieter: it moves slowly and leaves regions of the posterior
unexplored, which the diagnostics above catch.</p>
***/

webdoc stlog
preserve
clear
quietly svmat chain_stats, names(col)
generate str8 chain = "Chain " + string(_n)
order chain
label variable chain " "
label variable arate "Acceptance rate"
label variable eff_min "Lowest efficiency"
label variable eff_avg "Average efficiency"
label variable seconds "Seconds"
format arate eff_min eff_avg %9.2f
format seconds %9.1f
webdoc stlog close
html_table
restore

/***
<p><code>bayesmh</code>'s own check is <code>bayesstats ess</code>, which
reports the ESS, the correlation time (draws per effective draw), and the
efficiency of one chain. After <code>bayes_sample</code> it describes the last
chain. <code>bayesmh</code> also prints notes when something is off, such as
"There is a high autocorrelation after 500 lags" or "Adaptation tolerance is
not met". None appeared for this fit.</p>
***/

webdoc stlog
bayesstats ess
webdoc stlog close

/***
<h2>Trace and rank plots</h2>

<p>A trace plot shows each chain's draws in order. Chains that mix well overlap
and look like noise around a stable level. A rank plot pools the draws of all
chains, ranks them, and shows a histogram of ranks for each chain. When the
chains sample the same distribution, each chain's ranks are spread evenly, so
every histogram is flat. Rank plots show problems that trace plots hide when
many draws overlap (Vehtari et al., 2021).</p>
***/

webdoc stlog
capture program drop trace_and_rank
program define trace_and_rank
    * Trace plots (top row) and rank plots (bottom row) of the draws in memory
    syntax varlist, title(string)
    local colors `" "1 115 178" "222 143 5" "2 158 115" "213 94 0" "'
    quietly levelsof chain, local(chains)
    local draws_per_bin = _N / 20
    local top
    local bottom
    local first : word 1 of `varlist'
    local last : word `: word count `varlist'' of `varlist'
    foreach name of local varlist {
        local ytrace = cond("`name'" == "`first'", "Draw", " ")
        local yrank = cond("`name'" == "`first'", "Draws per bin", " ")
        if "`name'" == "`last'" local legend order(1 "Chain 1" 2 "Chain 2" 3 "Chain 3" 4 "Chain 4") rows(2) size(vsmall) ring(0) pos(6)
        else local legend off
        local traces
        local steps
        foreach c of local chains {
            local color : word `c' of `colors'
            local traces `traces' (line `name' draw if chain == `c', lcolor("`color'") lwidth(vthin))
            local steps `steps' (line count bin if chain == `c', connect(stairstep) lcolor("`color'") lwidth(medthick))
        }
        twoway `traces', name(t_`name', replace) nodraw legend(off) title(`name', size(medium)) ///
            xtitle("Iteration", size(small)) ytitle("`ytrace'") ///
            ylabel(, angle(horizontal) labsize(small))
        preserve
        tempvar rank
        egen double `rank' = rank(`name')
        * One set of bin edges for every chain: 20 equal bins of the pooled ranks
        generate int bin = min(ceil(`rank' / `draws_per_bin'), 20)
        contract chain bin, freq(count) zero
        twoway `steps', name(r_`name', replace) nodraw legend(`legend') ///
            xtitle("Rank of draw, all chains pooled (20 bins)", size(small)) ytitle("`yrank'") ///
            xlabel(none) yscale(range(0)) ylabel(#3, angle(horizontal) labsize(small))
        restore
        local top `top' t_`name'
        local bottom `bottom' r_`name'
    }
    graph combine `top' `bottom', cols(`: word count `varlist'') xsize(13.6) ysize(5.5) ///
        title("`title'", size(medium))
end

use `fit', clear
trace_and_rank alpha beta1 beta2 sigma, title("Trace plots (top) and rank plots (bottom), HSLS:09 regression")
webdoc stlog close
webdoc graph, alt("Trace plots and rank plots of the four parameters, four chains")

/***
<p>All four parameters pass: R-hat is 1.00, bulk and tail ESS are in the
thousands, MCSE is a small fraction of the posterior SD, the acceptance rates
lie between the targets of the coefficient block and the $\sigma$ block, and
the trace and rank plots look as they should. The
next two fits are built to fail.</p>

<h2>Failure 1: chains too short for an awkward posterior</h2>

<p>This fit makes two changes. It uses base-year math without centering, so the
intercept is the expected score at a base-year score of 0, far outside the
data, and the intercept and slope become almost perfectly correlated in the
posterior. And it runs only 50 burn-in iterations and 50 kept draws per chain,
with no thinning. That is too few to reach the posterior from a random start,
and too few to adapt the proposals: <code>bayesmh</code> adapts every 100
iterations, so here it never adapts at all. It uses flat priors, since the weak
prior on the intercept assumes centering.</p>
***/

webdoc stlog
use `hsls', clear
tempfile short
bayes_sample w2_math w1_math w1_ses, flat saving(`short') burnin(50) draws(50) thinning(1)
matrix short_stats = r(chain_stats)
matrix list short_stats, format(%9.3f)
use `short', clear
bayes_summary alpha beta1 beta2 sigma, chain(chain) clear
webdoc stlog close
html_table

webdoc stlog
use `short', clear
trace_and_rank alpha beta1 beta2 sigma, title("Too few iterations and an uncentered predictor")
webdoc stlog close
webdoc graph, alt("Trace plots and rank plots of the short, uncentered fit")

webdoc stlog
* The posterior correlation between the intercept and the base-year math slope,
* with and without centering, from the converged fit. Without centering, the
* intercept is the expected score at a base-year score of 0, alpha - 50 * beta1.
use `fit', clear
generate double alpha_at_0 = alpha - 50 * beta1
quietly correlate alpha beta1
display as result "Centered: alpha and beta1                 " %7.3f r(rho)
quietly correlate alpha_at_0 beta1
display as result "Uncentered: alpha - 50 beta1 and beta1    " %7.3f r(rho)
webdoc stlog close

/***
<p>The summary flags the failure: R-hat far above 1.01 and bulk ESS far below
400 for every parameter. The acceptance rates of 0.02 to 0.06 show proposals
that were never tuned. The trace plots show chains that have not settled on
a common level, and the rank plots are uneven.</p>

<p>The correlations show why the uncentered version is hard, using the
converged fit from above so the comparison is like for like. Without
centering, the intercept is the expected score at a base-year score of 0, and
it is almost perfectly correlated with the slope: a steeper line must start
lower. A random-walk sampler has to move along that narrow ridge, which takes
long chains and well-adapted proposals. The remedy here is both changes
reversed: centering the predictor removes most of the correlation, and a
longer burn-in lets the chains reach the posterior and the sampler adapt. More
iterations alone would also work, slowly.</p>

<h2>Failure 2: a funnel in a hierarchical model</h2>

<p>The model in <code>bayes_sample_groups</code> adds an intercept for each
school context: the 31 combinations of census region, locale, and public or
private control that occur in the sample. The group intercepts $a_j$ come from
a common Normal(0, $\tau$) distribution, so groups with little data are pulled
toward 0, and $\tau$ is estimated. The priors match the Stan program
<code>regression_groups.stan</code> of the R and Python projects, with
Exponential(0.5) on $\tau$.</p>

<p>With few students per group, the posterior of this model has a funnel: when
$\tau$ is small, the $a_j$ must all be near 0, and when $\tau$ is large, they
can spread out. A proposal size that suits the mouth of the funnel is too
large for its neck, so a sampler either avoids the neck or sticks in it for
long stretches. In <code>bayesmh</code> the group intercepts are coefficients
on group indicators, and how they are updated matters:</p>

<ul>
<li><strong>One block</strong>: all 34 coefficients, the intercept, the two
slopes, and the 31 group intercepts, in one random-walk block.
<code>bayesmh</code> does this by default for the coefficients of one
regression.</li>
<li><strong>A block per group</strong>: the <code>reffects</code> suboption of
<code>block()</code> updates each group intercept in a block of its own.</li>
<li><strong>Gibbs</strong>: the 31 group intercepts drawn together from their
exact conditional distribution, which is normal. <code>bayesmh</code> allows
this when the likelihood and the group prior take variances as parameters, so
this version samples $\sigma^2$ and $\tau^2$, with the exponential priors on
$\sigma$ and $\tau$ rewritten as densities of the variances.</li>
</ul>

<p>The Stan notebooks fix the funnel with a non-centered form, which samples
standardized offsets $z_j$ and sets $a_j = \tau z_j$. That helps Hamiltonian
Monte Carlo, whose step size must suit the whole posterior. In
<code>bayesmh</code> the form would need 31 explicit parameters in a nonlinear
expression, updated by the same random walk, so the notebook compares the
updates <code>bayesmh</code> offers instead. The cell fits each version to 3
students per group, drawn at random.</p>
***/

webdoc stlog
use `hsls', clear
local region1 Northeast
local region2 Midwest
local region3 South
local region4 West
local locale1 City
local locale2 Suburb
local locale3 Town
local locale4 Rural
quietly generate str40 context = ""
forvalues r = 1/4 {
    forvalues l = 1/4 {
        quietly replace context = "`region`r'', `locale`l'', " + cond(school_w1_public == 1, "Public", "Private") ///
            if school_w1_region == `r' & school_w1_locale == `l'
    }
}
* Groups numbered in alphabetical order of their names
egen int group = group(context)
quietly save `hsls', replace
quietly tabulate group
display as result r(r) " school contexts"

generate double shuffle = runiform()
quietly bysort group (shuffle): keep if _n <= 3
drop shuffle
tempfile few few_block few_reffects few_gibbs
quietly save `few'
local labels `" "One block" "A block per group" "Gibbs" "'
foreach update in block reffects gibbs {
    bayes_sample_groups w2_math w1_math_c w1_ses, group(group) update(`update') saving(`few_`update'')
    matrix few_`update' = r(chain_stats)
}
webdoc stlog close

webdoc stlog
* Sampler behavior of each version. The chains are equally long, so the mean
* of the chains' acceptance rates is the rate over all iterations.
preserve
clear
tempname post
tempfile behavior
postfile `post' str20 version double(arate eff_min seconds) using `behavior'
local i 0
foreach update in block reffects gibbs {
    local label : word `++i' of `labels'
    mata: S = st_matrix("few_`update'")
    mata: st_local("arate", strofreal(mean(S[., 1])))
    mata: st_local("eff_min", strofreal(min(S[., 2])))
    mata: st_local("seconds", strofreal(sum(S[., 4])))
    post `post' ("`label'") (`arate') (`eff_min') (`seconds')
}
postclose `post'
use `behavior', clear
label variable version " "
label variable arate "Acceptance rate, all chains"
label variable eff_min "Lowest efficiency, any chain"
label variable seconds "Seconds, four chains"
format arate eff_min %9.3f
format seconds %9.1f
webdoc stlog close
html_table
restore

webdoc stlog
* Diagnostics of tau, of all 31 group intercepts, and of the two slopes
preserve
tempfile few_summary
local i 0
foreach update in block reffects gibbs {
    local label : word `++i' of `labels'
    use `few_`update'', clear
    bayes_summary tau beta1 beta2 a1-a31, chain(chain) clear
    quietly generate byte kind = cond(parameter == "tau", 1, cond(inlist(parameter, "beta1", "beta2"), 3, 2))
    quietly generate byte high = rhat > 1.01
    collapse (max) rhat_max = rhat (min) ess_min = ess_bulk (sum) high, by(kind)
    quietly generate str20 version = "`label'"
    if `i' > 1 append using `few_summary'
    quietly save `few_summary', replace
}
* One row per version
quietly reshape wide rhat_max ess_min high, i(version) j(kind)
generate byte order = cond(version == "One block", 1, cond(version == "A block per group", 2, 3))
sort order
keep version rhat_max1 ess_min1 rhat_max2 high2 ess_min2 rhat_max3 ess_min3
order version rhat_max1 ess_min1 rhat_max2 high2 ess_min2 rhat_max3 ess_min3
label variable version " "
label variable rhat_max1 "tau: R-hat"
label variable ess_min1 "tau: bulk ESS"
label variable rhat_max2 "Group intercepts: largest R-hat"
label variable high2 "Group intercepts: R-hat above 1.01"
label variable ess_min2 "Group intercepts: smallest bulk ESS"
label variable rhat_max3 "Slopes: largest R-hat"
label variable ess_min3 "Slopes: smallest bulk ESS"
format rhat_max* %9.3f
format ess_min* high2 %9.0fc
webdoc stlog close
html_table
restore

webdoc stlog
local panels
foreach update in block reffects {
    use `few_`update'', clear
    generate double log_tau = ln(tau)
    local title = cond("`update'" == "block", "One block", "A block per group")
    twoway scatter log_tau a1, msymbol(o) msize(vtiny) mcolor("1 115 178") name(`update', replace) nodraw ///
        title("`title'", size(medium)) xtitle("Intercept of group 1, a1") ytitle("log(tau)") ///
        ylabel(, angle(horizontal))
    local panels `panels' `update'
}
graph combine `panels', cols(2) ycommon xcommon xsize(11) ysize(4) ///
    title("The funnel: group intercept against the log of its SD, 3 students per group", size(medium))
webdoc stlog close
webdoc graph, alt("Scatter plots of the draws of the first group intercept against log tau, for two samplers")

/***
<p>The single block fails on every parameter: R-hat is far above 1.01 and the
bulk ESS is in single digits. A random-walk proposal in 34 dimensions must be
tiny to be accepted, so the chains barely move from where they start, and they
disagree. The scatter plot shows the chains in separate clusters, none of them
reaching small values of $\tau$. Updating each group intercept in its own
block, or all of them together by Gibbs, fixes the slopes, which now have
over 2,000 effective draws each. It does not fix $\tau$: its R-hat is 1.30 with
a block per group and 1.68 with Gibbs, and its bulk ESS is 12 and 7. The group
intercepts depend on $\tau$, so they fail too: all 31 have R-hat above 1.01,
up to 1.23 and 1.29, and the smallest bulk ESS is 64 and 10. Given the group
intercepts, $\tau$ can move only a little, and given $\tau$, the intercepts
can move only a little, so the chains travel up and down the funnel slowly.
The Gibbs update draws the intercepts exactly, but $\tau$ still moves by a
random walk, so it does no better here. Diagnostics computed for every
parameter catch this kind of failure, which a look at the coefficients of
interest would miss.</p>

<p>The plain remedy for a slowly mixing chain is a longer one. The next cell
reruns the version with a block per group with five times the thinning: 2,500
burn-in iterations and then 50,000, of which every 50th is kept.</p>
***/

webdoc stlog
use `few', clear
tempfile few_long
bayes_sample_groups w2_math w1_math_c w1_ses, group(group) update(reffects) thinning(50) saving(`few_long')
matrix few_long = r(chain_stats)
preserve
tempfile longer
foreach version in reffects long {
    use `few_`version'', clear
    bayes_summary tau a1 beta2, chain(chain) clear
    quietly keep if parameter == "tau"
    quietly generate str40 version = cond("`version'" == "long", "Every 50th of 50,000 iterations", "Every 10th of 10,000 iterations")
    mata: S = st_matrix("few_`version'")
    mata: st_local("seconds", strofreal(sum(S[., 4])))
    generate double seconds = `seconds'
    if "`version'" == "long" append using `longer'
    quietly save `longer', replace
}
gsort -version
keep version mean sd ess_bulk ess_tail rhat seconds
order version
label variable version "A block per group, tau"
label variable seconds "Seconds, four chains"
format seconds %9.1f
webdoc stlog close
html_table
restore

/***
<p>Five times the iterations raise the bulk ESS of $\tau$ from 12 to about 250,
at four times the run time, but R-hat is still 1.016, just above 1.01. A longer
chain does not make the sampler better at the funnel; it gives it more time to
cross it. Here 50,000 iterations per chain are not quite enough.</p>

<h2>The hierarchical model on all students</h2>

<p>With all 18,623 students, each school context has between 39 and 2,356
students, and the data pin down each group's mean score. That creates a
different problem. The data fix the sum $\alpha + a_j$ for each group, but not
how it splits between $\alpha$ and $a_j$, so the posterior has a long, narrow
ridge along which $\alpha$ rises and every $a_j$ falls. Updating $\alpha$ and
the $a_j$ in separate blocks moves along that ridge in tiny steps.</p>

<p>Writing the same model in terms of the group means
$m_j = \alpha + a_j \sim \text{Normal}(\alpha, \tau)$, with $\alpha$ as their
hyperparameter, removes the ridge: the data fix each $m_j$, and $\alpha$ is
their average. The Stan notebooks find the same thing in their own terms: with
plenty of data in every group, the centered form is the efficient one.
<code>bayes_sample_groups</code> fits both forms, here each with a block per
group, and saves $a_j = m_j - \alpha$ for the means form. The cell compares
their diagnostics. The means form goes forward to the plots below.</p>
***/

webdoc stlog
use `hsls', clear
quietly tabulate group, matcell(sizes)
mata: st_local("smallest", strofreal(min(st_matrix("sizes"))))
mata: st_local("largest", strofreal(max(st_matrix("sizes"))))
display as result "Students per school context: `smallest' to `largest'"
tempfile full_offsets full_means
bayes_sample_groups w2_math w1_math_c w1_ses, group(group) form(offsets) update(reffects) saving(`full_offsets')
local seconds_offsets = r(seconds)
bayes_sample_groups w2_math w1_math_c w1_ses, group(group) form(means) update(reffects) saving(`full_means')
local seconds_means = r(seconds)
preserve
tempfile comparison
foreach form in offsets means {
    use `full_`form'', clear
    bayes_summary alpha beta1 beta2 sigma tau a1-a31, chain(chain) clear
    quietly summarize rhat
    local rhat = r(max)
    quietly summarize ess_tail
    local tail = r(min)
    sort ess_bulk
    local bulk = ess_bulk[1]
    local worst = parameter[1]
    clear
    quietly set obs 1
    generate str40 form = cond("`form'" == "offsets", "Offsets: a_j ~ Normal(0, tau)", "Means: m_j ~ Normal(alpha, tau)")
    generate double rhat = `rhat'
    generate double bulk = `bulk'
    generate double tail = `tail'
    generate str8 worst = "`worst'"
    generate double seconds = `seconds_`form''
    if "`form'" == "means" append using `comparison'
    quietly save `comparison', replace
}
gsort -form
label variable form "Form, a block per group"
label variable rhat "Largest R-hat"
label variable bulk "Smallest bulk ESS"
label variable tail "Smallest tail ESS"
label variable worst "Parameter with the smallest bulk ESS"
label variable seconds "Seconds, four chains"
format rhat %9.3f
format bulk tail %9.0f
format seconds %9.1f
webdoc stlog close
html_table
restore

/***
<h2>Diagnostics for every parameter</h2>

<p>A model with dozens of parameters needs a view of all of them at once. The
plot shows R-hat and bulk ESS for every parameter of the means form, with the
thresholds: R-hat 1.01 and ESS 400.</p>
***/

webdoc stlog
use `full_means', clear
bayes_summary alpha beta1 beta2 sigma tau a1-a31, chain(chain) clear
sort ess_bulk
generate int y = _n
forvalues i = 1/`=_N' {
    label define parameter `i' "`=parameter[`i']'", modify
}
label values y parameter
twoway scatter y rhat, msymbol(O) mcolor("1 115 178") msize(small) ///
    xline(1.01, lcolor(red) lpattern(dash)) xtitle("R-hat") ytitle("") ///
    ylabel(1(1)`=_N', valuelabel angle(horizontal) labsize(vsmall) nogrid) ///
    name(rhat, replace) nodraw
twoway scatter y ess_bulk, msymbol(O) mcolor("1 115 178") msize(small) ///
    xline(400, lcolor(red) lpattern(dash)) xscale(log) xlabel(100 400 1000 4000) ///
    xtitle("Bulk ESS (log scale)") ytitle("") ylabel(1(1)`=_N', valuelabel angle(horizontal) labsize(vsmall) nogrid) ///
    name(ess, replace) nodraw
graph combine rhat ess, cols(2) xsize(11) ysize(8) ///
    title("R-hat and bulk ESS for every parameter, means form (dashed: thresholds)", size(medium))
webdoc stlog close
webdoc graph, alt("R-hat and bulk ESS of every parameter of the hierarchical model")

/***
<h2>Caterpillar plots</h2>

<p>A caterpillar plot shows one interval per group, sorted by the posterior
mean, so the groups line up like the segments of a caterpillar. Each segment
here is a school context's intercept: how far its students' expected follow-up
score sits from the overall intercept, for students with the same base-year
math and SES. The thick bar is the central 50% interval and the thin line the
central 90% interval.</p>
***/

webdoc stlog
use `hsls', clear
contract group context, freq(n)
tempfile contexts
quietly save `contexts'

use `full_means', clear
tempname post
tempfile caterpillar
postfile `post' int group double(mean q05 q25 q75 q95) using `caterpillar'
forvalues j = 1/31 {
    bayes_interval a`j', level(90)
    local q05 = r(low)
    local q95 = r(high)
    local mean = r(mean)
    bayes_interval a`j', level(50)
    post `post' (`j') (`mean') (`q05') (r(low)) (r(high)) (`q95')
}
postclose `post'
use `caterpillar', clear
quietly merge 1:1 group using `contexts', nogenerate
sort mean
generate int y = _n
forvalues i = 1/`=_N' {
    label define context `i' "`=context[`i']' (n = `=strtrim(string(n[`i'], "%9.0fc"))')", modify
}
label values y context
twoway (rspike q05 q95 y, horizontal lcolor("1 115 178") lwidth(thin)) ///
    (rspike q25 q75 y, horizontal lcolor("1 115 178") lwidth(thick)) ///
    (scatter y mean, msymbol(O) mcolor(black) msize(vsmall)), ///
    xline(0, lcolor(gs8) lpattern(dash)) legend(off) ///
    ylabel(1(1)31, valuelabel angle(horizontal) labsize(vsmall) nogrid) ytitle("") ///
    xtitle("Group intercept: follow-up math points relative to the overall intercept") ///
    title("School-context intercepts, posterior mean with 50% and 90% intervals", size(medium)) ///
    xsize(8) ysize(9)
tempfile caterpillar_table
quietly save `caterpillar_table'
webdoc stlog close
webdoc graph, alt("Caterpillar plot of the 31 school-context intercepts")

webdoc stlog
* Partial pooling: a group's estimate is pulled toward 0 more when it has
* fewer students. The comparison is each group's mean residual around the
* hierarchical model's own common intercept and slopes (posterior means), the
* estimate a group would get with no pooling and the same reference point.
use `full_means', clear
foreach name in alpha beta1 beta2 {
    quietly summarize `name', meanonly
    local `name' = r(mean)
}
use `hsls', clear
generate double residual = w2_math - (`alpha' + `beta1' * w1_math_c + `beta2' * w1_ses)
collapse (mean) raw = residual, by(group)
quietly merge 1:1 group using `caterpillar_table', nogenerate
quietly summarize raw
local low = min(r(min), -3)
local high = max(r(max), 3)
twoway (function y = x, range(`low' `high') lcolor(gs8) lpattern(dash)) ///
    (scatter mean raw [aweight = n], msymbol(Oh) msize(*0.4) mcolor("1 115 178")), legend(off) ///
    xtitle("Mean residual in the group around the common line (no pooling)") ///
    ytitle("Posterior mean of the group intercept") ///
    ylabel(, angle(horizontal)) note("Marker area is proportional to the number of students in the group.") ///
    title("Partial pooling pulls small groups toward 0", size(medium)) xsize(6.5) ysize(5)
tempfile pooling
quietly save `pooling'
use `full_means', clear
quietly summarize tau
display as result "Posterior mean of tau, the SD of the group intercepts: " %4.2f r(mean)
webdoc stlog close
webdoc graph, alt("Posterior means of the group intercepts against the groups' mean residuals")

webdoc stlog
* How far each estimate moved toward 0, for the five smallest and five largest groups
use `pooling', clear
generate double moved = raw - mean
sort n
quietly keep if _n <= 5 | _n > _N - 5
keep context n raw mean moved
order context n raw mean moved
webdoc stlog close
label variable context " "
label variable n "Students"
label variable raw "No pooling"
label variable mean "Posterior mean"
label variable moved "Moved"
format n %9.0fc
format raw mean moved %9.2f
html_table

/***
<p>Groups on the dashed line keep their no-pooling estimate. The table lists
the five smallest and five largest groups and how far each estimate moved
toward 0. The five largest groups move by 0.04 points or less, since their
data dominate. Small groups with a large raw mean move the most: the 87
students at private rural schools in the Midwest go from 2.60 to 1.63. They
move because the hierarchical prior, with an SD of $\tau$ estimated from all
groups, pulls them in. That is the regularization from
<code>02-ols-vs-bayes</code> again, with the amount of pulling learned from the
data.</p>
***/
