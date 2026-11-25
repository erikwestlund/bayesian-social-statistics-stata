* 05-sampling.do: notebook that follows the data through one bayesmh fit
*
* webdoc runs this do-file and writes the text, Stata output, tables, and
* graphs to outputs/notebooks/05-sampling.html. Run it through
* do/04_bayes_notebooks.do. The R and Python projects render the same
* notebook with Stan. It saves the HSLS:09 posterior draws to
* outputs/models for 07-posterior-summary and 08-posterior-predictive.

webdoc init `"$outputs_notebooks/05-sampling.html"', replace ///
    header(title("Sampling the posterior") author("Erik") date("2026-11-18") width(60em)) ///
    logdir(05-sampling_files) ///
    grdir(05-sampling_files) ///
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

<h1>Sampling the posterior</h1>

<p>Erik, 2026-11-18</p>

<p>This notebook follows the data through one <code>bayesmh</code> fit: what
goes in, what the sampler does with it, and what comes out. It runs first on
simulated students, then on HSLS:09, and saves the HSLS:09 draws for the
notebooks on posterior summaries and posterior predictive checks.</p>

<p>Stata 14's <code>bayesmh</code> samples with an adaptive random-walk
Metropolis-Hastings (MH) algorithm. At each iteration it proposes a new point,
drawn from a normal distribution centered on the current one, and accepts it
with a probability equal to the ratio of the posterior densities at the two
points, capped at 1. A rejected proposal repeats the current point. Each step
is small, so successive draws are close together and strongly
autocorrelated. During burn-in the sampler adapts the scale and the covariance
of its proposals so that a target share of them is accepted. The parameters
can be split into blocks that are updated one after another, and a block whose
conditional posterior has a known form can be drawn from it directly, a Gibbs
update. Stan, used in the R and Python versions of this notebook, samples with
Hamiltonian Monte Carlo instead, which follows the gradient of the log
posterior and makes long moves with few rejections. Stata 14 has no
Hamiltonian sampler.</p>
***/

webdoc stlog
bayes_analysis_sample, clear
tempfile hsls
quietly save `hsls'

* One seed for the simulated students and the chains
set seed 505
webdoc stlog close

/***
<h2>The bayesmh command</h2>

<p>A <code>bayesmh</code> command states the model in its options: the
likelihood, a prior for every parameter, and the sampler settings.
<code>bayes_sample</code> in <code>functions/</code> builds the command below
for each chain. Written out for one chain on 1,000 simulated students, it
is:</p>
***/

webdoc stlog
bayes_simulate, n(1000) alpha(50.4) beta(0.7 1.8) sigma(6.6) clear
bayesmh w2_math w1_math_c w1_ses, likelihood(normal({sigma}^2)) ///
    prior({w2_math:_cons}, normal(50, 100)) ///
    prior({w2_math:w1_math_c}, normal(0, 6.25)) ///
    prior({w2_math:w1_ses}, normal(0, 6.25)) ///
    prior({sigma}, exponential(10)) ///
    block({sigma}) burnin(2500) mcmcsize(1000) thinning(10) ///
    initial({w2_math:_cons} 1.2 {w2_math:w1_math_c} -0.4 {w2_math:w1_ses} 0.9 {sigma} 2.1) ///
    dots(0)
webdoc stlog close

/***
<div class="table"><table>
<thead><tr><th>Option</th><th>Meaning</th></tr></thead>
<tbody>
<tr><td><code>likelihood(normal({sigma}^2))</code></td><td>Each <code>w2_math</code> is normal around the linear form <code>xb_w2_math</code>, the intercept plus the slopes times <code>w1_math_c</code> and <code>w1_ses</code>. <code>bayesmh</code> takes the variance, so the residual SD $\sigma$ enters squared and stays the parameter.</td></tr>
<tr><td><code>prior()</code></td><td>One prior for each parameter. <code>normal(m, v)</code> takes the variance, so Normal(50, 10) is <code>normal(50, 100)</code>. <code>exponential(b)</code> takes the mean, so Exponential(0.1) is <code>exponential(10)</code>. These are the weak priors of the other notebooks.</td></tr>
<tr><td><code>block({sigma})</code></td><td>Updates $\sigma$ in a block of its own, so each iteration first proposes new coefficients, all three together, and then a new $\sigma$. By default, <code>bayesmh</code> updates all parameters in one block.</td></tr>
<tr><td><code>burnin(2500)</code></td><td>Iterations run and discarded before any draw is kept. The sampler adapts its proposals during them, every 100 iterations.</td></tr>
<tr><td><code>mcmcsize(1000)</code></td><td>Draws kept after burn-in.</td></tr>
<tr><td><code>thinning(10)</code></td><td>Keeps every 10th iteration, so the chain runs 2,500 + 10,000 iterations. Thinning lowers the autocorrelation between kept draws.</td></tr>
<tr><td><code>initial()</code></td><td>The starting point. <code>bayes_sample</code> draws one for each chain, as Stan does: uniform from −2 to 2 for the intercept and the slopes, and for the log of $\sigma$.</td></tr>
<tr><td><code>saving()</code></td><td>Writes the draws to a Stata dataset. <code>bayes_sample</code> adds it; the call above leaves it out, and <code>bayesmh</code> then keeps the draws in a temporary file.</td></tr>
</tbody></table></div>

<p>The header of the output reports the acceptance rate, the share of proposals
accepted, and the efficiency: the effective sample size, explained in
<code>06-diagnostics</code>, over the number of draws kept, for each parameter.
The model summary at the top restates the model as <code>bayesmh</code>
understood it.</p>

<h2>Data in</h2>

<p><code>bayesmh</code> reads the variables in memory, as <code>regress</code>
does, and drops students with a missing value in any of them. The rest of the
model is in the options. The cell describes the variables of the 1,000
simulated students.</p>
***/

webdoc stlog
describe w2_math w1_math_c w1_ses
summarize w2_math w1_math_c w1_ses
webdoc stlog close

/***
<p>The two predictors are <code>w1_math_c</code>, base-year math minus 50, and
<code>w1_ses</code>, SES as supplied, and <code>w2_math</code> is the outcome. <code>bayesmh</code> checks the model before
sampling. A parameter without a prior stops it. So does a starting point where
the posterior density is 0, such as a negative $\sigma$, unless
<code>bayesmh</code> finds a feasible starting point nearby.</p>

<h2>Sampling</h2>

<p><code>bayes_sample</code> runs four chains of 2,500 burn-in iterations and
10,000 more, thinned to 1,000 draws each. Stata 14 runs one chain per
<code>bayesmh</code> call, so the chains run one after another, not in
parallel. The cell keeps each chain's simulation dataset to show what
<code>bayesmh</code> writes.</p>
***/

webdoc stlog
tempfile raw fake_draws
bayes_sample w2_math w1_math_c w1_ses, saving(`fake_draws') rawsaving(`raw')
display as result "Sampling took " %4.1f r(seconds) " seconds"
display as result "Output files: " r(chains) " Stata datasets, one per chain"
matrix list r(chain_stats), format(%9.3f)
webdoc stlog close

/***
<h2>Draws out</h2>

<p>Each chain's simulation dataset has one row per distinct kept draw. Its
columns are:</p>

<div class="table"><table>
<thead><tr><th>Column</th><th>Meaning</th></tr></thead>
<tbody>
<tr><td><code>_index</code></td><td>Number of the first kept draw in a run of identical draws</td></tr>
<tr><td><code>_loglikelihood</code></td><td>Log likelihood at the draw</td></tr>
<tr><td><code>_logposterior</code></td><td>Log posterior density at the draw, up to a constant</td></tr>
<tr><td><code>eq1_p1</code>, <code>eq1_p2</code>, <code>eq1_p3</code></td><td>The coefficients of the first equation, in the order of <code>e(parnames)</code>: the two slopes, then the intercept</td></tr>
<tr><td><code>eq0_p1</code></td><td>The parameters outside any equation, here $\sigma$</td></tr>
<tr><td><code>_frequency</code></td><td>How many kept draws in a row had this value</td></tr>
</tbody></table></div>

<p>A rejected proposal repeats the current point, so a run of identical draws
is stored once, with its count in <code>_frequency</code>. There is no
counterpart to Stan's sampler columns, such as the step size or divergent
transitions, because a random-walk sampler has none of them.</p>
***/

webdoc stlog
use `"`raw'_chain1.dta"', clear
codebook, compact
format _loglikelihood _logposterior eq* %10.3f
list in 1/5, noobs abbreviate(14)
quietly summarize _frequency
display as result r(N) " rows hold " r(sum) " draws"
webdoc stlog close

/***
<p>With <code>thinning(10)</code>, a kept draw rarely repeats the one kept
before it, so here nearly every row holds one draw. Without thinning, as in the
next section, runs are common. <code>bayes_sample</code> expands the runs,
renames the columns after the parameters, and stacks the chains: one row per
draw, with the chain and the draw number.</p>
***/

webdoc stlog
use `fake_draws', clear
codebook, compact
display as result strtrim(string(_N, "%9.0fc")) " rows: 4 chains of 1,000 draws"
list in 1/5, noobs
webdoc stlog close

/***
<h2>Burn-in and adaptation</h2>

<p>During burn-in, each chain moves from its random start toward the region of
high posterior density, and the sampler tunes its proposals. Burn-in draws are
not saved, so to show them the cell reruns the four chains without burn-in:
2,000 kept iterations each, with no thinning, and adaptation every 50
iterations for the first 1,000. The left panel shows the SES slope over all
2,000 iterations of each chain; the dashed line marks the end of adaptation.
The right panel shows the share of proposals for the coefficient block that
were accepted, in windows of 50 iterations. The adaptation aims at 0.234, the
rate that is most efficient for a random-walk proposal in several
dimensions.</p>
***/

webdoc stlog
bayes_simulate, n(1000) alpha(50.4) beta(0.7 1.8) sigma(6.6) clear
tempfile path
bayes_sample w2_math w1_math_c w1_ses, saving(`path') burnin(0) draws(2000) thinning(1) ///
    adaptation(every(50) maxiter(20))
use `path', clear
sort chain draw
* The coefficient block moved when the intercept changed
by chain: generate byte moved = alpha != alpha[_n - 1] if _n > 1
generate int window = ceil(draw / 50)
local colors `" "1 115 178" "222 143 5" "2 158 115" "213 94 0" "'
local traces
forvalues c = 1/4 {
    local traces `traces' (line beta2 draw if chain == `c', lcolor("`: word `c' of `colors''") lwidth(vthin))
}
twoway `traces', xline(1000, lcolor(black) lpattern(dash)) yline(1.8, lcolor(black)) ///
    legend(order(1 "Chain 1" 2 "Chain 2" 3 "Chain 3" 4 "Chain 4") rows(1) size(small)) ///
    xtitle("Iteration") ytitle("SES slope") ylabel(, angle(horizontal)) ///
    title("SES slope (solid line: true value)", size(medium)) name(trace, replace) nodraw
preserve
collapse (mean) accepted = moved (max) draw, by(chain window)
local rates
forvalues c = 1/4 {
    local rates `rates' (connected accepted draw if chain == `c', lcolor("`: word `c' of `colors''") ///
        mcolor("`: word `c' of `colors''") msize(vsmall))
}
twoway `rates', xline(1000, lcolor(black) lpattern(dash)) yline(0.234, lcolor(gs8)) ///
    legend(off) xtitle("Iteration") ytitle("Share of proposals accepted") ylabel(0(0.2)1, angle(horizontal)) ///
    title("Acceptance rate, windows of 50 iterations", size(medium)) name(rate, replace) nodraw
restore
graph combine trace rate, cols(2) xsize(12) ysize(3.8)
webdoc stlog close
webdoc graph, alt("Trace of the SES slope for four chains from random starts, and the acceptance rate by window")

webdoc stlog
* Early iterations of each chain, on the way to the posterior
format lp %12.2f
format alpha beta1 beta2 sigma %8.2f
list chain draw lp alpha beta1 beta2 sigma if inlist(draw, 1, 5, 10, 25, 50, 100, 200, 300, 400, 500), ///
    noobs sepby(chain)

* When each chain reaches the region of the final draws: the first iteration
* after which all four parameters stay within the range of all chains' draws
* after iteration 1,000
generate byte outside = 0
foreach name in alpha beta1 beta2 sigma {
    quietly summarize `name' if draw > 1000
    quietly replace outside = 1 if !inrange(`name', r(min), r(max))
}
forvalues c = 1/4 {
    quietly summarize draw if chain == `c' & outside
    display as result "Chain `c' stays in the region of the final draws from iteration " r(max) + 1
}
webdoc stlog close

/***
<p><code>bayes_sample</code> starts each chain as Stan does, at random values
between −2 and 2, so the intercept starts near 0, about 50 points from the
posterior, and $\sigma$ starts between 0.1 and 7.4. A rejected proposal leaves
the chain where it is, which shows as the flat stretches in the trace plot.
The table shows the chains
climbing toward the posterior, with the log posterior <code>lp</code> rising by
orders of magnitude. In this run, chain 4 is near the values of the final
draws by iteration 300, chains 1 and 3 by iteration 400, and chain 2 by
iteration 500. By the stricter measure in the last lines, every parameter staying within the range of the draws after
iteration 1,000, the chains arrive at iterations 378, 918, 403, and 746. A
random walk moves only a short distance per step, so the climb takes hundreds
of iterations. Reaching that region is not
convergence: the diagnostics in <code>06-diagnostics</code> check that the
chains, after burn-in, agree with one another. While the chains travel, the acceptance rate swings far
from the target, and it settles near 0.234 once they arrive and the proposals
are tuned. Burn-in runs much longer than that, because tuning the
proposals takes longer than finding the posterior. None of the burn-in draws
are used for inference.</p>

<p>The burn-in of 2,500 iterations in <code>bayes_sample</code> covers the
default 25 adaptation periods of 100 iterations each. A shorter burn-in leaves
<code>bayesmh</code> adapting after burn-in, and it then notes that
adaptation continues during the simulation.</p>

<h2>HSLS:09</h2>

<p>The same steps on the 18,623 HSLS:09 students, with the weak priors. Each
chain's simulation dataset goes to the private models folder as
<code>hsls_regression_chain1.dta</code> to <code>chain4</code>, and the stacked
draws as <code>hsls_regression_draws.dta</code>. The settings travel with the
draws as dataset characteristics: the model, the priors, the sample size, and
the sampler settings. <code>07-posterior-summary</code> and
<code>08-posterior-predictive</code> read the draws back.</p>
***/

webdoc stlog
use `hsls', clear
describe w2_math w1_math_c w1_ses
bayes_sample w2_math w1_math_c w1_ses, saving(`"$outputs_models/hsls_regression_draws.dta"') replace ///
    rawsaving(`"$outputs_models/hsls_regression"')
display as result "Sampling took " %4.1f r(seconds) " seconds"
matrix list r(chain_stats), format(%9.3f)
webdoc stlog close

webdoc stlog
* What else a reader of the draws needs: the priors and how the predictors
* were centered, so a later notebook can rebuild predictions on the score scale
use `"$outputs_models/hsls_regression_draws.dta"', clear
char _dta[bayes_center] "w1_math_c = w1_math - 50"
quietly save `"$outputs_models/hsls_regression_draws.dta"', replace
char list _dta[]
display as result "Saved " strtrim(string(_N, "%9.0fc")) " draws to outputs/models/hsls_regression_draws.dta"
webdoc stlog close

webdoc stlog
local panels
foreach name in alpha beta1 beta2 sigma {
    quietly histogram `name', bin(50) frequency fcolor("1 115 178") lcolor(white) lwidth(vthin) ///
        name(`name', replace) nodraw title(`name', size(medium)) xtitle("") ///
        ytitle(`=cond("`name'" == "alpha", "Draws", "")') ylabel(, angle(horizontal))
    local panels `panels' `name'
}
graph combine `panels', cols(4) xsize(14) ysize(3.2) ///
    title("Marginal posterior draws, HSLS:09 (n = 18,623, 4,000 draws)", size(medium))
webdoc stlog close
webdoc graph, alt("Histograms of the posterior draws of the intercept, the two slopes, and the residual SD")

/***
<p>Each histogram shows one parameter's 4,000 draws. Together the draws are a
sample from the joint posterior: every summary in the later notebooks, from a
mean to a predicted score for a new student, is a calculation done once per
draw and then summarized across draws. <code>06-diagnostics</code> checks
whether the draws are trustworthy before anything is summarized.</p>
***/
