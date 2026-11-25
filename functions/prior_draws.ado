*! prior_draws: draw every parameter from one or more prior sets
*
* Replaces the data with n() draws from each prior set: set_id (labeled with
* the set's name), draw, and one variable per parameter. Each set is a name,
* a colon, and named priors (parameter=prior, any names); || separates sets.
* Lists the sets. draw_priors() in the R and Python projects does the same.
*
*   prior_draws Weaker: alpha=normal(0, 1) beta=normal(0, 1) sigma=half_t(3, 2.5) ///
*       || Stronger: alpha=normal(0, 0.2) beta=normal(0, 0.5) sigma=exponential(1), n(4000) clear
program define prior_draws
    version 14
    syntax anything(name=sets everything equalok), clear [N(integer 4000)]

    local sets = subinstr(`"`sets'"', "||", "|", .)
    local labels
    local id 0
    tempfile all
    clear
    quietly save `all', emptyok
    while `"`sets'"' != "" {
        gettoken one sets : sets, parse("|")
        if `"`one'"' == "|" continue
        local ++id
        gettoken name priors : one, parse(":")
        gettoken colon priors : priors, parse(":")
        local name = strtrim(`"`name'"')
        * One parameter=prior per token: close each prior's parenthesis with a space
        local priors = subinstr(subinstr(`"`priors'"', " ", "", .), ")", ") ", .)

        clear
        quietly set obs `n'
        generate byte set_id = `id'
        generate long draw = _n
        local shown
        foreach entry of local priors {
            gettoken parameter prior : entry, parse("=")
            gettoken equals prior : prior, parse("=")
            if "`equals'" != "=" | "`prior'" == "" {
                display as error `"prior_draws: write each prior as parameter=prior, such as alpha=normal(0, 1), not `entry'"'
                exit 198
            }
            prior_parse `prior'
            generate double `parameter' = `r(random)'
            local shown = cond(`"`shown'"' == "", `"`parameter' ~ `r(name)'"', `"`shown', `parameter' ~ `r(name)'"')
        }
        display as text `"`name': "' as result `"`shown'"'
        local labels `labels' `id' `"`name'"'
        append using `all'
        quietly save `all', replace
    }

    use `all', clear
    label define prior_set `labels', replace
    label values set_id prior_set
    label variable set_id "Prior set"
    sort set_id draw
end
