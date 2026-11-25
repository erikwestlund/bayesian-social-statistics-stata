*! prior_share: the share of a prior between two values
*
* Displays it and returns r(share). A missing bound (.) means no bound on
* that side. prior_share() in the R and Python projects gives the same number.
*
*   prior_share normal(0, 1), between(-1 1)
*   prior_share exponential(1), between(1 .)
program define prior_share, rclass
    version 14
    syntax anything(name=prior), BETWeen(numlist min=2 max=2 missingokay)
    gettoken lower upper : between
    local upper = strtrim("`upper'")
    prior_parse `prior'
    local name `"`r(name)'"'
    local cdf `"`r(cdf)'"'
    * r(cdf) is an expression in @: put each bound in its place
    local at_lower : subinstr local cdf "@" "(`lower')", all
    local at_upper : subinstr local cdf "@" "(`upper')", all
    local below = cond(missing(`lower'), 0, `at_lower')
    local within = cond(missing(`upper'), 1, `at_upper')
    local share = `within' - `below'
    local lower_text = cond(missing(`lower'), "", "`lower' < ")
    local upper_text = cond(missing(`upper'), "", " < `upper'")
    display as result `"`name', share `lower_text'x`upper_text': "' %4.2f `share'
    return scalar share = `share'
end
