*! plot_priors: density curves of one or more priors on shared axes
*
* Each prior is normal(mean, sd) or exponential(rate). With two or more,
* each is labeled on its curve. Colours follow the order given, from the
* scheme fw_scaffold sets. range(lower upper) fixes the x axis, so separate
* graphs compare; without it the axis spans the priors' central 99.8%.
* possible(lower upper) shades the parameter's possible values.
* plot_priors() in the R and Python projects draws the same figure.
*
*   plot_priors normal(0, 1) normal(0, 0.2), xtitle("α") range(-3 3) possible(-1 1)
program define plot_priors
    version 14
    syntax anything(name=priors), XTItle(string) [RANGE(numlist min=2 max=2 ascending) POSsible(numlist min=2 max=2 ascending)]

    * One prior per token: close each prior's parenthesis with a space after it
    local priors = subinstr(subinstr(`"`priors'"', " ", "", .), ")", ") ", .)
    local count : word count `priors'

    * Axis range: given, or the widest central 99.8% of the priors
    if "`range'" != "" {
        gettoken from to : range
        * Round steps, so the axis ends where the range does: 0.5 up to a
        * width of 4, then 1, then 2
        local width = `to' - `from'
        local step = cond(`width' <= 4, 0.5, cond(`width' <= 8, 1, 2))
        local xlabels xlabel(`from'(`step')`to')
    }
    else {
        local from .
        local to .
        foreach prior of local priors {
            prior_parse `prior'
            local from = min(`from', r(from))
            local to = max(`to', r(to))
        }
    }

    local plots
    local labels
    local names
    local peak 0
    local i 0
    foreach prior of local priors {
        prior_parse `prior'
        local ++i
        local peak = max(`peak', r(peak))
        * pstyle keeps each prior's scheme colour whether or not a band comes first
        local plots `plots' (function y = `r(density)', range(`from' `to') pstyle(p`i') lwidth(medthick) n(501))
        local labels `labels' text(`r(label_y)' `r(label_at)' "`r(name)'", placement(ne))
        local names `"`names' "`r(name)'""'
    }

    * Title: "A", "A and B", "A, B, and C"
    local title
    forvalues i = 1/`count' {
        local name : word `i' of `names'
        if `i' == 1 local title `"`name'"'
        else if `i' < `count' local title `"`title', `name'"'
        else if `count' == 2 local title `"`title' and `name'"'
        else local title `"`title', and `name'"'
    }
    * One curve needs no label: the title names it
    if `count' == 1 local labels

    * Possible values: a light band behind the curves, as tall as the highest
    local band
    local caption
    if "`possible'" != "" {
        gettoken low high : possible
        local band (function y = 1.05 * `peak', range(`low' `high') recast(area) color(gs14) lwidth(none))
        local caption caption("Grey band: possible values.", size(small) position(5))
    }

    twoway `band' `plots', `labels' legend(off) `caption' ///
        title(`"`title'"', position(11) size(medium)) ///
        xtitle(`"`xtitle'"') `xlabels' ytitle("Density") ylabel(, angle(horizontal)) ///
        xsize(6) ysize(3)
end
