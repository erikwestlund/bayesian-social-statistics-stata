*! plot_simulated: simulated data sets as small scatter plots
*
* Uses the data prior_simulate leaves. Plots y against x() for the first
* draws() draws of each set, each in its own panel, cols() to a row, the sets
* one after another. Dashed lines mark -2 and 2 on the outcome's scale. Axis
* titles default to the variable names. plot_simulated() in the R and Python
* projects draws the same figure.
*
*   plot_simulated, x(parent_ses_z) xtitle("Family SES (SD)")
program define plot_simulated
    version 14
    syntax, X(varname) [DRAWs(integer 16) COLs(integer 8) XTItle(string) YTItle(string)]
    if "`xtitle'" == "" local xtitle `x'
    if "`ytitle'" == "" local ytitle "Simulated outcome"
    preserve
    quietly keep if draw <= `draws'
    quietly summarize row, meanonly
    local rows = r(max)

    * One panel per set and draw, labeled "Weaker 1" and so on, in set order
    generate int panel = (set_id - 1) * `draws' + draw
    quietly levelsof panel, local(panels)
    foreach p of local panels {
        quietly summarize set_id if panel == `p', meanonly
        local set : label prior_set `r(min)'
        quietly summarize draw if panel == `p', meanonly
        label define panel `p' "`set' `r(min)'", add
    }
    label values panel panel

    twoway scatter y `x', pstyle(p1) msymbol(o) msize(tiny) ///
        by(panel, cols(`cols') note("") compact ///
            title("Simulated data sets, `draws' draws from each prior set, `rows' rows each", size(medium) position(11)) ///
            caption("Red dashed lines: -2 and 2 on the outcome's scale.", size(small) position(5))) ///
        yline(-2 2, lpattern(dash) lcolor("213 94 0") lwidth(medthin)) ///
        subtitle(, size(vsmall) nobox) ///
        xlabel(-2(2)2, labsize(vsmall)) ylabel(, labsize(vsmall) angle(horizontal)) ///
        xtitle(`"`xtitle'"') ytitle(`"`ytitle'"') ///
        xsize(10) ysize(6)
    restore
end
