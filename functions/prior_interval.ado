*! prior_interval: the central interval holding level() percent of a prior
*
* Displays it as "95%: -1.96 to 1.96" and returns r(lower) and r(upper).
* interval_text() in the R and Python projects gives the same text.
*
*   prior_interval normal(0, 0.2)
program define prior_interval, rclass
    version 14
    syntax anything(name=prior) [, Level(real 95)]
    prior_parse `prior', level(`level')
    local lower = r(lower)
    local upper = r(upper)
    display as result strtrim(string(`level', "%9.0g")) "%: " %4.2f `lower' " to " %4.2f `upper'
    return scalar lower = `lower'
    return scalar upper = `upper'
end
