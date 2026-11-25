*! plot_prior_lines: the line each prior draw implies, one panel per set
*
* Uses the data prior_draws leaves. mu() is the model's expected outcome, an
* expression in the parameters and one predictor; other predictors are held
* at 0. Draws the first lines() draws of each set over the predictor from -2
* to 2, with a grey band at -2 to 2 on the outcome's scale. Axis titles
* default to the variable names. plot_prior_lines() in the R and Python
* projects draws the same figure.
*
*   plot_prior_lines, mu(alpha + beta * parent_ses_z) xtitle("Family SES (SD)")
program define plot_prior_lines
    version 14
    syntax, MU(string) [LINes(integer 100) XTItle(string) YTItle(string)]
    prior_predictors `mu'
    local predictors `r(predictors)'
    gettoken x others : predictors
    if "`xtitle'" == "" local xtitle `x'
    if "`ytitle'" == "" local ytitle "Expected outcome"

    preserve
    quietly keep if draw <= `lines'
    quietly expand 2
    bysort set_id draw: generate double `x' = cond(_n == 1, -2, 2)
    foreach other of local others {
        generate double `other' = 0
    }
    generate double mu = `mu'
    sort set_id draw `x'
    * connect(L) starts a new line wherever x falls back to -2: one per draw
    twoway (function y = 2, range(-2 2) recast(area) base(-2) color(gs14) lwidth(none)) ///
        (line mu `x', connect(L) pstyle(p1line) lwidth(vthin)), ///
        by(set_id, note("") legend(off) ///
            title("Implied lines, `lines' draws from each prior set", size(medium) position(11)) ///
            caption("Grey band: -2 to 2 on the outcome's scale.", size(small) position(5))) ///
        xtitle(`"`xtitle'"') ytitle(`"`ytitle'"') ylabel(, angle(horizontal)) ///
        xsize(8) ysize(3.5)
    restore
end
