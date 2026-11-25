*! plot_prior_stats: a statistic of the simulated data sets, as histograms
*
* Uses the data prior_stats leaves: one histogram of the statistic per set.
* reference() marks a value, such as the observed one; log puts the x axis on
* a log scale, for statistics with long right tails. plot_simulated_stats()
* in the R and Python projects draws the same figure.
*
*   plot_prior_stats outcome_sd, reference(1) log
program define plot_prior_stats
    version 14
    syntax varname [, REFerence(real -999) LOG BINs(integer 50)]
    local stat `varlist'
    quietly count if set_id == 1
    local draws = r(N)
    preserve
    local observed `reference'
    local axis
    if "`log'" != "" {
        * Histogram of log10 values, labeled in the statistic's own units
        quietly replace `stat' = log10(`stat')
        local axis xlabel(-2 "0.01" -1 "0.1" 0 "1" 1 "10" 2 "100")
        if `reference' != -999 local reference = log10(`reference')
    }
    local line
    local caption
    if `reference' != -999 {
        local line xline(`reference', lpattern(dash) lcolor("213 94 0") lwidth(medthick))
        local caption caption("Red dashed line: the value in the observed data (`stat' = `observed').", size(small) position(5))
    }
    histogram `stat', frequency bin(`bins') pstyle(p1) `line' `axis' ///
        by(set_id, cols(1) note("") ///
            title("Statistics of `=strtrim(string(`draws', "%9.0fc"))' simulated data sets per prior set", size(medium) position(11)) ///
            `caption') ///
        xtitle("`stat'") ytitle("Simulated data sets") ylabel(, angle(horizontal)) ///
        xsize(7) ysize(4)
    restore
end
