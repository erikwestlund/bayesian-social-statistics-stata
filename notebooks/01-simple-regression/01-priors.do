* 01-priors.do: notebook on choosing priors for the series regression
*
* webdoc runs this do-file and writes the text, Stata output, and graphs to
* outputs/notebooks/01-simple-regression/01-priors.html. Run it
* through do/render_notebooks.do. The R and Python projects render the same
* notebook (notebooks/01-simple-regression/01-priors.qmd and .ipynb).

webdoc init `"$outputs_notebooks/01-simple-regression/01-priors.html"', replace ///
    header(title("Priors") author("Erik") date("2026-11-22") width(60em)) ///
    logdir(01-priors_files) ///
    grdir(01-priors_files) ///
    linesize(100) nokeep gropts(as(svg) hardcode)

* fw_scaffold sets the graph scheme from settings.yml (stata_scheme)

/***
<style>
body { font-size: 15px; line-height: 1.5; }
figure { margin: 0 0 1.2em; }
</style>
<script>window.MathJax = { tex: { inlineMath: [["$", "$"], ["\\(", "\\)"]] } };</script>
<script src="https://cdn.jsdelivr.net/npm/mathjax@3.2.2/es5/tex-chtml.js"></script>

<h1>Priors</h1>

<p>Erik, 2026-11-22</p>

<h2>Model</h2>

$$
\begin{aligned}
\text{Adult SES}_i &\sim \text{Normal}(\mu_i, \sigma) \\
\mu_i &= \alpha + \beta\,\text{Family SES}_i
\end{aligned}
$$

<ul>
<li>Family: Normal.</li>
<li>Linear model: intercept $\alpha$, slope $\beta$.</li>
<li>Parameters needing priors: $\alpha$, $\beta$, $\sigma$.</li>
</ul>

<h2>Standardized variables</h2>
***/

webdoc stlog
read_mobility, clear
tabstat w1_ses w4_ses parent_ses_z adult_ses_z, statistics(mean sd) columns(statistics) format(%4.2f)
display as result "n = " strtrim(string(_N, "%9.0fc")) " students with both SES measures"
webdoc stlog close

/***
<ul>
<li><code>parent_ses_z</code> (family SES, 2002) and <code>adult_ses_z</code>
(adult SES, 2012): mean 0, SD 1.</li>
</ul>

<h2>Intercept</h2>
***/

webdoc stlog
local intercept_priors normal(0, 0.2) normal(0, 0.5) normal(0, 1)
plot_priors `intercept_priors', xtitle("α, expected adult SES at family SES = 0 (SD)") range(-3 3)
foreach prior in "normal(0, 0.2)" "normal(0, 0.5)" "normal(0, 1)" {
    prior_interval `prior'
}
webdoc stlog close
webdoc graph, nokeep

/***
<h2>Slope</h2>
***/

webdoc stlog
local slope_priors normal(0, 0.5) normal(0, 1)
plot_priors `slope_priors', xtitle("β, expected difference in adult SES per SD of family SES") ///
    range(-3 3) possible(-1 1)
foreach prior in "normal(0, 0.5)" "normal(0, 1)" {
    prior_interval `prior'
    prior_share `prior', between(-1 1)
}
webdoc stlog close
webdoc graph, nokeep

/***
<ul>
<li>Possible values: −1 to 1. With both variables standardized, the slope is
the correlation.</li>
</ul>

<h2>Residual SD</h2>
***/

webdoc stlog
local sigma_priors exponential(1) half_normal(1) half_t(3, 2.5)
plot_priors `sigma_priors', xtitle("σ, SD of adult SES around the line (SD)") ///
    range(0 4) possible(0 1)
foreach prior in "exponential(1)" "half_normal(1)" "half_t(3, 2.5)" {
    prior_interval `prior'
    prior_share `prior', between(1 .)
}
webdoc stlog close
webdoc graph, nokeep

/***
<ul>
<li>Possible values: greater than 0 and at most 1, the SD of adult SES.</li>
<li>Exponential(1): mean 1.</li>
<li>Half-normal(0, 1): Stan prior recommendations.</li>
<li>Half-t(3, 0, 2.5): brms default, <code>student_t(3, 0, 2.5)</code> with a
lower bound of 0.</li>
</ul>
***/

/***
<h2>Prior predictive simulation</h2>

<h3>Prior sets</h3>
***/

webdoc stlog
* 200 students' family SES, kept for the simulated data below
read_mobility, clear
quietly sample 200, count
keep parent_ses_z
tempfile students
quietly save `students'

prior_draws Weaker: alpha=normal(0, 1) beta=normal(0, 1) sigma=half_t(3, 2.5) ///
    || Stronger: alpha=normal(0, 0.2) beta=normal(0, 0.5) sigma=exponential(1), n(4000) clear
local mu alpha + beta * parent_ses_z
webdoc stlog close

/***
<ul>
<li>Weaker: the widest candidate for each parameter above; its residual SD
prior is the brms default.</li>
</ul>

<h3>Implied lines</h3>
***/

webdoc stlog
plot_prior_lines, mu(`mu') xtitle("Family SES (SD)") ytitle("Expected adult SES (SD)")
webdoc stlog close
webdoc graph, nokeep

/***
<h3>Simulated data</h3>
***/

webdoc stlog
prior_simulate using `students', mu(`mu')
plot_simulated, x(parent_ses_z) xtitle("Family SES (SD)") ytitle("Simulated adult SES (SD)")
webdoc stlog close
webdoc graph, nokeep

/***
<ul>
<li>Family SES: real values for 200 students. Adult SES: simulated.</li>
</ul>

<h3>Implied outcome SD</h3>
***/

webdoc stlog
prior_stats (sd) outcome_sd = y
plot_prior_stats outcome_sd, reference(1) log
webdoc stlog close
webdoc graph, nokeep

webdoc stlog
generate byte above_2 = outcome_sd > 2
collapse (median) median = outcome_sd (mean) share_above_2 = above_2, by(set_id)
format median share_above_2 %4.2f
list, noobs abbreviate(16) separator(0)
webdoc stlog close

/***
<ul>
<li>Outcome SD: the SD of simulated adult SES in each simulated data set.</li>
<li>Observed: adult SES is standardized with the sample's SD, so any data set
on this scale has an SD near 1.</li>
</ul>
***/
