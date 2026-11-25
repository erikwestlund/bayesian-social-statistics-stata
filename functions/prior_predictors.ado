*! prior_predictors: the predictors in a model expression
*
* Returns in r(predictors) the names in the expression that are neither
* variables in the data (the parameters prior_draws made) nor Stata functions.
* plot_prior_lines uses it.
*
*   prior_predictors alpha + beta * parent_ses_z
program define prior_predictors, rclass
    version 14
    syntax anything(name=mu everything)
    local words = ustrregexra(`"`mu'"', "[^A-Za-z0-9_]", " ")
    local predictors
    foreach word of local words {
        if !ustrregexm("`word'", "^[A-Za-z_]") continue
        if inlist("`word'", "exp", "ln", "log", "sqrt", "abs", "invlogit", "logit") continue
        capture confirm variable `word', exact
        if !_rc continue
        local predictors : list predictors | word
    }
    return local predictors "`predictors'"
end
